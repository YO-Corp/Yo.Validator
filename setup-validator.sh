#!/bin/bash

# YO Network Validator Setup Script
# Automated setup for YO Network validator node

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
CHAIN_ID="yo_100892-1"
NETWORK_NAME="yo-network"
BOOTNODE_IP="194.164.150.169"
EVMOS_VERSION="v20.0.0"
HOME_DIR="$(pwd)"

printf "${PURPLE}"
printf "╔══════════════════════════════════════════════════════════════╗\n"
printf "║                   YO Network Validator Setup                 ║\n"
printf "║              🇮🇳 Made in India • Enterprise Grade              ║\n"
printf "╚══════════════════════════════════════════════════════════════╝\n"
printf "${NC}\n"

printf "${GREEN}🚀 Starting YO Network Validator Setup...${NC}\n"
printf "${BLUE}Chain ID: $CHAIN_ID${NC}\n"
printf "${BLUE}Network: $NETWORK_NAME${NC}\n"
printf "${BLUE}Bootnode: $BOOTNODE_IP${NC}\n"
printf "${BLUE}Using existing YO genesis configuration${NC}\n"
printf "\n"

# Detect OS and architecture
printf "${YELLOW}🔍 Detecting system configuration...${NC}\n"
OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
    "Darwin")
        printf "${BLUE}📱 Detected: macOS ($ARCH)${NC}\n"
        ;;
    "Linux")
        printf "${BLUE}🐧 Detected: Linux ($ARCH)${NC}\n"
        ;;
    *)
        printf "${RED}❌ Unsupported operating system: $OS${NC}\n"
        exit 1
        ;;
esac

# Check system requirements
printf "${YELLOW}⚙️ Checking system requirements...${NC}\n"

# Check available memory
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}' 2>/dev/null || echo "0")
if [ "$MEMORY_GB" -lt 4 ]; then
    printf "${RED}⚠️ Warning: Less than 4GB RAM detected. Minimum 8GB recommended.${NC}\n"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    printf "${GREEN}✅ Memory: ${MEMORY_GB}GB RAM${NC}\n"
fi

# Check available disk space
DISK_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_GB" -lt 100 ]; then
    printf "${RED}⚠️ Warning: Less than 100GB disk space available. Minimum 200GB recommended.${NC}\n"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    printf "${GREEN}✅ Disk Space: ${DISK_GB}GB available${NC}\n"
fi

# Install dependencies
printf "${YELLOW}📦 Installing dependencies...${NC}\n"

if [ "$OS" = "Linux" ]; then
    # Update package list
    sudo apt update -qq
    
    # Install required packages
    sudo apt install -y curl wget jq unzip
    
    printf "${GREEN}✅ Dependencies installed successfully${NC}\n"
elif [ "$OS" = "Darwin" ]; then
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        printf "${YELLOW}Installing Homebrew...${NC}\n"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install dependencies
    brew install curl wget jq
    
    printf "${GREEN}✅ Dependencies verified${NC}\n"
fi

# Download Evmos binary
printf "${YELLOW}📥 Downloading Evmos binary...${NC}\n"

case "$OS" in
    "Darwin")
        if [ "$ARCH" = "arm64" ]; then
            BINARY_URL="https://github.com/evmos/evmos/releases/download/${EVMOS_VERSION}/evmos_20.0.0_Darwin_arm64.tar.gz"
        else
            BINARY_URL="https://github.com/evmos/evmos/releases/download/${EVMOS_VERSION}/evmos_20.0.0_Darwin_x86_64.tar.gz"
        fi
        ;;
    "Linux")
        if [ "$ARCH" = "aarch64" ]; then
            BINARY_URL="https://github.com/evmos/evmos/releases/download/${EVMOS_VERSION}/evmos_20.0.0_Linux_arm64.tar.gz"
        else
            BINARY_URL="https://github.com/evmos/evmos/releases/download/${EVMOS_VERSION}/evmos_20.0.0_Linux_amd64.tar.gz"
        fi
        ;;
esac

# Download and install binary
cd /tmp
wget -O evmos.tar.gz "$BINARY_URL"
tar -xzf evmos.tar.gz

# Find the evmosd binary
EVMOSD_PATH=$(find . -name "evmosd" -type f 2>/dev/null | head -n 1)
if [ -z "$EVMOSD_PATH" ]; then
    printf "${RED}❌ evmosd binary not found in extracted files${NC}\n"
    exit 1
fi

printf "${GREEN}Found evmosd at: $EVMOSD_PATH${NC}\n"
sudo mv "$EVMOSD_PATH" /usr/local/bin/evmosd
sudo chmod +x /usr/local/bin/evmosd
cd "$HOME_DIR"

