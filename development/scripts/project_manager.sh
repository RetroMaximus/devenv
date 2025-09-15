#!/bin/bash

# Load configuration
source ~/.dev_env_config

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

# Archive project
archive_project() {
    list_projects
    read -p "Enter project name to archive: " project_name
    
    active_dir="$DEV_DIR/projects/active/$project_name"
    archive_dir="$DEV_DIR/projects/archived/$project_name"
    
    if [ -d "$active_dir" ]; then
        mv "$active_dir" "$archive_dir"
        echo -e "${GREEN}Project '$project_name' archived!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found!${NC}"
    fi
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
    
    if [ -d "$archive_dir" ]; then
        mv "$archive_dir" "$active_dir"
        echo -e "${GREEN}Project '$project_name' restored!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found in archives!${NC}"
    fi
}
