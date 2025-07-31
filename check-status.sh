#!/bin/bash

# YO Network Validator Status Check

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

printf "${PURPLE}"
printf "╔══════════════════════════════════════════════════════════════╗\n"
printf "║               YO Network Validator Status                 ║\n"
printf "╚══════════════════════════════════════════════════════════════╝\n"
printf "${NC}\n"

# Check if validator process is running
if pgrep -f "evmosd start" > /dev/null; then
    printf "${GREEN}✅ Validator Status: RUNNING${NC}\n"
    
    # Get process information
    printf "\n${YELLOW}� Process Information:${NC}\n"
    pgrep -f "evmosd start" | while read pid; do
        ps -p $pid -o pid,ppid,%cpu,%mem,etime,cmd --no-headers | awk '{printf "PID: %s | CPU: %s%% | MEM: %s%% | Runtime: %s\n", $1, $3, $4, $5}'
    done
    
    # Check network connectivity
    printf "\n${YELLOW}🌐 Network Status:${NC}\n"
    
    # Test JSON-RPC endpoint
    printf "Testing JSON-RPC endpoint... "
    if curl -s -f http://localhost:8545 > /dev/null 2>&1; then
        printf "${GREEN}✅ ACTIVE${NC}\n"
        
        # Get current block number
        BLOCK_NUMBER=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
          -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null || echo "N/A")
        
        if [ "$BLOCK_NUMBER" != "N/A" ] && [ "$BLOCK_NUMBER" != "null" ]; then
            BLOCK_DECIMAL=$((16#${BLOCK_NUMBER#0x}))
            printf "${GREEN}✅ Current Block: $BLOCK_DECIMAL${NC}\n"
        else
            printf "${RED}❌ Unable to get block number${NC}\n"
        fi
        
        # Check sync status via Tendermint RPC
        printf "Testing Tendermint RPC... "
        if curl -s -f http://localhost:26657/status > /dev/null 2>&1; then
            printf "${GREEN}✅ ACTIVE${NC}\n"
            
            # Get sync info
            SYNC_INFO=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up' 2>/dev/null || echo "N/A")
            if [ "$SYNC_INFO" = "false" ]; then
                printf "${GREEN}✅ Sync Status: SYNCED${NC}\n"
            elif [ "$SYNC_INFO" = "true" ]; then
                printf "${YELLOW}⚠️ Sync Status: SYNCING${NC}\n"
            else
                printf "${RED}❌ Unable to check sync status${NC}\n"
            fi
            
            # Get peer count from Tendermint
            PEER_COUNT=$(curl -s http://localhost:26657/net_info | jq -r '.result.n_peers' 2>/dev/null || echo "N/A")
            if [ "$PEER_COUNT" != "N/A" ] && [ "$PEER_COUNT" != "null" ]; then
                if [ "$PEER_COUNT" -gt 0 ]; then
                    printf "${GREEN}✅ Connected Peers: $PEER_COUNT${NC}\n"
                else
                    printf "${YELLOW}⚠️ No peers connected${NC}\n"
                fi
            else
                printf "${RED}❌ Unable to check peer count${NC}\n"
            fi
            
        else
            printf "${RED}❌ INACTIVE${NC}\n"
        fi
        
    else
        printf "${RED}❌ INACTIVE${NC}\n"
    fi
    
    # Check disk usage
    printf "\n${YELLOW}💾 Storage Information:${NC}\n"
    if [ -d "data" ]; then
        DATA_SIZE=$(du -sh data 2>/dev/null | cut -f1)
        printf "${BLUE}Data Directory Size: $DATA_SIZE${NC}\n"
    fi
    
    # Check validator keys
    printf "\n${YELLOW}🔐 Security Status:${NC}\n"
    if [ -f "config/node_key.json" ]; then
        printf "${GREEN}✅ Node Key: Present${NC}\n"
    else
        printf "${RED}❌ Node Key: Missing${NC}\n"
    fi
    
    if [ -f "config/priv_validator_key.json" ]; then
        printf "${GREEN}✅ Validator Key: Present${NC}\n"
    else
        printf "${RED}❌ Validator Key: Missing${NC}\n"
    fi
    
    printf "\n${YELLOW}📋 Management Commands:${NC}\n"
    printf "${BLUE}  - Stop validator: ./stop-validator.sh${NC}\n"
    printf "${BLUE}  - Restart: ./stop-validator.sh && ./start-validator.sh${NC}\n"
    printf "${BLUE}  - Health check: ./scripts/health-check.sh${NC}\n"
    printf "${BLUE}  - View logs: tail -f validator.log (if using nohup)${NC}\n"
    
    printf "\n${YELLOW}🌐 Network Endpoints:${NC}\n"
    printf "${BLUE}  - JSON-RPC: http://localhost:8545${NC}\n"
    printf "${BLUE}  - WebSocket: ws://localhost:8546${NC}\n"
    printf "${BLUE}  - Tendermint RPC: http://localhost:26657${NC}\n"
    printf "${BLUE}  - gRPC: http://localhost:9090${NC}\n"
    printf "${BLUE}  - Explorer: https://yoscan.net${NC}\n"
    printf "${BLUE}  - Public RPC: https://rpc.yoscan.net${NC}\n"
    
else
    printf "${RED}❌ Validator Status: STOPPED${NC}\n"
    printf "\n${BLUE}📋 Available Actions:${NC}\n"
    printf "${BLUE}  - Start validator: ./start-validator.sh${NC}\n"
    printf "${BLUE}  - Start in background: nohup ./start-validator.sh > validator.log 2>&1 &${NC}\n"
    
    if [ -f "config/node_key.json" ] && [ -f "config/priv_validator_key.json" ]; then
        printf "${GREEN}✅ Validator keys are ready${NC}\n"
    else
        printf "${YELLOW}⚠️ Validator keys not found${NC}\n"
        printf "${BLUE}  - Run setup: ./setup-validator.sh${NC}\n"
    fi
    
    # Check if evmosd is installed
    if ! command -v evmosd &> /dev/null && [ ! -f "/usr/local/bin/evmosd" ]; then
        printf "${RED}❌ evmosd binary not found${NC}\n"
        printf "${BLUE}Please run './setup-validator.sh' first${NC}\n"
    fi
fi

printf "\n"
