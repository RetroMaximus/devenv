#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$HOME/.dev-env-config"

# Load or create configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Set default values
        DEV_DIR="$HOME/devenv/development"
        EDITOR="neovim"
        GIT_USER=""
        GIT_EMAIL=""
        ARCHIVE_TYPE="none"
        ARCHIVE_PATH=""
        CLOUD_TYPE=""
        
        # Create the config file with defaults
        save_config
    fi
}

# Save config function
save_config() {
    echo "DEV_DIR=\"$DEV_DIR\"" > "$CONFIG_FILE"
    echo "EDITOR=\"$EDITOR\"" > "$CONFIG_FILE"
    echo "GIT_USER=\"$GIT_USER\"" > "$CONFIG_FILE"
    echo "GIT_EMAIL=\"$GIT_EMAIL\"" > "$CONFIG_FILE"
    echo "ARCHIVE_TYPE=\"$ARCHIVE_TYPE\"" > "$CONFIG_FILE"
    echo "ARCHIVE_PATH=\"$ARCHIVE_PATH\"" > "$CONFIG_FILE"
    echo "CLOUD_TYPE=\"$CLOUD_TYPE\"" > "$CONFIG_FILE"
}

# Load configuration first
load_config

# Show current configuration
show_config() {
    echo -e "${YELLOW}Current Development Environment Configuration:${NC}"
    echo "Development Directory: $DEV_DIR"
    echo "Preferred Editor: $EDITOR"
    echo "Git User: $GIT_USER"
    echo "Git Email: $GIT_EMAIL"
    echo "Archive Type: $ARCHIVE_TYPE"
    echo "Archive Path: $ARCHIVE_PATH"
    echo "Cloud Type: $CLOUD_TYPE"
    echo -e "\n${YELLOW}Directory Structure:${NC}"
    if [ -d "$DEV_DIR" ]; then
        tree -d "$DEV_DIR" 2>/dev/null || ls -la "$DEV_DIR"
    else
        echo "Directory does not exist. Run 'Create directory structure' from main menu."
    fi
}

# Change editor preference
change_editor() {
    echo -e "${YELLOW}Select your preferred editor:${NC}"
    echo "1. Neovim"
    echo "2. Emacs"
    echo "3. Nano"
    
    read -p "Choose (1-3): " editor_choice
    
    case $editor_choice in
        1) EDITOR="neovim" ;;
        2) EDITOR="emacs" ;;
        3) EDITOR="nano" ;;
        *) echo -e "${RED}Invalid choice!${NC}"; return ;;
    esac
    
    save_config
    echo -e "${GREEN}Editor preference changed to $EDITOR${NC}"
}

# Change development directory
change_dev_dir() {
    read -p "Enter new development directory path: " new_dir
    if [ -d "$new_dir" ]; then
        DEV_DIR="$new_dir"
        save_config
        echo -e "${GREEN}Development directory changed to $DEV_DIR${NC}"
    else
        echo -e "${RED}Directory does not exist!${NC}"
        read -p "Create it? (y/n): " create_choice
        if [ "$create_choice" = "y" ]; then
            mkdir -p "$new_dir"
            DEV_DIR="$new_dir"
            save_config
            echo -e "${GREEN}Development directory created and set to $DEV_DIR${NC}"
        fi
    fi
}

# Edit configuration manually
edit_config() {
    case $EDITOR in
        "neovim") nvim ~/.dev-env-config ;;
        "emacs") emacs ~/.dev-env-config ;;
        "nano") nano ~/.dev-env-config ;;
    esac
    # Reload config after editing
    source ~/.dev-env-config
}

# Add archive configuration menu option
configure_archive() {
    echo -e "${YELLOW}Configure Project Archiving${NC}"
    echo "1. Git repository archiving"
    echo "2. Cloud storage (Dropbox, Google Drive, etc.)"
    echo "3. Local network path"
    echo "4. Disable archiving"
    
    read -p "Choose archiving method (1-4): " choice
    
    case $choice in
        1)
            ARCHIVE_TYPE="git"
            read -p "Enter Git repository URL for archives: " ARCHIVE_PATH
            ;;
        2)
            ARCHIVE_TYPE="cloud"
            echo "Cloud options: dropbox, googledrive, onedrive"
            read -p "Enter cloud type: " CLOUD_TYPE
            read -p "Enter cloud path (e.g., ~/Dropbox/archive): " ARCHIVE_PATH
            ;;
        3)
            ARCHIVE_TYPE="local"
            read -p "Enter network path (e.g., //192.168.1.100/archive): " ARCHIVE_PATH
            ;;
        4)
            ARCHIVE_TYPE="none"
            ARCHIVE_PATH=""
            CLOUD_TYPE=""
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            return
            ;;
    esac
    
    save_config
    echo -e "${GREEN}Archive configuration updated!${NC}"
}
