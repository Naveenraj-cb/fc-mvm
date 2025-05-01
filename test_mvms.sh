#!/bin/bash

# Script to test the Firecracker microVMs with Deno echo servers
set -e

# Configuration
STATUS_FILE="./mvm_status.json"
TIMEOUT=2  # seconds

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. Using grep/awk instead.${NC}"
    USE_JQ=false
else
    USE_JQ=true
fi

# Check if status file exists
if [ ! -f "$STATUS_FILE" ]; then
    echo -e "${RED}Error: Status file $STATUS_FILE not found.${NC}"
    echo "Please run main.sh first to create the microVMs."
    exit 1
fi

# Function to test a single microVM
test_mvm() {
    local id=$1
    local ip="172.20.0.$(($id + 2))"
    local port=8000
    local url="http://$ip:$port/"
    
    echo -e "\n${YELLOW}Testing microVM $id at $url${NC}"
    
    # Send a test payload
    local payload="Hello from test script to microVM $id!"
    
    # Try to connect with increasing timeouts
    for attempt in 1 2 3; do
        echo "Attempt $attempt with timeout $((TIMEOUT * attempt))s..."
        response=$(curl -s -m $((TIMEOUT * attempt)) -X POST -d "$payload" "$url" 2>/dev/null)
        status=$?
        
        if [ $status -eq 0 ] && [ ! -z "$response" ]; then
            # Successfully connected
            echo -e "${GREEN}Connection successful!${NC}"
            
            # Check if the response contains the VM ID
            if echo "$response" | grep -q "\"vm_id\":.*$id"; then
                echo -e "${GREEN}Response contains correct VM ID: $id${NC}"
            else
                echo -e "${RED}Response does not contain expected VM ID $id${NC}"
                echo "Response:"
                echo "$response"
            fi
            
            # Check if response includes our payload
            if echo "$response" | grep -q "$payload"; then
                echo -e "${GREEN}Response includes our payload${NC}"
            else
                echo -e "${YELLOW}Response does not include our payload${NC}"
                echo "Response:"
                echo "$response"
            fi
            
            return 0
        elif [ $status -eq 28 ]; then
            echo -e "${YELLOW}Connection timed out, retrying...${NC}"
        else
            echo -e "${RED}curl failed with status $status, retrying...${NC}"
        fi
    done
    
    echo -e "${RED}Failed to connect to microVM $id after 3 attempts${NC}"
    return 1
}

# Function to test all microVMs
test_all_mvms() {
    local success=0
    local total=0
    
    if $USE_JQ; then
        # Get the number of microVMs from the JSON file
        total=$(jq '. | length' "$STATUS_FILE")
    else
        # Count the number of IDs in the file
        total=$(grep -o '"id":' "$STATUS_FILE" | wc -l)
    fi
    
    echo "Testing $total microVMs..."
    
    for ((i=0; i<total; i++)); do
        if test_mvm $i; then
            success=$((success + 1))
        fi
    done
    
    echo -e "\n${GREEN}Test Summary:${NC}"
    echo "$success out of $total microVMs responded successfully"
    
    if [ $success -eq $total ]; then
        echo -e "${GREEN}All microVMs are working correctly!${NC}"
    else
        echo -e "${RED}Some microVMs failed to respond correctly.${NC}"
    fi
}

# Test a specific microVM if ID is provided
if [ $# -eq 1 ]; then
    test_mvm $1
else
    # Test all microVMs
    test_all_mvms
fi