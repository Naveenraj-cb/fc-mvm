#!/bin/bash

# Firecracker MicroVM Orchestration Script
# This script sets up and launches 10 Firecracker microVMs

set -e

# Configuration variables
NUM_MVMS=10
FC_BIN_PATH="/usr/local/bin/firecracker"
KERNEL_PATH="./resources/vmlinux"
ROOTFS_PATH="./resources/rootfs.ext4"
NETWORK_BRIDGE="fcbridge0"
API_SOCKET_DIR="./sockets"
LOG_DIR="./logs"

# Create required directories
mkdir -p $API_SOCKET_DIR $LOG_DIR ./resources

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if running on EC2 i3.metal
instance_type=$(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
if [[ "$instance_type" != "i3.metal" ]]; then
  echo "Warning: This script is optimized for EC2 i3.metal instances. Current instance: $instance_type"
  echo "Performance may be suboptimal. Continue anyway? (y/n)"
  read -r answer
  if [ "$answer" != "y" ]; then
    exit 1
  fi
fi

# Download Firecracker binary if not present
if [ ! -f "$FC_BIN_PATH" ]; then
  echo "Downloading Firecracker binary..."
  wget -O firecracker.tgz https://github.com/firecracker-microvm/firecracker/releases/download/v1.3.3/firecracker-v1.3.3-x86_64.tgz
  tar -xvf firecracker.tgz
  cp release-v1.3.3-x86_64/firecracker-v1.3.3-x86_64 $FC_BIN_PATH
  chmod +x $FC_BIN_PATH
  rm -rf release-v1.3.3-x86_64 firecracker.tgz
fi

# Download kernel if not present
if [ ! -f "$KERNEL_PATH" ]; then
  echo "Downloading kernel image..."
  mkdir -p $(dirname $KERNEL_PATH)
  wget -O $KERNEL_PATH https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin
fi

# Download rootfs if not present
if [ ! -f "$ROOTFS_PATH" ]; then
  echo "Downloading root filesystem..."
  mkdir -p $(dirname $ROOTFS_PATH)
  wget -O $ROOTFS_PATH https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4
fi

# Setup networking bridge if it doesn't exist
setup_network() {
  if ! ip link show $NETWORK_BRIDGE &>/dev/null; then
    echo "Setting up network bridge $NETWORK_BRIDGE..."
    ip link add name $NETWORK_BRIDGE type bridge
    ip addr add 172.20.0.1/24 dev $NETWORK_BRIDGE
    ip link set dev $NETWORK_BRIDGE up
    
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    
    # Setup NAT
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $NETWORK_BRIDGE -o eth0 -j ACCEPT
  fi
}

# Function to create and setup a tap device
setup_tap_device() {
  local id=$1
  local tap_name="fc-tap-$id"
  local tap_ip="172.20.0.$(($id + 1))"
  
  ip tuntap add dev $tap_name mode tap
  ip link set $tap_name up
  ip link set $tap_name master $NETWORK_BRIDGE
  
  echo $tap_name
}

# Function to create a Firecracker configuration file
create_config() {
  local id=$1
  local tap_device=$2
  local socket_path="$API_SOCKET_DIR/firecracker-$id.sock"
  local config_file="./config-$id.json"
  
  cat > $config_file << EOF
{
  "boot-source": {
    "kernel_image_path": "$KERNEL_PATH",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "$ROOTFS_PATH",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "AA:FC:00:00:00:$(printf "%02x" $id)",
      "host_dev_name": "$tap_device"
    }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 128,
    "ht_enabled": false
  }
}
EOF

  echo $config_file
}

# Function to launch a Firecracker microVM
launch_microvm() {
  local id=$1
  local socket_path="$API_SOCKET_DIR/firecracker-$id.sock"
  local log_file="$LOG_DIR/firecracker-$id.log"
  
  # Remove socket if it exists
  [ -S "$socket_path" ] && rm "$socket_path"
  
  # Setup networking
  local tap_device=$(setup_tap_device $id)
  
  # Create configuration
  local config_file=$(create_config $id $tap_device)
  
  # Start Firecracker
  echo "Starting Firecracker microVM $id..."
  $FC_BIN_PATH --api-sock "$socket_path" --config-file "$config_file" --log-path "$log_file" &
  
  # Store PID for reference
  echo $! > "$LOG_DIR/firecracker-$id.pid"
  
  # Allow firecracker to start
  sleep 2
}

# Main execution
setup_network

echo "Launching $NUM_MVMS Firecracker microVMs..."
for ((i=0; i<$NUM_MVMS; i++)); do
  launch_microvm $i
done

echo "All $NUM_MVMS microVMs have been started!"
echo "You can check their status in the $LOG_DIR directory"