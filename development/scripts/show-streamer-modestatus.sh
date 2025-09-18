#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current settings
CURRENT_MODE=$(grep "^STREAMER_MODE=" ~/.bashrc 2>/dev/null | cut -d= -f2 || echo "false")
CURRENT_MASK=$(grep "^STREAMER_MASK=" ~/.bashrc 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "user")

echo -e "${YELLOW}=== Streamer Mode Status ===${NC}"
echo -e "Streamer mode: ${GREEN}$CURRENT_MODE${NC}"
echo -e "Mask: ${GREEN}$CURRENT_MASK${NC}"

if [ "$CURRENT_MODE" = "true" ]; then
    echo -e "Status: ${GREEN}Enabled${NC}"
    echo -e "Prompt will show: ${GREEN}$CURRENT_MASK${NC} instead of user@host"
else
    echo -e "Status: ${YELLOW}Disabled${NC}"
    echo -e "Prompt will show: normal user@host information"
fi

echo -e "${YELLOW}============================${NC}"