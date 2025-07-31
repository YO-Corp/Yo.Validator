#!/bin/bash

# YO Network Validator Key Generation Script
# This script generates validator keys for the YO network

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

printf "${PURPLE}"
printf "╔══════════════════════════════════════════════════════════════╗\n"
printf "║              YO Network Key Generation                    ║\n"
printf "╚══════════════════════════════════════════════════════════════╝\n"
printf "${NC}\n"

# Configuration
CHAIN_ID="yomlm_100892-1"
MONIKER="yomlm-validator"
HOME_DIR="$(pwd)"

printf "${GREEN}🔐 Generating YO validator keys...${NC}\n"
printf "${BLUE}Chain ID: $CHAIN_ID${NC}\n"
printf "${BLUE}Moniker: $MONIKER${NC}\n"
printf "${BLUE}Home Directory: $HOME_DIR${NC}\n"
printf "\n"

# Check if evmosd is installed
if ! command -v evmosd &> /dev/null && [ ! -f "/usr/local/bin/evmosd" ]; then
    printf "${RED}❌ evmosd binary not found.${NC}\n"
    printf "${BLUE}Please run './setup-validator.sh' first to install evmosd.${NC}\n"
    exit 1
fi

# Use full path if evmosd is not in PATH
if [ -f "/usr/local/bin/evmosd" ] && ! command -v evmosd &> /dev/null; then
    EVMOSD_CMD="/usr/local/bin/evmosd"
else
    EVMOSD_CMD="evmosd"
fi

# Check if keys already exist
if [ -f "config/node_key.json" ] || [ -f "config/priv_validator_key.json" ]; then
    printf "${YELLOW}⚠️ Validator keys already exist!${NC}\n"
    printf "\n${BLUE}Existing files:${NC}\n"
    [ -f "config/node_key.json" ] && printf "${BLUE}  - config/node_key.json${NC}\n"
    [ -f "config/priv_validator_key.json" ] && printf "${BLUE}  - config/priv_validator_key.json${NC}\n"
    printf "\n"
    
    read -p "Do you want to overwrite existing keys? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "${BLUE}Key generation cancelled.${NC}\n"
        exit 0
    fi
    
    printf "${YELLOW}Backing up existing keys...${NC}\n"
    mkdir -p backup
    [ -f "config/node_key.json" ] && cp "config/node_key.json" "backup/node_key.json.backup.$(date +%s)"
    [ -f "config/priv_validator_key.json" ] && cp "config/priv_validator_key.json" "backup/priv_validator_key.json.backup.$(date +%s)"
fi

# Create config directory if it doesn't exist
mkdir -p config

# Initialize validator to generate keys
printf "${YELLOW}� Initializing validator...${NC}\n"

# Create temporary directory for initialization
TEMP_INIT_DIR="temp_init_$(date +%s)"
$EVMOSD_CMD init "$MONIKER" --chain-id "$CHAIN_ID" --home "./$TEMP_INIT_DIR"

# Copy generated keys to our config directory
if [ -f "./$TEMP_INIT_DIR/config/node_key.json" ]; then
    cp "./$TEMP_INIT_DIR/config/node_key.json" config/
    printf "${GREEN}✅ Node key generated: config/node_key.json${NC}\n"
else
    printf "${RED}❌ Failed to generate node key${NC}\n"
    rm -rf "./$TEMP_INIT_DIR"
    exit 1
fi

if [ -f "./$TEMP_INIT_DIR/config/priv_validator_key.json" ]; then
    cp "./$TEMP_INIT_DIR/config/priv_validator_key.json" config/
    printf "${GREEN}✅ Validator key generated: config/priv_validator_key.json${NC}\n"
else
    printf "${RED}❌ Failed to generate validator key${NC}\n"
    rm -rf "./$TEMP_INIT_DIR"
    exit 1
fi

# Clean up temporary directory
rm -rf "./$TEMP_INIT_DIR"

# Set secure permissions
chmod 600 config/node_key.json config/priv_validator_key.json
printf "${GREEN}✅ Secure permissions set (600)${NC}\n"

# Display key information
printf "\n${YELLOW}🔍 Key Information:${NC}\n"

# Show node ID
NODE_ID=$(cat config/node_key.json | jq -r '.id' 2>/dev/null || echo "Unable to extract")
printf "${BLUE}Node ID: $NODE_ID${NC}\n"

# Show validator address
VALIDATOR_ADDRESS=$(cat config/priv_validator_key.json | jq -r '.address' 2>/dev/null || echo "Unable to extract")
printf "${BLUE}Validator Address: $VALIDATOR_ADDRESS${NC}\n"

# Show validator public key
VALIDATOR_PUBKEY=$(cat config/priv_validator_key.json | jq -r '.pub_key.value' 2>/dev/null || echo "Unable to extract")
printf "${BLUE}Validator PubKey: $VALIDATOR_PUBKEY${NC}\n"

printf "\n${RED}🔒 IMPORTANT SECURITY NOTES:${NC}\n"
printf "${RED}  - Keep these keys secure and private${NC}\n"
printf "${RED}  - Make regular backups of your keys${NC}\n"
printf "${RED}  - Never share your private keys${NC}\n"
printf "${RED}  - Store backups in multiple secure locations${NC}\n"

printf "\n${YELLOW}� Next Steps:${NC}\n"
printf "${BLUE}  1. Backup your keys: ./scripts/backup-keys.sh${NC}\n"
printf "${BLUE}  2. Start your validator: ./start-validator.sh${NC}\n"
printf "${BLUE}  3. Check status: ./check-status.sh${NC}\n"

printf "\n${GREEN}✅ Key generation completed successfully!${NC}\n"
