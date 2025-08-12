#!/bin/bash

# YO Network Recreation Script
# This script recreates the network with reduced premine (1 billion) and YO denomination

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

# New configuration values
NEW_PREMINE="1000000000000000000000000000"  # 1 billion YO (with 18 decimals)
NEW_DENOM="YO"
NEW_BASE_DENOM="ayo"  # Base denomination (atomic units)
VALIDATOR_STAKE="1000000000000000000"  # 1 YO for initial validator stake

printf "${PURPLE}"
printf "╔═══════════════════════════════════════════════════════════════╗\n"
printf "║              YO Network Recreation Script                     ║\n"
printf "║         🔄 Updating to 1B YO Premine & YO Denomination       ║\n"
printf "╚═══════════════════════════════════════════════════════════════╝\n"
printf "${NC}\n"

printf "${GREEN}🔄 Starting YO Network recreation process...${NC}\n"
printf "${BLUE}Chain ID: $CHAIN_ID${NC}\n"
printf "${BLUE}New Premine: 1,000,000,000 YO${NC}\n"
printf "${BLUE}New Denomination: $NEW_DENOM${NC}\n"
printf "\n"

# Confirmation prompt
printf "${YELLOW}⚠️ WARNING: This will recreate the network configuration!${NC}\n"
printf "${RED}This will replace existing genesis and configuration files.${NC}\n"
printf "${YELLOW}Make sure to backup any important data before proceeding.${NC}\n"
printf "Do you want to continue? (y/N): "
read REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "${BLUE}Operation cancelled.${NC}\n"
    exit 0
fi

# Stop validator if running
printf "${YELLOW}🛑 Checking for running validator...${NC}\n"
if pgrep -f "evmosd start" > /dev/null; then
    printf "${YELLOW}Stopping existing validator...${NC}\n"
    ./stop-validator.sh || echo "No stop script found, killing process directly"
    pkill -f "evmosd start" || echo "No validator process found"
    sleep 3
    printf "${GREEN}✅ Validator stopped${NC}\n"
else
    printf "${GREEN}✅ No running validator found${NC}\n"
fi

# Check if evmosd is available
printf "${YELLOW}🔍 Checking Evmos binary...${NC}\n"
if [ -f "/usr/local/bin/evmosd" ] && ! command -v evmosd &> /dev/null; then
    EVMOSD_CMD="/usr/local/bin/evmosd"
elif command -v evmosd &> /dev/null; then
    EVMOSD_CMD="evmosd"
else
    printf "${RED}❌ evmosd binary not found. Please run setup-validator.sh first.${NC}\n"
    exit 1
fi

printf "${GREEN}✅ Found evmosd at: $EVMOSD_CMD${NC}\n"

# Clean existing data
printf "${YELLOW}🧹 Cleaning existing blockchain data...${NC}\n"
rm -rf data/
rm -rf config/genesis.json
rm -rf config/gentx/
rm -rf config/config.toml
rm -rf config/app.toml
rm -rf keyring-test/
mkdir -p config/gentx
mkdir -p data
echo "{}" > data/priv_validator_state.json
printf "${GREEN}✅ Existing data cleaned${NC}\n"

# Initialize fresh chain
printf "${YELLOW}🔧 Initializing fresh chain...${NC}\n"
$EVMOSD_CMD init yo-validator --chain-id $CHAIN_ID --home .

# Configure client settings
printf "${YELLOW}⚙️ Configuring client settings...${NC}\n"
$EVMOSD_CMD config chain-id $CHAIN_ID --home .
$EVMOSD_CMD config keyring-backend test --home .
$EVMOSD_CMD config node tcp://localhost:26657 --home .

# Generate validator key if not exists
if [ ! -f "config/priv_validator_key.json" ]; then
    printf "${YELLOW}🔑 Generating new validator key...${NC}\n"
    # Key will be generated during init
    printf "${GREEN}✅ Validator key generated${NC}\n"
fi

# Create new genesis with YO denomination
printf "${YELLOW}⚙️ Creating new genesis configuration...${NC}\n"

# Get validator address from the generated key
VALIDATOR_KEY_ADDRESS=$($EVMOSD_CMD keys add validator --keyring-backend test --home . --output json 2>/dev/null | jq -r '.address' || echo "")

