#!/bin/bash

# YO Network Validator Start Script
# This script starts a YO validator node

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CHAIN_ID="yo_100892-1"
HOME_DIR="$(pwd)"

printf "${GREEN}🚀 Starting YO Network Validator...${NC}\n"
printf "${BLUE}Chain ID: $CHAIN_ID${NC}\n"
printf "${BLUE}Home Directory: $HOME_DIR${NC}\n"
printf "\n"

# Check if evmosd is installed
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

# Check if config exists
if [ ! -d "$HOME_DIR/config" ]; then
    printf "${RED}❌ Config directory not found. Please run setup-validator.sh first.${NC}\n"
    exit 1
fi

# Check if genesis file exists
if [ ! -f "$HOME_DIR/config/genesis.json" ]; then
    printf "${RED}❌ Genesis file not found. Please run setup-validator.sh first.${NC}\n"
    exit 1
fi

# Check if already running
if pgrep -f "evmosd start" > /dev/null; then
    printf "${YELLOW}⚠️ YO validator is already running!${NC}\n"
    printf "${BLUE}Process IDs:${NC}\n"
    pgrep -f "evmosd start"
    printf "\n"
    printf "${YELLOW}To stop the validator, run:${NC}\n"
    printf "${BLUE}./stop-validator.sh${NC}\n"
    printf "\n"
    printf "${YELLOW}To check status, run:${NC}\n"
    printf "${BLUE}./check-status.sh${NC}\n"
    exit 0
fi

# Initialize validator if not done
if [ ! -d "$HOME_DIR/data" ]; then
    printf "${YELLOW}� Initializing validator for first time...${NC}\n"
    $EVMOSD_CMD init yo-validator --chain-id $CHAIN_ID --home "$HOME_DIR"
    
    # Copy our genesis file over the generated one
    if [ -f "$HOME_DIR/config/genesis.json.backup" ]; then
        cp "$HOME_DIR/config/genesis.json.backup" "$HOME_DIR/config/genesis.json"
    fi
    
    printf "${GREEN}✅ Validator initialized${NC}\n"
fi

printf "${YELLOW}🌐 Network Endpoints:${NC}\n"
printf "${BLUE}  - JSON-RPC: http://localhost:8545${NC}\n"
printf "${BLUE}  - WebSocket: ws://localhost:8546${NC}\n"
printf "${BLUE}  - Tendermint RPC: http://localhost:26657${NC}\n"
printf "${BLUE}  - gRPC: http://localhost:9090${NC}\n"
printf "${BLUE}  - P2P: tcp://0.0.0.0:26656${NC}\n"
printf "\n"

printf "${GREEN}🚀 Starting YO validator node...${NC}\n"
printf "${YELLOW}Note: This will run in foreground. Use Ctrl+C to stop, or run with nohup for background.${NC}\n"
printf "\n"

# Start the validator node
exec $EVMOSD_CMD start \
    --home "$HOME_DIR" \
    --chain-id "$CHAIN_ID" \
    --minimum-gas-prices=0.0001ayo \
    --json-rpc.api eth,txpool,personal,net,debug,web3 \
    --json-rpc.enable \
    --json-rpc.address 0.0.0.0:8545 \
    --json-rpc.ws-address 0.0.0.0:8546 \
    --rpc.laddr tcp://0.0.0.0:26657 \
    --p2p.laddr tcp://0.0.0.0:26656 \
    --grpc.address 0.0.0.0:9090 \
    --log_level info \
    --metrics
