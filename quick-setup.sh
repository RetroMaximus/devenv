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

# Run main setup
echo -e "${BLUE}Running main setup...${NC}"
sudo chmod +x ~/devenv/development/scripts/setup-dev-env.sh
sudo bash ~/devenv/development/scripts/setup-dev-env.sh

# Make all scripts executable
echo -e "${BLUE}Making scripts executable...${NC}"
sudo chmod +x *.sh

# Move scripts to development directory
echo -e "${BLUE}Organizing scripts...${NC}"
sudo mkdir -p ~/devenv/development/scripts
#sudo mv *.sh ~/devenv/development/scripts/

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

add_alias_if_not_exists "dev" "Main development environment menu" "~/devenv/development/scripts/setup-dev-env.sh"
add_alias_if_not_exists "projects" "Manage projects and repositories" "~/devenv/development/scripts/project-manager.sh"
add_alias_if_not_exists "config-dev" "Configure environment settings" "~/devenv/development/scripts/config-manager.sh"
add_alias_if_not_exists "lang-setup" "Install and manage programming languages" "~/devenv/development/scripts/language-manager.sh"

source ~/.bashrc

echo -e ""