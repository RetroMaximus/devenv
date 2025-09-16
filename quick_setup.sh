#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quick setup for new Raspberry Pi
echo -e "${YELLOW}=== Quick Development Environment Setup ===${NC}"

sudo ~/devenv/development/scripts/fix_line_endings.sh ~/

echo -e ""
sudo ~/devenv/development/scripts/sudofix.sh

# Update system
echo -e "${BLUE}Updating system packages...${NC}"
#sudo apt update && sudo apt upgrade -y

# Run main setup
echo -e "${BLUE}Running main setup...${NC}"
sudo chmod +x ~/devenv/development/scripts/setup_dev_env.sh
sudo ~/devenv/development/setup_dev_env.sh

# Make all scripts executable
echo -e "${BLUE}Making scripts executable...${NC}"
sudo chmod +x *.sh

# Move scripts to development directory
echo -e "${BLUE}Organizing scripts...${NC}"
sudo mkdir -p ~/devenv/development/scripts
sudo mv *.sh ~/devenv/development/scripts/

# Add aliases to bashrc
echo -e "${BLUE}Setting up aliases...${NC}"
echo "alias dev='~/devenv/development/scripts/setup-dev-env.sh'" >> ~/.bashrc
echo "alias projects='~/devenv/development/scripts/project-manager.sh'" >> ~/.bashrc
echo "alias config-dev='~/devenv/development/scripts/config-manager.sh'" >> ~/.bashrc
echo "alias lang-setup='~/devenv/development/scripts/language-manager.sh'" >> ~/.bashrc

echo -e "${GREEN}Setup complete! Scripts are in ~/devenv/development/scripts/${NC}"
echo -e "${YELLOW}Available commands:${NC}"
echo -e "  dev        - Main development environment menu"
echo -e "  projects   - Manage projects and repositories"
echo -e "  config-dev - Configure environment settings"
echo -e "  lang-setup - Install and manage programming languages"
echo -e ""
echo -e "${YELLOW}Run 'source ~/.bashrc' to apply aliases, or restart your shell.${NC}"
