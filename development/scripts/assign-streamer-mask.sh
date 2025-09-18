#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Usage: set-streamer-mask [mask_text]${NC}"
    echo "Current mask: $(grep "^STREAMER_MASK=" ~/.bashrc | cut -d= -f2 | tr -d '"')"
    exit 1
fi

NEW_MASK="$1"

# Update the .bashrc file with the new mask
if grep -q "^STREAMER_MASK=" ~/.bashrc; then
    sed -i "s/^STREAMER_MASK=.*/STREAMER_MASK=\"$NEW_MASK\"/" ~/.bashrc
    echo -e "${GREEN}Streamer mask set to: $NEW_MASK${NC}"
else
    # If the line doesn't exist, add it
    echo "STREAMER_MASK=\"$NEW_MASK\"" >> ~/.bashrc
    echo -e "${GREEN}Streamer mask created and set to: $NEW_MASK${NC}"
fi

# Reload bashrc to apply changes
source ~/.bashrc