printf "${GREEN}✅ Evmos binary installed successfully${NC}\n"

# Create directory structure
printf "${YELLOW}📁 Creating directory structure...${NC}\n"

mkdir -p config
mkdir -p validator
mkdir -p scripts
mkdir -p data
mkdir -p logs

printf "${GREEN}✅ Directory structure created${NC}\n"

# Copy existing genesis file
printf "${YELLOW}⚙️ Using existing YO genesis configuration...${NC}\n"

# Check if the genesis file exists in the parent created directory
GENESIS_SOURCE="../created/config/genesis.json"
if [ -f "$GENESIS_SOURCE" ]; then
    cp "$GENESIS_SOURCE" config/genesis.json
    printf "${GREEN}✅ Genesis configuration copied from created directory${NC}\n"
elif [ -f "config/genesis.json" ]; then
    printf "${GREEN}✅ Genesis configuration already exists${NC}\n"
else
    printf "${RED}❌ Genesis file not found. Please ensure the created directory exists.${NC}\n"
    exit 1
fi

# Create static nodes configuration
printf "${YELLOW}🌐 Creating network configuration...${NC}\n"

cat > config/static-nodes.json << EOF
[
  "/ip4/$BOOTNODE_IP/tcp/26656/p2p/16Uiu2HAmASDnBQRYq2uJHzqiUdkVGJGFMoLHJnC9Tm4qr9b7aXvC"
]
EOF

printf "${GREEN}✅ Network configuration created${NC}\n"

# Create Evmos configuration
printf "${YELLOW}⚙️ Creating Evmos configuration...${NC}\n"

cat > config/config.toml << 'EOF'
# YO Network Validator Configuration

# Base Configuration
proxy_app = "tcp://127.0.0.1:26658"
moniker = "yo-validator"
fast_sync = true

# RPC Server Configuration
[rpc]
laddr = "tcp://0.0.0.0:26657"
cors_allowed_origins = ["*"]
cors_allowed_methods = ["HEAD", "GET", "POST"]
cors_allowed_headers = ["Origin", "Accept", "Content-Type", "X-Requested-With", "X-Server-Time"]
max_open_connections = 900
max_subscription_clients = 100
max_subscriptions_per_client = 5
timeout_broadcast_tx_commit = "10s"

# P2P Configuration
[p2p]
laddr = "tcp://0.0.0.0:26656"
external_address = ""
seeds = ""
persistent_peers = ""
max_num_inbound_peers = 40
max_num_outbound_peers = 10
flush_throttle_timeout = "100ms"
max_packet_msg_payload_size = 1024
send_rate = 5120000
recv_rate = 5120000

# Mempool Configuration
[mempool]
size = 5000
cache_size = 10000

# Consensus Configuration
[consensus]
timeout_propose = "3s"
timeout_propose_delta = "500ms"
timeout_prevote = "1s"
timeout_prevote_delta = "500ms"
timeout_precommit = "1s"
timeout_precommit_delta = "500ms"
timeout_commit = "2s"
create_empty_blocks = true
create_empty_blocks_interval = "0s"
peer_gossip_sleep_duration = "100ms"
peer_query_maj23_sleep_duration = "2s"

# Instrumentation Configuration
[instrumentation]
prometheus = true
prometheus_listen_addr = ":26660"
max_open_connections = 3
namespace = "tendermint"
EOF

printf "${GREEN}✅ Evmos configuration created${NC}\n"

# Create app.toml for Evmos application configuration
cat > config/app.toml << 'EOF'
# YO Network Application Configuration

# Base Configuration
minimum-gas-prices = "0.0001ayo"
pruning = "nothing"
pruning-keep-recent = "0"
pruning-interval = "0"
halt-height = 0
halt-time = 0
min-retain-blocks = 0
inter-block-cache = true
index-events = []

# JSON-RPC Configuration
[json-rpc]
enable = true
address = "0.0.0.0:8545"
ws-address = "0.0.0.0:8546"
api = "eth,txpool,personal,net,debug,web3"
gas-cap = 50000000
txfee-cap = 100
enable-unsafe-cors = true

# gRPC Configuration  
[grpc]
enable = true
address = "0.0.0.0:9090"

# gRPC Web Configuration
[grpc-web]
enable = true
address = "0.0.0.0:9091"
enable-unsafe-cors = true

# State Sync Configuration
[state-sync]
snapshot-interval = 1000
snapshot-keep-recent = 2

# EVM Configuration
[evm]
tracer = ""
max-tx-gas-wanted = 500000

# Fee Market Configuration
[feemarket]
enable = true
EOF

