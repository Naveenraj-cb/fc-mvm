# Firecracker MicroVM Orchestration

This project demonstrates deploying and managing multiple Firecracker microVMs on AWS EC2 i3.metal instances. It provides scripts to launch 10 microVMs with networking capabilities.

## Project Overview

Firecracker is a lightweight virtualization technology developed by AWS for serverless computing platforms like Lambda and Fargate. This project provides tooling to:

1. Automatically deploy 10 Firecracker microVMs
2. Configure networking between microVMs and the host
3. Enable accessing each microVM independently

## Requirements

- AWS EC2 i3.metal instance (recommended)
- Ubuntu 20.04 or Amazon Linux 2
- Root access
- Internet connectivity for downloading resources

## Project Structure

```
fc-mvm/
├── main.sh              # Main script for deploying microVMs
├── resources/           # Contains kernel and rootfs images
├── sockets/             # Socket files for communicating with microVMs
└── logs/                # Log files from microVMs
```

## Setup Instructions

### Step 1: Launch an EC2 i3.metal Instance

1. Login to AWS Console and navigate to EC2
2. Launch a new instance with the following specifications:
   - Instance type: i3.metal
   - AMI: Ubuntu 20.04 LTS or Amazon Linux 2
   - Storage: Default (NVMe SSD)
   - Security Group: Allow SSH (port 22)
3. Connect to the instance via SSH:
   ```
   ssh -i your-key.pem ubuntu@your-instance-ip
   ```

### Step 2: Install Prerequisites

```bash
# Update package lists
sudo apt-get update

# Install required tools
sudo apt-get install -y wget curl iptables-persistent

# Enable KVM module
sudo modprobe kvm
sudo modprobe kvm_intel # For Intel processors
# or
sudo modprobe kvm_amd # For AMD processors
```

### Step 3: Clone This Repository

```bash
git clone https://github.com/yourusername/fc-mvm.git
cd fc-mvm
```

### Step 4: Make the Script Executable

```bash
chmod +x main.sh
```

### Step 5: Run the Script to Launch 10 microVMs

```bash
sudo ./main.sh
```

## How It Works

1. **Resource Preparation**:
   - Downloads the Firecracker binary if not present
   - Downloads a Linux kernel and root filesystem
   - Creates required directories

2. **Network Configuration**:
   - Creates a bridge network (fcbridge0)
   - Configures NAT for internet access
   - Assigns each microVM a unique IP address

3. **MicroVM Launching**:
   - Creates 10 microVMs with unique IDs
   - Sets up networking for each microVM
   - Configures CPU and memory resources

## Networking Details

- Host bridge: 172.20.0.1/24 (fcbridge0)
- MicroVMs: 172.20.0.2 to 172.20.0.11
- Each microVM has a unique MAC address

## Monitoring and Management

- Log files are stored in the `logs/` directory
- Each microVM has its own log file
- Process IDs are saved for each microVM

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   - Run the script with sudo

2. **Network Issues**:
   - Check that the bridge interface is created correctly
   - Verify iptables rules are set up

3. **Firecracker Errors**:
   - Check the log files for specific error messages
   - Verify KVM is loaded and working

### Checking Status

```bash
# List running Firecracker processes
ps aux | grep firecracker

# Check network configuration
ip addr show fcbridge0
```

## Next Steps

- Part 2: Deploy Deno applications to each microVM
- Part 3: Configure API endpoints and test with curl

## References

- [Firecracker GitHub Repository](https://github.com/firecracker-microvm/firecracker)
- [Firecracker Demo](https://github.com/firecracker-microvm/firecracker-demo)
- [Firecracker Documentation](https://firecracker-microvm.github.io/)