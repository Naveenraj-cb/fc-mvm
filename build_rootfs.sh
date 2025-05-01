#!/bin/bash

# Script to build a custom rootfs with Deno installed
set -e

WORKDIR="./rootfs_build"
MOUNT_DIR="$WORKDIR/mount"
BASE_ROOTFS="./resources/rootfs.ext4"
CUSTOM_ROOTFS="./resources/custom_rootfs.ext4"
DENO_VERSION="1.37.0"
DENO_ZIP="deno-x86_64-unknown-linux-gnu.zip"
DENO_URL="https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/$DENO_ZIP"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check for required tools and install them if missing
echo "Checking for required tools..."
for tool in unzip wget e2fsck resize2fs; do
  if ! command -v $tool &> /dev/null; then
    echo "$tool not found. Installing required packages..."
    apt-get update -y
    apt-get install -y unzip wget e2fsprogs
    break
  fi
done

# Create working directories
mkdir -p $WORKDIR $MOUNT_DIR

# Copy the base rootfs
if [ ! -f $BASE_ROOTFS ]; then
  echo "Base rootfs not found. Please run main.sh first to download it."
  exit 1
fi

echo "Creating a copy of the base rootfs..."
cp $BASE_ROOTFS $CUSTOM_ROOTFS

# Resize the rootfs to have more space for Deno
echo "Resizing rootfs to 300MB..."
truncate -s 300M $CUSTOM_ROOTFS
e2fsck -f $CUSTOM_ROOTFS
resize2fs $CUSTOM_ROOTFS

# Mount the rootfs
echo "Mounting rootfs..."
mount -o loop $CUSTOM_ROOTFS $MOUNT_DIR

# Download and install Deno
echo "Downloading Deno..."
cd $WORKDIR
wget $DENO_URL
unzip $DENO_ZIP

echo "Installing Deno in rootfs..."
cp deno $MOUNT_DIR/usr/local/bin/
chmod +x $MOUNT_DIR/usr/local/bin/deno

# Create the echo server script
mkdir -p $MOUNT_DIR/opt/deno
cat > $MOUNT_DIR/opt/deno/echo_server.js << 'EOF'
// Simple Deno echo server that returns the input along with the VM ID
import { serve } from "https://deno.land/std@0.150.0/http/server.ts";

const VM_ID = Deno.env.get("VM_ID") || "unknown";
const PORT = 8000;

console.log(`Starting echo server on VM ${VM_ID} at port ${PORT}...`);

serve(async (req) => {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;
  
  // Get request body if present
  let body = "";
  try {
    body = await req.text();
  } catch (e) {
    // No body or error reading body
  }
  
  const responseBody = JSON.stringify({
    vm_id: VM_ID,
    message: `Request received on VM ${VM_ID}`,
    timestamp: new Date().toISOString(),
    request: {
      method,
      path,
      body
    }
  }, null, 2);
  
  console.log(`VM ${VM_ID} processing request: ${method} ${path}`);
  
  return new Response(responseBody, {
    status: 200,
    headers: {
      "content-type": "application/json",
      "server": `FirecrackerVM-${VM_ID}`
    }
  });
}, { port: PORT });
EOF

# Create startup script
cat > $MOUNT_DIR/etc/init.d/start_deno_server << 'EOF'
#!/bin/sh

# Get VM ID from hostname
VM_ID=$(hostname | sed 's/.*-//')

# Set environment variable for Deno script
export VM_ID

# Start Deno server
cd /opt/deno
nohup /usr/local/bin/deno run --allow-net --allow-env echo_server.js > /var/log/deno_server.log 2>&1 &

# Wait briefly and check if server started
sleep 2
if pgrep -f "deno run" > /dev/null; then
  echo "Deno server started successfully on VM $VM_ID"
else
  echo "Failed to start Deno server on VM $VM_ID"
fi
EOF

chmod +x $MOUNT_DIR/etc/init.d/start_deno_server

# Add to startup
ln -sf /etc/init.d/start_deno_server $MOUNT_DIR/etc/rc3.d/S99start_deno_server

# Unmount
echo "Unmounting rootfs..."
umount $MOUNT_DIR

# Clean up
echo "Cleaning up..."
rm -rf $WORKDIR

echo "Custom rootfs with Deno has been created at $CUSTOM_ROOTFS"