printf "${GREEN}✅ Evmos application configuration created${NC}\n"

# Create startup script (instead of Docker for simplicity)
printf "${YELLOW}� Creating startup script...${NC}\n"

cat > start-validator.sh << 'EOF'
#!/bin/bash

# YO Network Validator Start Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${GREEN}🚀 Starting YO Network Validator...${NC}\n"

# Check if evmosd is available
if ! command -v evmosd &> /dev/null && [ ! -f "/usr/local/bin/evmosd" ]; then
    printf "${RED}❌ evmosd binary not found. Please run setup-validator.sh first.${NC}\n"
    exit 1
fi

# Use full path if evmosd is not in PATH
if [ -f "/usr/local/bin/evmosd" ] && ! command -v evmosd &> /dev/null; then
    EVMOSD_CMD="/usr/local/bin/evmosd"
else
    EVMOSD_CMD="evmosd"
fi

# Check if already running
if pgrep -f "evmosd start" > /dev/null; then
    printf "${YELLOW}⚠️ Validator is already running!${NC}\n"
    printf "${BLUE}Use './stop-validator.sh' to stop it first.${NC}\n"
    exit 0
fi

# Initialize if not done
if [ ! -d "data" ]; then
    printf "${YELLOW}🔧 Initializing validator...${NC}\n"
    $EVMOSD_CMD init yo-validator --chain-id yo_100892-1 --home .
    
    # Copy our genesis file
    cp config/genesis.json config/genesis.json.backup
    
    printf "${GREEN}✅ Validator initialized${NC}\n"
fi

# Start the validator
printf "${GREEN}🚀 Starting validator node...${NC}\n"

exec $EVMOSD_CMD start \
    --home . \
    --chain-id yo_100892-1 \
    --minimum-gas-prices=0.0001ayo \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --json-rpc.enable \
    --json-rpc.address 0.0.0.0:8545 \
    --json-rpc.ws-address 0.0.0.0:8546 \
    --rpc.laddr tcp://0.0.0.0:26657 \
    --p2p.laddr tcp://0.0.0.0:26656
EOF

chmod +x start-validator.sh

# Create environment file
printf "${YELLOW}📝 Creating environment configuration...${NC}\n"

cat > .env << EOF
# YO Network Validator Configuration

# Network Configuration
CHAIN_ID=yomlm_100892-1
NETWORK_NAME=yomlm-network
BOOTNODE_IP=$BOOTNODE_IP

# Validator Configuration
VALIDATOR_NAME=yomlm-validator
MIN_GAS_PRICE=0.0001ayomlm

# Network Ports
P2P_PORT=26656
RPC_PORT=26657
JSON_RPC_PORT=8545
WS_PORT=8546
GRPC_PORT=9090

# Evmos Configuration
EVMOS_VERSION=$EVMOS_VERSION

# Security
ENABLE_METRICS=true
ENABLE_LOGGING=true
LOG_LEVEL=info

# Paths
DATA_PATH=./data
CONFIG_PATH=./config
EOF

printf "${GREEN}✅ Environment configuration created${NC}\n"

# Generate validator keys
printf "${YELLOW}🔐 Generating validator keys...${NC}\n"

# Create validator key using evmosd
if [ ! -f "config/node_key.json" ]; then
    printf "${YELLOW}Creating validator identity...${NC}\n"
    
    # Use full path if evmosd is not in PATH
    if [ -f "/usr/local/bin/evmosd" ] && ! command -v evmosd &> /dev/null; then
        EVMOSD_CMD="/usr/local/bin/evmosd"
    else
        EVMOSD_CMD="evmosd"
    fi
    
    # Initialize tendermint for key generation
    $EVMOSD_CMD init temp-validator --chain-id $CHAIN_ID --home ./temp_init
    
    # Copy the generated keys
    cp ./temp_init/config/node_key.json config/
    cp ./temp_init/config/priv_validator_key.json config/
    
    # Clean up temp directory
    rm -rf ./temp_init
    
    printf "${GREEN}✅ Validator keys generated${NC}\n"
    printf "${BLUE}🔑 Node key stored in: config/node_key.json${NC}\n"
    printf "${BLUE}🔑 Validator key stored in: config/priv_validator_key.json${NC}\n"
    printf "${RED}⚠️ IMPORTANT: Backup these keys securely!${NC}\n"
else
    printf "${YELLOW}⚠️ Validator keys already exist${NC}\n"
fi

# Create management scripts
printf "${YELLOW}📜 Creating management scripts...${NC}\n"

# Stop validator script
cat > stop-validator.sh << 'EOF'
#!/bin/bash

