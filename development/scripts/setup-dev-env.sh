#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    USER_HOME=$HOME
fi

# Configuration file
CONFIG_FILE="$USER_HOME/.dev-env-config"
#source ${CONFIG_FILE}

# Load configuration
if [ -f ~/.dev-env-config ]; then
    source ~/.dev-env-config
    # Set default values if any variables are empty
    DEV_DIR="${DEV_DIR:-$USER_HOME/devenv/development}"
    EDITOR="${EDITOR:-neovim}"
    GIT_USER="${GIT_USER:-none}"
    GIT_PATH="${GIT_PATH:-none}"
    ARCHIVE_TYPE="${ARCHIVE_TYPE:-none}"
    ARCHIVE_PATH="${ARCHIVE_PATH:-none}"
    OPEN_PROJECT="${OPEN_PROJECT:-none}"

#else
#    echo -e "${RED}Configuration file not found! Please run './quick-setup.sh' first without quotes.${NC}"
#    exit 1
fi

# Load or create config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Default values
        DEV_DIR="$USER_HOME/devenv/development"
        EDITOR="neovim"
        GIT_USER="none"
        GIT_EMAIL="none"
        ARCHIVE_TYPE="none"
        ARCHIVE_PATH="none"
        CLOUD_TYPE="none"
        OPEN_PROJECT="none"
        # Create the config file with defaults
        save_config
    fi
}

# Save configuration
save_config() {
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Read current config and update values
    if [ -f ~/.dev-env-config ]; then
        while IFS= read -r line; do
            case $line in
                DEV_DIR=*)
                    echo "DEV_DIR=\"$DEV_DIR\"" >> "$temp_file"
                    ;;
                EDITOR=*)
                    echo "EDITOR=\"$EDITOR\"" >> "$temp_file"
                    ;;
                GIT_USER=*)
                    echo "GIT_USER=\"$GIT_USER\"" >> "$temp_file"
                    ;;
                GIT_EMAIL=*)
                    echo "GIT_EMAIL=\"$GIT_EMAIL\"" >> "$temp_file"
                    ;;
                ARCHIVE_TYPE=*)
                    echo "ARCHIVE_TYPE=\"$ARCHIVE_TYPE\"" >> "$temp_file"
                    ;;
                ARCHIVE_PATH=*)
                    echo "ARCHIVE_PATH=\"$ARCHIVE_PATH\"" >> "$temp_file"
                    ;;
                CLOUD_TYPE=*)
                    echo "CLOUD_TYPE=\"$CLOUD_TYPE\"" >> "$temp_file"
                    ;;
                OPEN_PROJECT=*)
                    echo "OPEN_PROJECT=\"$OPEN_PROJECT\"" >> "$temp_file"
                    ;;
                *)
                    echo "$line" >> "$temp_file"
                    ;;
            esac
        done < ~/.dev-env-config
    else
        # Create new config with all values
        echo "DEV_DIR=\"$DEV_DIR\"" >> "$temp_file"
        echo "EDITOR=\"$EDITOR\"" >> "$temp_file"
        echo "GIT_USER=\"$GIT_USER\"" >> "$temp_file"
        echo "GIT_EMAIL=\"$GIT_EMAIL\"" >> "$temp_file"
        echo "ARCHIVE_TYPE=\"$ARCHIVE_TYPE\"" >> "$temp_file"
        echo "ARCHIVE_PATH=\"$ARCHIVE_PATH\"" >> "$temp_file"
        echo "CLOUD_TYPE=\"$CLOUD_TYPE\"" >> "$temp_file"
        echo "OPEN_PROJECT=\"$OPEN_PROJECT\"" >> "$temp_file"
    fi
    
    # Replace the original config file
    mv "$temp_file" ~/.dev-env-config
    echo -e "${GREEN}Configuration saved!${NC}"
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
    
    sudo git config --global user.name "$GIT_USER"
    sudo git config --global user.email "$GIT_EMAIL"
    sudo git config --global core.editor "$EDITOR"
    sudo git config --global pull.rebase false
    echo -e "${GREEN}Git configuration set up!${NC}"
}

# Create development directory structure
create_dev_structure() {
    echo -e "${BLUE}Creating development directory structure...${NC}"
    sudo mkdir -p "$DEV_DIR"/{projects,temp,backups,scripts,configs}
    sudo mkdir -p "$DEV_DIR/projects"/{active,archived,languages}
    echo -e "${GREEN}Directory structure created in $DEV_DIR${NC}"
}

