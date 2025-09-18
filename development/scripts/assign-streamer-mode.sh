#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Usage: set-streamer-mode [true|false]${NC}"
    CURRENT_MODE=$(grep "^STREAMER_MODE=" ~/.bashrc | cut -d= -f2)
    CURRENT_MASK=$(grep "^STREAMER_MASK=" ~/.bashrc | cut -d= -f2 | tr -d '"')
    echo -e "Current streamer mode: ${YELLOW}$CURRENT_MODE${NC}"
    echo -e "Current mask: ${YELLOW}$CURRENT_MASK${NC}"
    exit 1
fi

MODE="$1"

if [ "$MODE" = "true" ] || [ "$MODE" = "True" ] || [ "$MODE" = "1" ]; then
    NEW_MODE=true
    echo -e "${GREEN}Streamer mode enabled. Prompt will be masked.${NC}"
elif [ "$MODE" = "false" ] || [ "$MODE" = "False" ] || [ "$MODE" = "0" ]; then
    NEW_MODE=false
    echo -e "${GREEN}Streamer mode disabled. Normal prompt restored.${NC}"
else
    echo -e "${RED}Invalid option! Usage: set-streamer-mode [true|false]${NC}"
    exit 1
fi

# Update the .bashrc file with the new setting
if grep -q "^STREAMER_MODE=" ~/.bashrc; then
    sed -i "s/^STREAMER_MODE=.*/STREAMER_MODE=$NEW_MODE/" ~/.bashrc
else
    # If the line doesn't exist, add it
    echo "STREAMER_MODE=$NEW_MODE" >> ~/.bashrc
fi

# Reload bashrc to apply changes
source ~/.bashrc