# YO Network Validator Stop Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${YELLOW}� Stopping YO Network Validator...${NC}\n"

# Stop the validator
pkill -f "evmosd start" || printf "${YELLOW}No validator process found${NC}\n"

printf "${GREEN}✅ Validator stopped successfully!${NC}\n"
EOF

chmod +x stop-validator.sh

# Status check script
cat > check-status.sh << 'EOF'
#!/bin/bash

# YO Network Validator Status Check

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${BLUE}📊 YO Network Validator Status${NC}\n"
printf "═══════════════════════════════════════\n"

# Check if process is running
if pgrep -f "evmosd start" > /dev/null; then
    printf "${GREEN}✅ Validator Status: RUNNING${NC}\n"
    
    # Get process info
    printf "\n${YELLOW}📈 Process Information:${NC}\n"
    ps aux | grep "evmosd start" | grep -v grep | awk '{printf "PID: %s, CPU: %s%%, MEM: %s%%\n", $2, $3, $4}'
    
    # Check network connectivity
    printf "\n${YELLOW}🌐 Network Status:${NC}\n"
    BLOCK_NUMBER=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null || echo "N/A")
    
    if [ "$BLOCK_NUMBER" != "N/A" ] && [ "$BLOCK_NUMBER" != "null" ]; then
        BLOCK_DECIMAL=$((16#${BLOCK_NUMBER#0x}))
        printf "${GREEN}✅ Current Block: $BLOCK_DECIMAL${NC}\n"
        
        # Check if syncing
        SYNCING=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
          -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null || echo "N/A")
        
        if [ "$SYNCING" = "false" ]; then
            printf "${GREEN}✅ Sync Status: SYNCED${NC}\n"
        else
            printf "${YELLOW}⚠️ Sync Status: SYNCING${NC}\n"
        fi
    else
        printf "${RED}❌ JSON-RPC not responding${NC}\n"
    fi
    
    printf "\n${YELLOW}📋 Quick Commands:${NC}\n"
    printf "${BLUE}- Stop validator: ./stop-validator.sh${NC}\n"
    printf "${BLUE}- Restart: ./stop-validator.sh && ./start-validator.sh${NC}\n"
    printf "${BLUE}- Health check: ./scripts/health-check.sh${NC}\n"
    
else
    printf "${RED}❌ Validator Status: STOPPED${NC}\n"
    printf "${BLUE}Run './start-validator.sh' to start the validator${NC}\n"
fi

printf "\n"
EOF

chmod +x check-status.sh

# Create additional utility scripts
cat > scripts/health-check.sh << 'EOF'
#!/bin/bash

# YO Network Validator Health Check

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

printf "${YELLOW}🏥 YO Validator Health Check${NC}\n"
printf "════════════════════════════════════\n"

# Check if process is running
printf "Checking validator process... "
if pgrep -f "evmosd start" > /dev/null; then
    printf "${GREEN}✅ RUNNING${NC}\n"
else
    printf "${RED}❌ NOT RUNNING${NC}\n"
    printf "\n"
    exit 1
fi

# Check if RPC is responding
printf "Checking JSON-RPC endpoint... "
if curl -s -f http://localhost:8545 > /dev/null; then
    printf "${GREEN}✅ HEALTHY${NC}\n"
else
    printf "${RED}❌ UNHEALTHY${NC}\n"
fi

# Check if syncing
printf "Checking sync status... "
SYNCING=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null)

if [ "$SYNCING" = "false" ]; then
    printf "${GREEN}✅ SYNCED${NC}\n"
elif [ "$SYNCING" = "null" ] || [ -z "$SYNCING" ]; then
    printf "${RED}❌ RPC ERROR${NC}\n"
else
    printf "${YELLOW}⚠️ SYNCING${NC}\n"
fi

# Check current block
printf "Checking current block... "
BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null)