if [ -z "$VALIDATOR_KEY_ADDRESS" ]; then
    printf "${YELLOW}Creating validator account...${NC}\n"
    echo -e "\n\n" | $EVMOSD_CMD keys add validator --keyring-backend test --home . --recover
    VALIDATOR_KEY_ADDRESS=$($EVMOSD_CMD keys show validator --keyring-backend test --home . --address)
fi

printf "${BLUE}Validator address: $VALIDATOR_KEY_ADDRESS${NC}\n"

# Add genesis account with YO tokens
printf "${YELLOW}💰 Adding genesis account with 1B YO tokens...${NC}\n"
$EVMOSD_CMD add-genesis-account $VALIDATOR_KEY_ADDRESS ${NEW_PREMINE}${NEW_BASE_DENOM} --home .

# Update genesis file to use YO denomination
printf "${YELLOW}📝 Updating genesis configuration for YO denomination...${NC}\n"

# Create a temporary Python script to update the genesis file
cat > update_genesis.py << 'EOF'
#!/usr/bin/env python3
import json
import sys

def update_genesis_for_yo():
    # Load genesis file
    with open('config/genesis.json', 'r') as f:
        genesis = json.load(f)
    
    # Update app_state for YO denomination
    app_state = genesis['app_state']
    
    # Update bank module
    if 'bank' in app_state:
        # Update supply
        if 'supply' in app_state['bank']:
            for supply in app_state['bank']['supply']:
                if supply['denom'] in ['ayomlm', 'aevmos']:
                    supply['denom'] = 'ayo'
                    supply['amount'] = '1000000000000000000000000000'  # 1B YO with 18 decimals
        
        # Update balances
        if 'balances' in app_state['bank']:
            for balance in app_state['bank']['balances']:
                if 'coins' in balance:
                    for coin in balance['coins']:
                        if coin['denom'] in ['ayomlm', 'aevmos']:
                            coin['denom'] = 'ayo'
                            coin['amount'] = '1000000000000000000000000000'
    
    # Update staking module
    if 'staking' in app_state:
        if 'params' in app_state['staking']:
            app_state['staking']['params']['bond_denom'] = 'ayo'
    
    # Update crisis module
    if 'crisis' in app_state:
        if 'constant_fee' in app_state['crisis']:
            app_state['crisis']['constant_fee']['denom'] = 'ayo'
    
    # Update gov module
    if 'gov' in app_state:
        if 'params' in app_state['gov']:
            if 'min_deposit' in app_state['gov']['params']:
                for deposit in app_state['gov']['params']['min_deposit']:
                    if deposit['denom'] in ['ayomlm', 'aevmos']:
                        deposit['denom'] = 'ayo'
                        deposit['amount'] = '10000000000000000000'  # 10 YO for proposals
            
            if 'expedited_min_deposit' in app_state['gov']['params']:
                for deposit in app_state['gov']['params']['expedited_min_deposit']:
                    if deposit['denom'] in ['aevmos', 'ayomlm']:
                        deposit['denom'] = 'ayo'
                        deposit['amount'] = '50000000000000000000'  # 50 YO for expedited proposals
    
    # Update inflation module
    if 'inflation' in app_state:
        if 'params' in app_state['inflation']:
            app_state['inflation']['params']['mint_denom'] = 'ayo'
    
    # Update evm module
    if 'evm' in app_state:
        if 'params' in app_state['evm']:
            app_state['evm']['params']['evm_denom'] = 'ayo'
    
    # Update feemarket module
    if 'feemarket' in app_state:
        if 'params' in app_state['feemarket']:
            app_state['feemarket']['params']['min_gas_price'] = '0.000000000000000000'
    
    # Update distribution module
    if 'distribution' in app_state:
        if 'params' in app_state['distribution']:
            app_state['distribution']['params']['community_tax'] = '0.020000000000000000'
    
    # Save updated genesis
    with open('config/genesis.json', 'w') as f:
        json.dump(genesis, f, indent=2)
    
    print("✅ Genesis file updated for YO denomination (ayo)")

if __name__ == "__main__":
    update_genesis_for_yo()
EOF

# Run the Python script to update genesis
python3 update_genesis.py
rm update_genesis.py

printf "${GREEN}✅ Genesis configuration updated for YO denomination${NC}\n"

