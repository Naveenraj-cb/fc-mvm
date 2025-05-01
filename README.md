# Firecracker MicroVM Orchestration with Deno

This project demonstrates deploying and managing multiple Firecracker microVMs on AWS EC2 i3.metal instances, each running a Deno echo server.

## Project Overview

Firecracker is a lightweight virtualization technology developed by AWS for serverless computing platforms like Lambda and Fargate. This project provides tooling to:

1. **Part 1**: Automatically deploy 10 Firecracker microVMs
2. **Part 2**: Run a Deno echo server in each microVM that returns input along with VM ID
3. **Part 3**: Test the microVMs using curl requests to verify proper operation

## Requirements

- AWS EC2 i3.metal instance (recommended)
- Ubuntu 20.04 or Amazon Linux 2
- Root access
- Internet connectivity for downloading resources

## Project Structure

```
fc-mvm/
├── main.sh              # Main script for deploying microVMs with Deno
├── build_rootfs.sh      # Script to build custom rootfs with Deno installed
├── test_mvms.sh         # Script to test the Deno echo servers
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
sudo apt-get install -y wget curl iptables-persistent jq

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

### Step 4: Make the Scripts Executable

```bash
chmod +x main.sh build_rootfs.sh test_mvms.sh
```

### Step 5: Run the Script to Launch 10 microVMs with Deno

```bash
sudo ./main.sh
```

This script will:
1. Download the Firecracker binary, kernel, and base rootfs
2. Build a custom rootfs with Deno installed
3. Create a network bridge
4. Launch 10 microVMs with unique IDs and network configurations
5. Start a Deno echo server in each microVM
6. Generate a status file with information about each microVM

### Step 6: Test the Deno Echo Servers

```bash
# Test all microVMs
sudo ./test_mvms.sh

# Test a specific microVM (e.g., ID 3)
sudo ./test_mvms.sh 3
```

## How It Works

### Part 1: Deploying Firecracker MicroVMs

1. **Resource Preparation**:
   - Downloads the Firecracker binary
   - Downloads a Linux kernel and root filesystem
   - Creates required directories for logs and sockets

2. **Network Configuration**:
   - Creates a bridge network (fcbridge0)
   - Configures NAT for internet access
   - Assigns each microVM a unique IP address

3. **MicroVM Setup**:
   - Creates 10 microVMs with unique IDs
   - Sets up networking for each microVM
   - Configures CPU and memory resources

### Part 2: Deno Echo Server

1. **Custom Rootfs Creation**:
   - Extends the base rootfs to add more space
   - Installs Deno runtime
   - Adds a Deno echo server application

2. **Echo Server Features**:
   - Runs on port 8000 in each microVM
   - Returns the VM ID along with the request details
   - Starts automatically when the microVM boots

3. **VM Configuration**:
   - Each microVM has a unique hostname (fc-vm-0, fc-vm-1, etc.)
   - The Deno server uses this hostname to identify itself

### Part 3: Testing with Curl

The `test_mvms.sh` script:
1. Sends HTTP requests to each microVM
2. Verifies that the response includes the correct VM ID
3. Checks that the request payload is echoed back
4. Provides a summary of successful responses

## Networking Details

- Host bridge: 172.20.0.1/24 (fcbridge0)
- MicroVMs: 172.20.0.2 to 172.20.0.11
- Each microVM has a unique MAC address
- Each Deno server runs on port 8000

## Monitoring and Management

- Log files for Firecracker are stored in the `logs/` directory
- Each microVM has its own log file
- Process IDs are saved for each microVM
- The Deno server logs are stored in `/var/log/deno_server.log` within each microVM

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   - Run all scripts with sudo

2. **Network Issues**:
   - Check that the bridge interface is created correctly
   - Verify iptables rules are set up
   - Ensure port 8000 is accessible

3. **Firecracker Errors**:
   - Check the log files for specific error messages
   - Verify KVM is loaded and working

4. **Deno Server Not Responding**:
   - The server may take some time to start
   - Check server logs within the microVM
   - Verify network connectivity to the microVM

### Checking Status

```bash
# List running Firecracker processes
ps aux | grep firecracker

# Check network configuration
ip addr show fcbridge0

# View status of all microVMs
cat mvm_status.json

# Send a test request to microVM 0
curl -X POST -d "Hello VM" http://172.20.0.2:8000/
```

## References

- [Firecracker GitHub Repository](https://github.com/firecracker-microvm/firecracker)
- [Firecracker Demo](https://github.com/firecracker-microvm/firecracker-demo)
- [Firecracker Documentation](https://firecracker-microvm.github.io/)
- [Deno Documentation](https://deno.land/)