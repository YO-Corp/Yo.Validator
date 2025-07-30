#!/bin/bash

# YO Network Validator Health Check

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

printf "${YELLOW}🏥 YO Validator Comprehensive Health Check${NC}\n"
printf "══════════════════════════════════════════════════════════\n"

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Function to run a check
run_check() {
    local check_name="$1"
    local check_command="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-40s " "$check_name..."
    
    if eval "$check_command" > /dev/null 2>&1; then
        printf "${GREEN}✅ PASS${NC}\n"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        printf "${RED}❌ FAIL${NC}\n"
        return 1
    fi
}

# Docker checks
printf "\n${BLUE}🐳 Docker Environment${NC}\n"
printf "─────────────────────────────────────────────────────\n"
run_check "Docker daemon running" "docker info"
run_check "YO validator container running" "docker ps | grep -q yo-validator"

# Network connectivity checks
printf "\n${BLUE}🌐 Network Connectivity${NC}\n"
printf "─────────────────────────────────────────────────────\n"
run_check "JSON-RPC endpoint responding" "curl -s -f http://localhost:8545"
run_check "WebSocket endpoint responding" "curl -s -f http://localhost:8546"
run_check "Metrics endpoint responding" "curl -s -f http://localhost:9545"

# Blockchain checks
printf "\n${BLUE}⛓️ Blockchain Status${NC}\n"
printf "─────────────────────────────────────────────────────\n"

# Check if we can get block number
if BLOCK_NUMBER=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null); then
    if [ "$BLOCK_NUMBER" != "null" ] && [ "$BLOCK_NUMBER" != "N/A" ]; then
        BLOCK_DECIMAL=$((16#${BLOCK_NUMBER#0x}))
        printf "%-40s ${GREEN}✅ Block #$BLOCK_DECIMAL${NC}\n" "Current block height"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        printf "%-40s ${RED}❌ FAIL${NC}\n" "Current block height"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    printf "%-40s ${RED}❌ FAIL${NC}\n" "Current block height"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

# Check peer connections
if PEER_COUNT=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null); then
    if [ "$PEER_COUNT" != "null" ] && [ "$PEER_COUNT" != "N/A" ]; then
        PEER_DECIMAL=$((16#${PEER_COUNT#0x}))
        if [ "$PEER_DECIMAL" -gt 0 ]; then
            printf "%-40s ${GREEN}✅ $PEER_DECIMAL peers${NC}\n" "Peer connections"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            printf "%-40s ${YELLOW}⚠️ No peers${NC}\n" "Peer connections"
        fi
    else
        printf "%-40s ${RED}❌ FAIL${NC}\n" "Peer connections"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    printf "%-40s ${RED}❌ FAIL${NC}\n" "Peer connections"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

# Check sync status
if SYNCING=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  -H "Content-Type: application/json" http://localhost:8545 | jq -r '.result' 2>/dev/null); then
    if [ "$SYNCING" = "false" ]; then
        printf "%-40s ${GREEN}✅ SYNCED${NC}\n" "Synchronization status"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ "$SYNCING" != "null" ] && [ "$SYNCING" != "N/A" ]; then
        printf "%-40s ${YELLOW}⚠️ SYNCING${NC}\n" "Synchronization status"
    else
        printf "%-40s ${RED}❌ FAIL${NC}\n" "Synchronization status"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    printf "%-40s ${RED}❌ FAIL${NC}\n" "Synchronization status"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

# File system checks
printf "\n${BLUE}💾 File System${NC}\n"
printf "─────────────────────────────────────────────────────\n"
run_check "Validator key exists" "[ -f validator/key ]"
run_check "Validator key permissions secure" "[ \"\$(stat -c %a validator/key 2>/dev/null)\" = \"600\" ]"
run_check "Data directory exists" "[ -d data ]"
run_check "Config directory exists" "[ -d config ]"

# Resource checks
printf "\n${BLUE}📊 Resource Usage${NC}\n"
printf "─────────────────────────────────────────────────────\n"

# Check disk space
if [ -d data ]; then
    DATA_SIZE=$(du -sh data 2>/dev/null | cut -f1 || echo "0B")
    printf "%-40s ${BLUE}📁 $DATA_SIZE${NC}\n" "Data directory size"
fi

# Get available disk space
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
printf "%-40s ${BLUE}💽 $AVAILABLE_SPACE${NC}\n" "Available disk space"

# Container resource usage (if running)
if docker ps | grep -q yo-validator; then
    printf "\n${BLUE}🔧 Container Resources${NC}\n"
    printf "─────────────────────────────────────────────────────\n"
    docker stats yo-validator --no-stream --format "CPU: {{.CPUPerc}} | Memory: {{.MemUsage}} | Network: {{.NetIO}}"
fi

# Summary
printf "\n${YELLOW}📋 Health Check Summary${NC}\n"
printf "══════════════════════════════════════════════════════════\n"

HEALTH_PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [ "$HEALTH_PERCENTAGE" -ge 90 ]; then
    printf "${GREEN}🎉 EXCELLENT HEALTH: $PASSED_CHECKS/$TOTAL_CHECKS checks passed ($HEALTH_PERCENTAGE%%)${NC}\n"
elif [ "$HEALTH_PERCENTAGE" -ge 75 ]; then
    printf "${YELLOW}⚠️ GOOD HEALTH: $PASSED_CHECKS/$TOTAL_CHECKS checks passed ($HEALTH_PERCENTAGE%%)${NC}\n"
elif [ "$HEALTH_PERCENTAGE" -ge 50 ]; then
    printf "${YELLOW}⚠️ MODERATE HEALTH: $PASSED_CHECKS/$TOTAL_CHECKS checks passed ($HEALTH_PERCENTAGE%%)${NC}\n"
else
    printf "${RED}🚨 POOR HEALTH: $PASSED_CHECKS/$TOTAL_CHECKS checks passed ($HEALTH_PERCENTAGE%%)${NC}\n"
fi

printf "\n${BLUE}🔧 Quick Actions:${NC}\n"
printf "  - View logs: docker logs yo-validator -f\n"
printf "  - Restart: docker compose restart\n"
printf "  - Full status: ./check-status.sh\n"
printf "  - Network explorer: https://yo-bs.bcflex.com\n"

printf "\n"