# Verify chain ID in genesis before proceeding
GENESIS_CHAIN_ID=$(jq -r '.chain_id' config/genesis.json)
printf "${BLUE}Genesis Chain ID: $GENESIS_CHAIN_ID${NC}\n"
if [ "$GENESIS_CHAIN_ID" != "$CHAIN_ID" ]; then
    printf "${RED}❌ Chain ID mismatch! Expected: $CHAIN_ID, Found: $GENESIS_CHAIN_ID${NC}\n"
    exit 1
fi

# Create genesis transaction for validator
printf "${YELLOW}🏗️ Creating genesis transaction...${NC}\n"
$EVMOSD_CMD gentx validator ${VALIDATOR_STAKE}ayo \
    --chain-id $CHAIN_ID \
    --moniker "yo-validator" \
    --commission-rate "0.10" \
    --commission-max-rate "0.20" \
    --commission-max-change-rate "0.01" \
    --min-self-delegation "1" \
    --keyring-backend test \
    --home . \
    --yes

# Collect genesis transactions
printf "${YELLOW}📋 Collecting genesis transactions...${NC}\n"
$EVMOSD_CMD collect-gentxs --home .

# Validate genesis
printf "${YELLOW}✅ Validating genesis configuration...${NC}\n"
$EVMOSD_CMD validate-genesis --home .

printf "${GREEN}✅ Genesis validation successful${NC}\n"

# Update configuration files for YO denomination
printf "${YELLOW}⚙️ Updating configuration files...${NC}\n"

# Update app.toml
cat > config/app.toml << EOF
# YO Network Application Configuration

# Base Configuration
minimum-gas-prices = "0.0001ayo"
# Archive node: keep full history to allow queries at any past height
pruning = "nothing"
# When pruning = "nothing", the following are ignored but kept here for clarity
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
# Take snapshots periodically to help other nodes state-sync (optional)
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

# Update environment file
cat > .env << EOF
# YO Network Validator Configuration (Updated for YO denomination)

# Network Configuration
CHAIN_ID=$CHAIN_ID
NETWORK_NAME=$NETWORK_NAME
BOOTNODE_IP=$BOOTNODE_IP

# Token Configuration
NATIVE_DENOM=YO
BASE_DENOM=ayo
PREMINE_AMOUNT=1000000000  # 1 billion YO

# Validator Configuration
VALIDATOR_NAME=yo-validator
MIN_GAS_PRICE=0.0001ayo

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

# Update start script to use YO denomination
cat > start-validator.sh << 'EOF'
#!/bin/bash

# YO Network Validator Start Script (Updated for YO denomination)

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${GREEN}🚀 Starting YO Network Validator (YO denomination)...${NC}\n"

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

# Start the validator with YO denomination
printf "${GREEN}🚀 Starting validator node with YO denomination...${NC}\n"

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

# Create network information file
cat > NETWORK_INFO.md << EOF
# YO Network Information

## Updated Configuration

### Token Details
- **Native Token**: YO
- **Base Denomination**: ayo (atomic units)
- **Total Premine**: 1,000,000,000 YO (1 billion)
- **Decimals**: 18

### Network Details
- **Chain ID**: yo_100892-1
- **Network Name**: yo-network
- **Consensus**: CometBFT (Tendermint)
- **EVM Compatibility**: Full

### Validator Details
- **Initial Stake**: 1 YO
- **Commission Rate**: 10%
- **Max Commission**: 20%
- **Min Self Delegation**: 1 YO

### Gas Configuration
- **Minimum Gas Price**: 0.0001 ayo
- **Gas Cap**: 50,000,000
- **Transaction Fee Cap**: 100 YO

### Governance
- **Minimum Deposit**: 10 YO
- **Expedited Minimum Deposit**: 50 YO
- **Voting Period**: 30 seconds (testnet setting)
- **Community Tax**: 2%

## Migration Notes

This network recreation:
1. Changed denomination from 'ayomlm' to 'ayo' (atomic YO units)
2. Reduced premine from ~1 trillion to 1 billion YO
3. Updated all module configurations for ayo denomination
4. Updated chain ID to 'yo_100892-1'
5. Reset blockchain state to genesis
EOF

# Create verification script
cat > verify-network.sh << 'EOF'
#!/bin/bash

# YO Network Verification Script

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${BLUE}🔍 YO Network Configuration Verification${NC}\n"
printf "═══════════════════════════════════════════════\n"

