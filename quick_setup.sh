#!/bin/bash

# Quick setup for new Raspberry Pi
echo -e "${YELLOW}=== Quick Development Environment Setup ===${NC}"

# Update system
#sudo apt update && sudo apt upgrade -y

# Run main setup
chmod +x setup-dev-env.sh
./setup-dev-env.sh

# Make scripts executable
chmod +x *.sh

# Move scripts to development directory
mkdir -p ~/development/scripts
mv *.sh ~/development/scripts/

echo -e "${GREEN}Setup complete! Scripts are in ~/development/scripts/${NC}"
echo -e "Add this to your ~/.bashrc:"
echo -e "alias dev='~/development/scripts/setup_dev_env.sh'"
echo -e "alias projects='~/development/scripts/project_manager.sh'"
echo -e "alias config-dev='~/development/scripts/config_manager.sh'"
