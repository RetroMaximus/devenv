#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$HOME/.dev_env_config"

# Load or create config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Default values
        DEV_DIR="$HOME/development"
        EDITOR="neovim"
        GIT_USER=""
        GIT_EMAIL=""
        # Create default config
        echo "DEV_DIR=\"$DEV_DIR\"" > "$CONFIG_FILE"
        echo "EDITOR=\"$EDITOR\"" >> "$CONFIG_FILE"
        echo "GIT_USER=\"$GIT_USER\"" >> "$CONFIG_FILE"
        echo "GIT_EMAIL=\"$GIT_EMAIL\"" >> "$CONFIG_FILE"
    fi
}

# Save config
save_config() {
    echo "DEV_DIR=\"$DEV_DIR\"" > "$CONFIG_FILE"
    echo "EDITOR=\"$EDITOR\"" >> "$CONFIG_FILE"
    echo "GIT_USER=\"$GIT_USER\"" >> "$CONFIG_FILE"
    echo "GIT_EMAIL=\"$GIT_EMAIL\"" >> "$CONFIG_FILE"
}

# Install required packages
install_packages() {
    echo -e "${BLUE}Installing required packages...${NC}"
    sudo apt update
    sudo apt install -y git curl wget neovim nano emacs tmux fzf ripgrep bat
    echo -e "${GREEN}Packages installed successfully!${NC}"
}

# Setup git configuration
setup_git() {
    echo -e "${BLUE}Setting up Git configuration...${NC}"
    if [ -z "$GIT_USER" ]; then
        read -p "Enter your Git username: " GIT_USER
        echo "GIT_USER=\"$GIT_USER\"" >> "$CONFIG_FILE"
    fi
    
    if [ -z "$GIT_EMAIL" ]; then
        read -p "Enter your Git email: " GIT_EMAIL
        echo "GIT_EMAIL=\"$GIT_EMAIL\"" >> "$CONFIG_FILE"
    fi
    
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global core.editor "$EDITOR"
    git config --global pull.rebase false
    echo -e "${GREEN}Git configuration set up!${NC}"
}

# Create development directory structure
create_dev_structure() {
    echo -e "${BLUE}Creating development directory structure...${NC}"
    mkdir -p "$DEV_DIR"/{projects,temp,backups,scripts,configs}
    mkdir -p "$DEV_DIR/projects"/{active,archived,templates}
    echo -e "${GREEN}Directory structure created in $DEV_DIR${NC}"
}

# Setup editor configuration
setup_editor() {
    echo -e "${BLUE}Setting up $EDITOR configuration...${NC}"
    
    case $EDITOR in
        "neovim")
            # Create basic neovim config
            mkdir -p ~/.config/nvim
            cat > ~/.config/nvim/init.vim << EOF
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set mouse=a
syntax on
EOF
            ;;
        "emacs")
            # Basic emacs config
            cat > ~/.emacs << EOF
(setq inhibit-startup-screen t)
(setq column-number-mode t)
(show-paren-mode 1)
(setq-default indent-tabs-mode nil)
EOF
            ;;
        "nano")
            # Nano doesn't need much setup
            echo "Nano selected - no additional configuration needed"
            ;;
    esac
    echo -e "${GREEN}$EDITOR configuration set up!${NC}"
}

# Main menu
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Raspberry Pi Development Environment ===${NC}"
        echo -e "1. Install packages"
        echo -e "2. Setup Git configuration"
        echo -e "3. Create directory structure"
        echo -e "4. Setup editor ($EDITOR)"
        echo -e "5. Change editor preference"
        echo -e "6. Clone GitHub repository"
        echo -e "7. List projects"
        echo -e "8. Open project"
        echo -e "9. Show configuration"
        echo -e "10. Exit"
        echo -e "${YELLOW}=============================================${NC}"
        
        read -p "Choose an option (1-10): " choice
        
        case $choice in
            1) install_packages ;;
            2) setup_git ;;
            3) create_dev_structure ;;
            4) setup_editor ;;
            5) change_editor ;;
            6) clone_repo ;;
            7) list_projects ;;
            8) open_project ;;
            9) show_config ;;
            10) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Additional functions would be defined here...

# Main execution
load_config
show_menu