# Check genesis file
printf "\n${YELLOW}📋 Genesis Configuration:${NC}\n"
if [ -f "config/genesis.json" ]; then
    CHAIN_ID=$(jq -r '.chain_id' config/genesis.json)
    printf "Chain ID: ${GREEN}$CHAIN_ID${NC}\n"
    
    # Check supply
    SUPPLY=$(jq -r '.app_state.bank.supply[0].amount' config/genesis.json 2>/dev/null || echo "N/A")
    DENOM=$(jq -r '.app_state.bank.supply[0].denom' config/genesis.json 2>/dev/null || echo "N/A")
    printf "Supply: ${GREEN}$SUPPLY $DENOM${NC}\n"
    
    # Check staking denom
    BOND_DENOM=$(jq -r '.app_state.staking.params.bond_denom' config/genesis.json 2>/dev/null || echo "N/A")
    printf "Bond Denom: ${GREEN}$BOND_DENOM${NC}\n"
    
    # Check EVM denom
    EVM_DENOM=$(jq -r '.app_state.evm.params.evm_denom' config/genesis.json 2>/dev/null || echo "N/A")
    printf "EVM Denom: ${GREEN}$EVM_DENOM${NC}\n"
else
    printf "${RED}❌ Genesis file not found${NC}\n"
fi

# Check app configuration
printf "\n${YELLOW}⚙️ App Configuration:${NC}\n"
if [ -f "config/app.toml" ]; then
    MIN_GAS=$(grep "minimum-gas-prices" config/app.toml | cut -d'"' -f2 2>/dev/null || echo "N/A")
    printf "Minimum Gas Prices: ${GREEN}$MIN_GAS${NC}\n"
else
    printf "${RED}❌ App config not found${NC}\n"
fi

# Check environment
printf "\n${YELLOW}🌐 Environment Configuration:${NC}\n"
if [ -f ".env" ]; then
    NATIVE_DENOM=$(grep "NATIVE_DENOM" .env | cut -d'=' -f2 2>/dev/null || echo "N/A")
    PREMINE=$(grep "PREMINE_AMOUNT" .env | cut -d'=' -f2 2>/dev/null || echo "N/A")
    printf "Native Denom: ${GREEN}$NATIVE_DENOM${NC}\n"
    printf "Premine Amount: ${GREEN}$PREMINE${NC}\n"
else
    printf "${RED}❌ Environment file not found${NC}\n"
fi

printf "\n${GREEN}✅ Network verification completed${NC}\n"
EOF

chmod +x verify-network.sh

# Run verification
printf "${YELLOW}🔍 Running network verification...${NC}\n"
./verify-network.sh

# Recreation completion
printf "\n${PURPLE}"
printf "╔═══════════════════════════════════════════════════════════════╗\n"
printf "║                  Network Recreation Complete! 🎉             ║\n"
printf "╚═══════════════════════════════════════════════════════════════╝\n"
printf "${NC}\n"

printf "${GREEN}✅ YO Network successfully recreated with new configuration!${NC}\n"
printf "\n"
printf "${YELLOW}📋 Summary of Changes:${NC}\n"
printf "${BLUE}• Denomination changed from 'ayomlm' to 'ayo' (atomic YO)${NC}\n"
printf "${BLUE}• Premine reduced to 1,000,000,000 YO (1 billion)${NC}\n"
printf "${BLUE}• All modules updated for YO denomination${NC}\n"
printf "${BLUE}• Chain ID updated to 'yo_100892-1'${NC}\n"
printf "${BLUE}• Fresh blockchain state (genesis reset)${NC}\n"
printf "\n"
printf "${YELLOW}🚀 Next Steps:${NC}\n"
printf "${BLUE}1. Start your validator: ./start-validator.sh${NC}\n"
printf "${BLUE}2. Check status: ./check-status.sh${NC}\n"
printf "${BLUE}3. Verify configuration: ./verify-network.sh${NC}\n"
printf "${BLUE}4. Review network info: cat NETWORK_INFO.md${NC}\n"
printf "\n"
printf "${YELLOW}🔐 Important:${NC}\n"
printf "${RED}• This is a completely new network state${NC}\n"
printf "${RED}• Previous blockchain data has been reset${NC}\n"
printf "${RED}• Make sure to inform all participants about the changes${NC}\n"
printf "\n"
printf "${GREEN}Happy validating with YO! 🚀${NC}\n"
