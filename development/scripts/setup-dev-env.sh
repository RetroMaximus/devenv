#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$HOME/.dev-env-config"

# Load or create config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Default values
        DEV_DIR="$HOME/devenv/development"
        EDITOR="neovim"
        GIT_USER=""
        GIT_EMAIL=""
        ARCHIVE_TYPE="none"
        ARCHIVE_PATH=""
        CLOUD_TYPE=""
        # Create default config
        echo "DEV_DIR=\"$DEV_DIR\"" > "$CONFIG_FILE"
        echo "EDITOR=\"$EDITOR\"" > "$CONFIG_FILE"

        echo "GIT_USER=\"$GIT_USER\"" > "$CONFIG_FILE"
        echo "GIT_EMAIL=\"$GIT_EMAIL\"" > "$CONFIG_FILE"
        echo "ARCHIVE_TYPE=\"$ARCHIVE_TYPE\"" > "$CONFIG_FILE"
        echo "ARCHIVE_PATH=\"$ARCHIVE_PATH\"" > "$CONFIG_FILE"
        echo "CLOUD_TYPE=\"$CLOUD_TYPE\"" > "$CONFIG_FILE"
    fi
}

# Save config
save_config() {
    echo "DEV_DIR=\"$DEV_DIR\"" > "$CONFIG_FILE"
    echo "EDITOR=\"$EDITOR\"" > "$CONFIG_FILE"
    echo "GIT_USER=\"$GIT_USER\"" > "$CONFIG_FILE"
    echo "GIT_EMAIL=\"$GIT_EMAIL\"" > "$CONFIG_FILE"
    echo "ARCHIVE_TYPE=\"$ARCHIVE_TYPE\"" > "$CONFIG_FILE"
    echo "ARCHIVE_PATH=\"$ARCHIVE_PATH\"" > "$CONFIG_FILE"
    echo "CLOUD_TYPE=\"$CLOUD_TYPE\"" > "$CONFIG_FILE"
}

# Install required packages
install_packages() {
    echo -e "${BLUE}Installing required packages...${NC}"
    sudo apt update
    sudo apt install -y git curl wget neovim nano emacs tmux fzf ripgrep bat build-essential
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
    mkdir -p "$DEV_DIR/projects"/{active,archived,languages}
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

# Install programming languages
install_languages() {
    echo -e "${BLUE}Launching Language Manager...${NC}"
    ./language-manager.sh
}

# Clone GitHub repository
clone_repo() {
    read -p "Enter GitHub repository URL: " repo_url
    read -p "Enter project name (or press enter for repo name): " project_name
    
    if [ -z "$project_name" ]; then
        project_name=$(basename "$repo_url" .git)
    fi
    
    target_dir="$DEV_DIR/projects/active/$project_name"
    
    if [ -d "$target_dir" ]; then
        echo -e "${RED}Project '$project_name' already exists!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Cloning repository to $target_dir...${NC}"
    git clone "$repo_url" "$target_dir"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Repository cloned successfully!${NC}"
        cd "$target_dir" || return
    else
        echo -e "${RED}Failed to clone repository!${NC}"
    fi
}

# List all projects
list_projects() {
    echo -e "${YELLOW}Active Projects:${NC}"
    if [ -d "$DEV_DIR/projects/active" ]; then
        ls -la "$DEV_DIR/projects/active"
    else
        echo "No active projects found."
    fi
    
    echo -e "\n${YELLOW}Archived Projects:${NC}"
    if [ -d "$DEV_DIR/projects/archived" ]; then
        ls -la "$DEV_DIR/projects/archived"
    else
        echo "No archived projects found."
    fi
}

# Open project
open_project() {
    list_projects
    read -p "Enter project name to open: " project_name
    
    project_dir="$DEV_DIR/projects/active/$project_name"
    
    if [ -d "$project_dir" ]; then
        cd "$project_dir" || return
        echo -e "${GREEN}Changed to project directory: $project_dir${NC}"
        
        # Open in selected editor
        case $EDITOR in
            "neovim") nvim . ;;
            "emacs") emacs . ;;
            "nano") nano . ;;
        esac
    else
        echo -e "${RED}Project '$project_name' not found!${NC}"
    fi
}




# Configure project archiving
configure_archive() {
    echo -e "${BLUE}Launching Configuration Manager...${NC}"
    
    # Check if config-manager.sh exists and has the function
    if [ -f "./config-manager.sh" ]; then
        source ./config-manager.sh
        if type show_menu &>/dev/null; then
            show_menu
        else
            echo -e "${RED}Configuration not available in config-manager.sh${NC}"
        fi
    else
        echo -e "${RED}config-manager.sh not found!${NC}"
        echo -e "${YELLOW}Please make sure config-manager.sh is in the same directory.${NC}"
    fi
}


# Show current configuration
show_config() {
    source ./config-manager.sh
    echo -e "${YELLOW}Current Development Environment Configuration:${NC}"
    echo "Development Directory: $DEV_DIR"
    echo "Preferred Editor: $EDITOR"
    echo "Git User: $GIT_USER"
    echo "Git Email: $GIT_EMAIL"
    echo "Archive Type: $ARCHIVE_TYPE"
    echo "Archive Path: $ARCHIVE_PATH"
    echo "Cloud Type: $CLOUD_TYPE"
    echo -e "\n${YELLOW}Directory Structure:${NC}"
    tree -d "$DEV_DIR" 2>/dev/null || ls -la "$DEV_DIR"
}


# Main menu
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Raspberry Pi Development Environment ===${NC}"
        echo -e "1. Update RaspberryPi packages"
        echo -e "2. Setup Git configuration"
        echo -e "3. Create directory structure"
        echo -e "4. Setup editor ($EDITOR)"
        echo -e "5. Install programming languages"
        echo -e "6. Clone GitHub repository"
        echo -e "7. List projects"
        echo -e "8. Open project"
        echo -e "9. Configuration Manager"
        echo -e "10. Exit"
        echo -e "${YELLOW}=============================================${NC}"
        
        read -p "Choose an option (1-10): " choice
        
        case $choice in
            1) install_packages ;;
            2) setup_git ;;
            3) create_dev_structure ;;
            4) setup_editor ;;
            5) install_languages ;;
            6) clone_repo ;;
            7) list_projects ;;
            8) open_project ;;
            9) configure_archive ;;  # This was missing
            10) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac    
    done
}

# Main execution
load_config
show_menu
