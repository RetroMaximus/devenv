#!/bin/bash

# Script to find commands that need sudo and add it where missing

# Files to check
SCRIPTS_DIR="~/devenv/development/scripts"
FILES="$SCRIPTS_DIR/*.sh"

# Commands that typically need sudo
SUDO_COMMANDS=(
    "apt"
    "apt-get"
    "chown"
    "chmod"
    "systemctl"
    "service"
    "ufw"
    "mysql"
    "mysqldump"
    "tar.*-C.*/usr/"
    "tar.*-C.*/etc/"
    "mv.*/var/"
    "mv.*/etc/"
    "cp.*/var/"
    "cp.*/etc/"
    "mkdir.*/var/"
    "mkdir.*/etc/"
    "rm.*/var/"
    "rm.*/etc/"
    "nano.*/etc/"
    "cat.*>.*/etc/"
    "echo.*>.*/etc/"
    "tee.*/etc/"
    "curl.*|.*bash"  # Piped curl commands often need sudo
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Checking for commands that need sudo...${NC}"

for file in $FILES; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    echo -e "\n${YELLOW}Checking: $file${NC}"
    changes_made=0
    
    # Create a backup
    cp "$file" "$file.bak"
    
    for pattern in "${SUDO_COMMANDS[@]}"; do
        # Find lines that match the pattern but don't have sudo
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                line_num=$(echo "$line" | cut -d: -f1)
                line_content=$(echo "$line" | cut -d: -f2-)
                
                # Skip if it's a comment, echo statement, or already has sudo
                if [[ "$line_content" =~ ^[[:space:]]*# ]] || \
                   [[ "$line_content" =~ echo.*sudo ]] || \
                   [[ "$line_content" =~ [[:space:]]sudo[[:space:]] ]] || \
                   [[ "$line_content" =~ sudo$ ]]; then
                    continue
                fi
                
                # Add sudo to the beginning of the command
                sed -i "${line_num}s/^[[:space:]]*/&sudo /" "$file"
                echo -e "  ${RED}FIXED:${NC} Line $line_num: $line_content"
                changes_made=1
            fi
        done < <(grep -n "$pattern" "$file" | grep -v "sudo")
    done
    
    if [ $changes_made -eq 0 ]; then
        echo -e "  ${GREEN}No changes needed${NC}"
        rm "$file.bak"  # Remove backup if no changes
    else
        echo -e "  ${GREEN}Changes made to $file (backup saved as $file.bak)${NC}"
    fi
done

echo -e "\n${GREEN}Done checking files!${NC}"
