#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
source ~/.dev-env-config

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
        
        # Ask about language configuration
        read -p "Configure languages for this project? (y/N): " configure_lang
        if [ "$configure_lang" = "y" ] || [ "$configure_lang" = "Y" ]; then
            ./language-manager.sh
        fi
        
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
    
    # Show language configurations if any
    if [ -d "$DEV_DIR/projects/languages" ] && [ -n "$(ls -A "$DEV_DIR/projects/languages")" ]; then
        echo -e "\n${YELLOW}Project Language Configurations:${NC}"
        ls -la "$DEV_DIR/projects/languages"
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

# Archive project
old_local_archive_project() {
    list_projects
    read -p "Enter project name to archive: " project_name
    
    active_dir="$DEV_DIR/projects/active/$project_name"
    archive_dir="$DEV_DIR/projects/archived/$project_name"
    lang_file="$DEV_DIR/projects/languages/${project_name}.lang"
    lang_archive="$DEV_DIR/projects/languages/archived/${project_name}.lang"
    
    if [ -d "$active_dir" ]; then
        mv "$active_dir" "$archive_dir"
        # Also archive language config if exists
        if [ -f "$lang_file" ]; then
            mkdir -p "$DEV_DIR/projects/languages/archived"
            mv "$lang_file" "$lang_archive"
        fi
        echo -e "${GREEN}Project '$project_name' archived!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found!${NC}"
    fi
}

# Replace archive_project function with remote archiving
archive_project() {
    list_projects
    read -p "Enter project name to archive: " project_name
    
    project_dir="$DEV_DIR/projects/active/$project_name"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return
    fi

    case $ARCHIVE_TYPE in
        "git")
            archive_to_git "$project_name" "$project_dir"
            ;;
        "cloud")
            archive_to_cloud "$project_name" "$project_dir"
            ;;
        "local")
            archive_to_local "$project_name" "$project_dir"
            ;;
        "none")
            echo -e "${YELLOW}Archiving disabled. Removing project locally.${NC}"
            rm -rf "$project_dir"
            ;;
    esac
    
    # Clean up local files
    rm -rf "$project_dir"
    echo -e "${GREEN}Project '$project_name' archived remotely!${NC}"
}

# Git archiving function
archive_to_git() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving to Git repository...${NC}"
    
    # Initialize git if not already
    cd "$project_dir" || return
    if [ ! -d ".git" ]; then
        git init
        git add .
        git commit -m "Initial archive of $project_name"
    fi
    
    # Add remote and push
    git remote add archive "$ARCHIVE_PATH" 2>/dev/null
    git push archive main --force
}

# Cloud storage archiving
archive_to_cloud() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving to cloud storage...${NC}"
    
    # Create compressed archive
    tar -czf "/tmp/${project_name}.tar.gz" -C "$project_dir" .
    
    # Copy to cloud location
    cp "/tmp/${project_name}.tar.gz" "$ARCHIVE_PATH/"
    rm "/tmp/${project_name}.tar.gz"
}

# Local network archiving
archive_to_local() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving to network location...${NC}"
    
    # Use rsync for efficient transfer
    rsync -avz "$project_dir/" "$ARCHIVE_PATH/$project_name/"
}

# Restore project
restore_project() {
    echo -e "${YELLOW}Archived Projects:${NC}"
    if [ -d "$DEV_DIR/projects/archived" ]; then
        ls -la "$DEV_DIR/projects/archived"
    else
        echo "No archived projects found."
        return
    fi
    
    read -p "Enter project name to restore: " project_name
    
    active_dir="$DEV_DIR/projects/active/$project_name"
    archive_dir="$DEV_DIR/projects/archived/$project_name"
    lang_file="$DEV_DIR/projects/languages/${project_name}.lang"
    lang_archive="$DEV_DIR/projects/languages/archived/${project_name}.lang"
    
    if [ -d "$archive_dir" ]; then
        mv "$archive_dir" "$active_dir"
        # Also restore language config if exists
        if [ -f "$lang_archive" ]; then
            mv "$lang_archive" "$lang_file"
        fi
        echo -e "${GREEN}Project '$project_name' restored!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found in archives!${NC}"
    fi
}

# Configure languages for project
configure_project_languages() {
    ./language-manager.sh
}

# Main menu
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Project Manager ===${NC}"
        echo -e "1. Clone GitHub repository"
        echo -e "2. List all projects"
        echo -e "3. Open project"
        echo -e "4. Archive project"
        echo -e "5. Restore project"
        echo -e "6. Configure project languages"
        echo -e "7. Back to main menu"
        echo -e "${YELLOW}=======================${NC}"
        
        read -p "Choose an option (1-7): " choice
        
        case $choice in
            1) clone_repo ;;
            2) list_projects ;;
            3) open_project ;;
            4) archive_project ;;
            5) restore_project ;;
            6) configure_project_languages ;;
            7) echo -e "${GREEN}Returning to main menu...${NC}"; break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Main execution
show_menu
