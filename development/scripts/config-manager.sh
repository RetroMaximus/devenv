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

load_sync_tools() {
    local sync_tools_path="$DEV_DIR/development/scripts/sync-tools.sh"
    if [ -f "$sync_tools_path" ]; then
        source "$sync_tools_path"
    else
        echo -e "${RED}Sync tools not found at $sync_tools_path${NC}"
        return 1
    fi
}

# Load or create configuration
load_config() {
    if [ -f ~/.dev-env-config ]; then
        source "${CONFIG_FILE}"
        # Set default values if any variables are empty
        DEV_DIR="${DEV_DIR:-$USER_HOME/devenv/development}"
        EDITOR="${EDITOR:-neovim}"
        GIT_USER="${GIT_USER:-none}"
        GIT_PATH="${GIT_PATH:-none}"
        ARCHIVE_TYPE="${ARCHIVE_TYPE:-none}"
        ARCHIVE_PATH="${ARCHIVE_PATH:-none}"
        OPEN_PROJECT="${OPEN_PROJECT:-none}"
    else
        # Set default values
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

# Save config function
# Save configuration properly
save_config() {
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Read current config and update values
    if [ -f "${CONFIG_FILE}" ]; then
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
        done < "${CONFIG_FILE}"
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
    sudo mv "$temp_file" "${CONFIG_FILE}"
    echo -e "${GREEN}Configuration saved!${NC}"
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
        "neovim") nvim "${CONFIG_FILE}" ;;
        "emacs") emacs "${CONFIG_FILE}" ;;
        "nano") nano "${CONFIG_FILE}" ;;
    esac
    # Reload config after editing
    source "${CONFIG_FILE}"
}

# Add archive configuration menu option
configure_archive() {
    
    echo -e "${YELLOW}Current Archive Configuration:${NC}"
    echo "Archive Type: $ARCHIVE_TYPE"
    echo "Archive Path: $ARCHIVE_PATH"
    echo ""
    
    echo -e "${YELLOW}Configure Archive Settings:${NC}"
    echo "1. Change archive type"
    echo "2. Change archive path"
    echo "3. Back to main menu"
    
    read -p "Choose (1-3): " config_choice
    
    case $config_choice in
        1)
            echo -e "${YELLOW}Select archive type:${NC}"
            echo "1. none (remove only)"
            echo "2. git"
            echo "3. cloud"
            echo "4. local"
            read -p "Choose (1-4): " type_choice
            
            case $type_choice in
                1) ARCHIVE_TYPE="none" ;;
                2) ARCHIVE_TYPE="git" ;;
                3) ARCHIVE_TYPE="cloud" ;;
                4) ARCHIVE_TYPE="local" ;;
                *) echo -e "${RED}Invalid choice!${NC}"; return ;;
            esac
            
            # Save configuration using the new function
            save_config
            echo -e "${GREEN}Archive type updated to: $ARCHIVE_TYPE${NC}"
            ;;
        2)
            read -p "Enter new archive path: " new_path
            ARCHIVE_PATH="$new_path"
            # Save configuration using the new function
            save_config
            echo -e "${GREEN}Archive path updated to: $ARCHIVE_PATH${NC}"
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            ;;
    esac
}
# Sync tools menu
show_sync_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Sync Tools ===${NC}"
        echo -e "1. Sync a project"
        echo -e "2. Setup git auto-sync hook"
        echo -e "3. Schedule automatic backups"
        echo -e "4. Show sync status"
        echo -e "5. Back to config menu"
        echo -e "${YELLOW}===================${NC}"

        read -p "Choose an option (1-5): " choice

        case $choice in
            1) sync_project_menu ;;
            2) setup_hook_menu ;;
            3) schedule_backup_menu ;;
            4) show_sync_status ;;
            5) break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Helper functions for sync menu
sync_project_menu() {
    list_projects
    read -p "Enter project name to sync: " project_name
    source "${DEV_DIR}/scripts/sync-tools.sh"
    sync_project "$project_name"
}

setup_hook_menu() {
    list_projects
    read -p "Enter project name for auto-sync hook: " project_name
    source "${DEV_DIR}/scripts/sync-tools.sh"
    setup_git_archiving "$project_name"
}

schedule_backup_menu() {
    list_projects
    read -p "Enter project name to schedule: " project_name
    read -p "Enter schedule (daily/weekly/hourly or cron): " schedule
    source "${DEV_DIR}/scripts/sync-tools.sh"
    setup_backup_schedule "$project_name" "$schedule"
}

show_sync_status() {
    source "${DEV_DIR}/scripts/sync-tools.sh"
    list_sync_status
}

# List projects for selection
list_projects() {
    echo -e "${YELLOW}Available projects:${NC}"
    if [ -d "$USER_HOME/projects/active" ]; then
        ls "$USER_HOME/projects/active"
    else
        echo -e "${RED}No projects found!${NC}"
        return 1
    fi
}
# Main menu
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Configuration Manager ===${NC}"
        echo -e "1. Show current configuration"
        echo -e "2. Change editor preference"
        echo -e "3. Change development directory"
        echo -e "4. Configure project archiving"
        echo -e "5. Sync tools menu"
        echo -e "6. Help generator configuration"
        echo -e "7. Edit configuration manually"
	
        echo -e "8. Back to main menu"
        echo -e "${YELLOW}==============================${NC}"

        read -p "Choose an option (1-7): " choice

        case $choice in
            1) show_config ;;
            2) change_editor ;;
            3) change_dev_dir ;;
            4) configure_archive ;;
            5) show_sync_menu ;;
            6) source "${DEV_DIR}/scripts/help-gen.sh" && configure_help_gen ;;
            7) edit_config ;;
            8) echo -e "${GREEN}Returning to main menu...${NC}"; break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}
# Main execution
show_menu