# Setup editor configuration
setup_editor() {
    echo -e "${BLUE}Setting up $EDITOR configuration...${NC}"
    
    case $EDITOR in
        "neovim")
            # Create basic neovim config
            sudo mkdir -p ~/.config/nvim
            sudo cat > ~/.config/nvim/init.vim << EOF
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
    sudo bash $DEV_DIR/scripts/language-manager.sh
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
    sudo git clone "$repo_url" "$target_dir"
    
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
        OPEN_PROJECT="$project_name"
        save_config
        echo -e "${GREEN}Changed to project directory: $project_dir${NC}"
        echo -e "${GREEN}Current project: $OPEN_PROJECT${NC}"
        
        # Check if language config exists and show info
        lang_file="$DEV_DIR/projects/languages/${project_name}.lang"
        if [ -f "$lang_file" ]; then
            echo -e "${BLUE}Project languages:$(cat "$lang_file" | tr '\n' ' ')${NC}"
        fi
        
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
    echo -e "${BLUE}Launching Archive Configuration...${NC}"
    
    # Check if config-manager.sh exists and has the function
    #if [ -f "./config-manager.sh" ]; then
    #    source ./config-manager.sh
    if [ -f "$DEV_DIR/scripts/config-manager.sh" ]; then
        source "$DEV_DIR/scripts/config-manager.sh"
        if type configure_archive &>/dev/null; then
            configure_archive
        else
            echo -e "${RED}Archive configuration not available in config-manager.sh${NC}"
        fi
    else
        echo -e "${RED}config-manager.sh not found!${NC}"
        echo -e "${YELLOW}Please make sure config-manager.sh is in the same directory.${NC}"
    fi
}


# Show current configuration
show_config() {
    # source ./config-manager.sh
    echo -e "${YELLOW}Current Development Environment Configuration:${NC}"
    echo "Development Directory: $DEV_DIR"
    echo "Preferred Editor: $EDITOR"
    echo "Git User: $GIT_USER"
    echo "Git Email: $GIT_EMAIL"
    echo "Archive Type: $ARCHIVE_TYPE"
    echo "Archive Path: $ARCHIVE_PATH"
    echo "Cloud Type: $CLOUD_TYPE"
    echo "Opened Project: $OPEN_PROJECT"
    echo -e "\n${YELLOW}Directory Structure:${NC}"
    tree -d "$DEV_DIR" 2>/dev/null || ls -la "$DEV_DIR"
}

env_size() {
echo -e ""
echo -e "Environment"
df -h -x tmpfs
}

# Main menu

show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Dev Env ===============================${NC}"
        echo -e "1. Projects Manager"
        echo -e "2. Configuation"
        echo -e "3. Exit"
        echo -e "${YELLOW}=============================================${NC}"

        read -p "Choose an option (1-11): " choice
        
        case $choice in
            1) 
                # Launch the project manager script
                if [ -f "./project-manager.sh" ]; then
                    bash ./project-manager.sh
                elif [ -f "$DEV_DIR/scripts/project-manager.sh" ]; then
                    bash "$DEV_DIR/scripts/project-manager.sh"
                else
                    echo -e "${RED}Project manager script not found!${NC}"
                fi
                ;;
            2) show_config_menu ;;
            3) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac    
    done
}


show_config_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Dev Env - Config ======================${NC}"
        echo -e "1. Update RaspberryPi packages"
        echo -e "2. Setup Git configuration"
        echo -e "3. Create directory structure"
        echo -e "4. Setup editor ($EDITOR)"
        echo -e "5. Change editor preference"
        echo -e "6. Install programming languages"
        echo -e "7. Configure project archiving"
        echo -e "8. Show Filesystem Usage"        
        echo -e "9. Show Configuration"
        echo -e "10. Back to Main menu"
        echo -e "${YELLOW}=============================================${NC}"
        
        read -p "Choose an option (1-11): " choice
        
        case $choice in
            1) install_packages ;;
            2) setup_git ;;
            3) create_dev_structure ;;
            4) setup_editor ;;
            5) change_editor ;;
            6) install_languages ;;
            7) configure_archive ;;
            8) env_size ;;
            9) show_config ;;
            10) show_menu ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac    
    done
}


# Main execution
load_config
echo -e ""
show_menu
