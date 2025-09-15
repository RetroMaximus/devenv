#!/bin/bash

# Load configuration
source ~/.dev_env_config

# Show current configuration
show_config() {
    echo -e "${YELLOW}Current Development Environment Configuration:${NC}"
    echo "Development Directory: $DEV_DIR"
    echo "Preferred Editor: $EDITOR"
    echo "Git User: $GIT_USER"
    echo "Git Email: $GIT_EMAIL"
    echo -e "\n${YELLOW}Directory Structure:${NC}"
    tree -d "$DEV_DIR" 2>/dev/null || ls -la "$DEV_DIR"
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
    setup_editor
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
            create_dev_structure
            echo -e "${GREEN}Development directory created and set to $DEV_DIR${NC}"
        fi
    fi
}

# Edit configuration manually
edit_config() {
    case $EDITOR in
        "neovim") nvim ~/.dev_env_config ;;
        "emacs") emacs ~/.dev_env_config ;;
        "nano") nano ~/.dev_env_config ;;
    esac
    # Reload config after editing
    source ~/.dev_env_config
}
