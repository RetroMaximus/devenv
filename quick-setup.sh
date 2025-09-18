#!/bin/bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# Quick setup for new Raspberry Pi
echo -e "${YELLOW}=== Quick Development Environment Setup ===${NC}"

sudo bash ~/devenv/development/scripts/fix-line-endings.sh ~/

sudo bash ~/devenv/development/scripts/fix-line-endings.sh ~/devenv/development/scripts/

sudo bash ~/devenv/development/scripts/sudofix.sh

# Update system
#echo -e "${BLUE}Updating system packages...${NC}"
#sudo apt update && sudo apt upgrade -y

# Make all scripts executable
echo -e "${BLUE}Making scripts executable...${NC}"
sudo chmod +x *.sh
sudo chmod +x ~/devenv/development/scripts/*.sh

# Run main setup
echo -e "${BLUE}Running main setup...${NC}"
sudo bash ~/devenv/development/scripts/setup-dev-env.sh

# Move scripts to development directory
echo -e "${BLUE}Organizing scripts...${NC}"
sudo mkdir -p ~/devenv/development/scripts
sudo mv *.sh ~/devenv/development/scripts/

# Add aliases to bashrc only if they don't exist
echo -e "${BLUE}Setting up aliases...${NC}"

# Function to add alias if it doesn't exist
add_alias_if_not_exists() {
    local alias_name=$1
    local alias_command=$2
    local alias_desc=$3
    
    if ! grep -q "alias $alias_name=" ~/.bashrc; then
        echo "alias $alias_name='$alias_command'" >> ~/.bashrc
        echo -e "${GREEN}$alias_name${NC} - $alias_desc"
    else
        echo -e "${GREEN}$alias_name${NC} - $alias_desc"
    fi
}

echo -e "${GREEN}Setup complete! Scripts are in ~/devenv/development/scripts/${NC}"

# Add the aliases
echo -e "${YELLOW}Available commands:${NC}"

add_alias_if_not_exists "dev" "~/devenv/development/scripts/setup-dev-env.sh" "Main development environment menu"
add_alias_if_not_exists "projects" "~/devenv/development/scripts/project-manager.sh" "Manage projects and repositories"
add_alias_if_not_exists "config-dev" "~/devenv/development/scripts/config-manager.sh" "Configure environment settings"
add_alias_if_not_exists "lang-setup" "~/devenv/development/scripts/language-manager.sh" "Install and manage programming languages"
add_alias_if_not_exists "set-streamer-mask" "~/devenv/development/scripts/assign-streamer-mask.sh" "Set the streamer mode mask. This can be anything you wish."
add_alias_if_not_exists "set-streamer-mode" "~/devenv/development/scripts/assign-streamer-mode.sh" "Set to True/true or False/false. Note assing a mask first."
add_alias_if_not_exists "show-streamer-status" "~/devenv/development/scripts/show-streamer-mode-status.sh" "Show Streamer mode and mask settings."

source ~/.bashrc

echo -e ""