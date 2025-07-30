#!/bin/bash

# YO Network Validator Update Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${YELLOW}🔄 YO Network Validator Update${NC}\n"
printf "════════════════════════════════════════\n"

# Check if validator is running
if docker ps | grep -q "yo-validator"; then
    printf "${YELLOW}Validator is currently running. Stopping for update...${NC}\n"
    docker compose down
    RESTART_AFTER_UPDATE=true
else
    RESTART_AFTER_UPDATE=false
fi

# Pull latest images
printf "${BLUE}📥 Pulling latest Docker images...${NC}\n"
docker compose pull

# Update the repository (if this is a git repo)
if [ -d ".git" ]; then
    printf "${BLUE}📝 Updating repository...${NC}\n"
    git pull origin main || printf "${YELLOW}⚠️ Could not update repository (not a problem if running from release)${NC}\n"
fi

# Backup current configuration
printf "${BLUE}💾 Creating backup...${NC}\n"
BACKUP_DIR="backup/update-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r config "$BACKUP_DIR/"
cp -r validator "$BACKUP_DIR/"
printf "${GREEN}✅ Backup created at: $BACKUP_DIR${NC}\n"

# Restart if it was running before
if [ "$RESTART_AFTER_UPDATE" = true ]; then
    printf "${BLUE}🚀 Restarting validator...${NC}\n"
    docker compose up -d
    
    # Wait for startup
    sleep 5
    
    # Check if it's running
    if docker ps | grep -q "yo-validator"; then
        printf "${GREEN}✅ Validator updated and restarted successfully!${NC}\n"
    else
        printf "${RED}❌ Validator failed to restart. Check logs: docker logs yo-validator${NC}\n"
        exit 1
    fi
else
    printf "${GREEN}✅ Update completed! Use './start-validator.sh' to start.${NC}\n"
fi

printf "\n${BLUE}📋 Update Summary:${NC}\n"
printf "  - Docker images: Updated\n"
printf "  - Configuration: Backed up to $BACKUP_DIR\n"
printf "  - Status: $(docker ps | grep -q yo-validator && echo "Running" || echo "Stopped")\n"
printf "\n"
