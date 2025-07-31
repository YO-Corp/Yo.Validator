#!/bin/bash

# YO Network Validator Stop Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${YELLOW}🛑 Stopping YO Network Validator...${NC}\n"

# Check if validator is running
if ! pgrep -f "evmosd start" > /dev/null; then
    printf "${YELLOW}⚠️ No YO validator process found${NC}\n"
    exit 0
fi

# Show current processes
printf "${BLUE}Current validator processes:${NC}\n"
pgrep -f "evmosd start" | while read pid; do
    ps -p $pid -o pid,ppid,cmd --no-headers
done
printf "\n"

# Stop the validator gracefully
printf "${YELLOW}Stopping validator processes...${NC}\n"
pkill -TERM -f "evmosd start" 2>/dev/null || true

# Wait a moment for graceful shutdown
sleep 3

# Force kill if still running
if pgrep -f "evmosd start" > /dev/null; then
    printf "${YELLOW}Force stopping remaining processes...${NC}\n"
    pkill -KILL -f "evmosd start" 2>/dev/null || true
    sleep 1
fi

# Verify it's stopped
if ! pgrep -f "evmosd start" > /dev/null; then
    printf "${GREEN}✅ YO validator stopped successfully!${NC}\n"
    printf "\n"
    printf "${BLUE}📋 Next Steps:${NC}\n"
    printf "${BLUE}  - Start again: ./start-validator.sh${NC}\n"
    printf "${BLUE}  - Start in background: nohup ./start-validator.sh > validator.log 2>&1 &${NC}\n"
    printf "${BLUE}  - Check status: ./check-status.sh${NC}\n"
    printf "${BLUE}  - View data: ls -la data/${NC}\n"
else
    printf "${RED}❌ Some validator processes may still be running!${NC}\n"
    printf "${BLUE}Check with: pgrep -f 'evmosd start'${NC}\n"
    exit 1
fi