if [ "$BLOCK" != "null" ] && [ -n "$BLOCK" ]; then
    BLOCK_NUM=$((16#${BLOCK#0x}))
    printf "${GREEN}✅ Block $BLOCK_NUM${NC}\n"
else
    printf "${RED}❌ ERROR${NC}\n"
fi

printf "\n"
EOF

chmod +x scripts/health-check.sh

# Create key backup script
cat > scripts/backup-keys.sh << 'EOF'
#!/bin/bash

# YO Network Key Backup Script

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"

printf "${YELLOW}🔐 Creating key backup...${NC}\n"

mkdir -p "$BACKUP_DIR"

if [ -f "config/node_key.json" ]; then
    cp config/node_key.json "$BACKUP_DIR/"
    printf "${GREEN}✅ Node key backed up${NC}\n"
fi

if [ -f "config/priv_validator_key.json" ]; then
    cp config/priv_validator_key.json "$BACKUP_DIR/"
    printf "${GREEN}✅ Validator key backed up${NC}\n"
fi

if [ -f "data/priv_validator_state.json" ]; then
    cp data/priv_validator_state.json "$BACKUP_DIR/"
    printf "${GREEN}✅ Validator state backed up${NC}\n"
fi

printf "${GREEN}✅ Backup created in: $BACKUP_DIR${NC}\n"
printf "${RED}⚠️ Store this backup securely offline!${NC}\n"
EOF

chmod +x scripts/backup-keys.sh

# Create update script
cat > scripts/update-node.sh << 'EOF'
#!/bin/bash

# YO Network Update Script

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${YELLOW}🔄 Updating YO validator...${NC}\n"

# Stop validator if running
if pgrep -f "evmosd start" > /dev/null; then
    printf "${YELLOW}Stopping validator...${NC}\n"
    ./stop-validator.sh
    sleep 5
fi

# Backup current binary
if [ -f "/usr/local/bin/evmosd" ]; then
    sudo cp /usr/local/bin/evmosd /usr/local/bin/evmosd.backup
    printf "${GREEN}✅ Current binary backed up${NC}\n"
fi

# Download latest version (you may want to specify a version)
printf "${YELLOW}Downloading latest Evmos binary...${NC}\n"

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
    "Darwin")
        if [ "$ARCH" = "arm64" ]; then
            BINARY_URL="https://github.com/evmos/evmos/releases/download/v20.0.0/evmos_20.0.0_Darwin_arm64.tar.gz"
        else
            BINARY_URL="https://github.com/evmos/evmos/releases/download/v20.0.0/evmos_20.0.0_Darwin_x86_64.tar.gz"
        fi
        ;;
    "Linux")
        if [ "$ARCH" = "aarch64" ]; then
            BINARY_URL="https://github.com/evmos/evmos/releases/download/v20.0.0/evmos_20.0.0_Linux_arm64.tar.gz"
        else
            BINARY_URL="https://github.com/evmos/evmos/releases/download/v20.0.0/evmos_20.0.0_Linux_amd64.tar.gz"
        fi
        ;;
esac

cd /tmp
wget -O evmos.tar.gz "$BINARY_URL"
tar -xzf evmos.tar.gz

EVMOSD_PATH=$(find . -name "evmosd" -type f 2>/dev/null | head -n 1)
if [ -n "$EVMOSD_PATH" ]; then
    sudo mv "$EVMOSD_PATH" /usr/local/bin/evmosd
    sudo chmod +x /usr/local/bin/evmosd
    printf "${GREEN}✅ Binary updated successfully${NC}\n"
else
    printf "${RED}❌ Failed to find new binary${NC}\n"
    exit 1
fi

printf "${GREEN}✅ Update completed! You can now restart your validator.${NC}\n"
EOF

chmod +x scripts/update-node.sh

printf "${GREEN}✅ Management scripts created${NC}\n"

# Create license file
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2025 YO Network

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Setup completion
printf "\n${PURPLE}"
printf "╔══════════════════════════════════════════════════════════════╗\n"
printf "║                     Setup Complete! 🎉                       ║\n"
printf "╚══════════════════════════════════════════════════════════════╝\n"
printf "${NC}\n"

printf "${GREEN}✅ YO Network Validator setup completed successfully!${NC}\n"
printf "\n"
printf "${YELLOW}📋 Next Steps:${NC}\n"
printf "${BLUE}1. Review the configuration in .env file${NC}\n"
printf "${BLUE}2. Start your validator: ./start-validator.sh${NC}\n"
printf "${BLUE}3. Check status: ./check-status.sh${NC}\n"
printf "${BLUE}4. Monitor logs: docker logs yo-validator -f${NC}\n"
printf "\n"
printf "${YELLOW}🔐 Important:${NC}\n"
printf "${RED}- Backup your validator key: validator/key${NC}\n"
printf "${RED}- Keep your private key secure and never share it${NC}\n"
printf "${RED}- Ensure ports 30303, 8545, 8546 are open in firewall${NC}\n"
printf "\n"
printf "${YELLOW}🌐 Network Information:${NC}\n"
printf "${BLUE}- Chain ID: $CHAIN_ID${NC}\n"
printf "${BLUE}- Explorer: https://yoscan.net${NC}\n"
printf "${BLUE}- Public RPC: https://rpc.yoscan.net${NC}\n"
printf "\n"
printf "${GREEN}Happy validating! 🚀${NC}\n"
