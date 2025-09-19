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
fi

# Clone GitHub repository
clone_repo() {
    read -p "Enter GitHub repository URL: " repo_url
    read -p "Enter project name (or press enter for repo name): " project_name
    
    if [ -z "$project_name" ]; then
        project_name=$(basename "$repo_url" .git)
    fi
    
    target_dir="$USER_HOME/projects/active/$project_name"
    
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
    if [ -d "$USER_HOME/projects/active" ]; then
        ls -la "$USER_HOME/projects/active"
    else
        echo "No active projects found."
    fi
    
    echo -e "${YELLOW}Imported Projects:${NC}"
    if [ -d "$USER_HOME/projects/imported" ]; then
        ls -la "$USER_HOME/projects/imported"
    else
        echo "No imported projects found."
    fi
    
    echo -e "\n${YELLOW}Archived Projects:${NC}"
    if [ -d "$USER_HOME/projects/archived" ]; then
        ls -la "$USER_HOME/projects/archived"
    else
        echo "No archived projects found."
    fi
}


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


# Open project
open_project() {
    list_projects
    read -p "Enter project name to open: " project_name
    
    project_dir="$USER_HOME/projects/active/$project_name"
    
    if [ -d "$project_dir" ]; then
        cd "$project_dir" || return
        OPEN_PROJECT="$project_name"
        save_config
        echo -e "${GREEN}Changed to project directory: $project_dir${NC}"
        echo -e "${GREEN}Current project: $OPEN_PROJECT${NC}"
        
        # Check if language config exists and show info
        lang_file="$USER_HOME/projects/languages/active/${project_name}.lang"
        lang_archive="$USER_HOME/projects/languages/archived/${project_name}.lang"
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


# Git archiving function
archive_to_git() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving to Git repository...${NC}"
    
    # Initialize git if not already
    cd "$project_dir" || return
    if [ ! -d ".git" ]; then
        sudo git init
        sudo git add .
        sudo git commit -m "Initial archive of $project_name"
    fi
    
    # Add remote and push
    sudo git remote add archive "$ARCHIVE_PATH" 2>/dev/null
    sudo git push archive main --force
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully archived to Git repository!${NC}"
        return 0
    else
        echo -e "${RED}Failed to archive to Git repository!${NC}"
        return 1
    fi
}

# Cloud storage archiving
archive_to_cloud() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving to cloud storage...${NC}"
    
    # Create compressed archive
    sudo tar -czf "/tmp/${project_name}.tar.gz" -C "$project_dir" .
    
    # Copy to cloud location
    sudo cp "/tmp/${project_name}.tar.gz" "$ARCHIVE_PATH/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully archived to cloud storage!${NC}"
        sudo rm "/tmp/${project_name}.tar.gz"
        return 0
    else
        echo -e "${RED}Failed to archive to cloud storage!${NC}"
        sudo rm "/tmp/${project_name}.tar.gz"
        return 1
    fi
}

# Local network archiving
archive_to_local() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving to network location...${NC}"
    
    # Use rsync for efficient transfer
    sudo rsync -avz "$project_dir/" "$ARCHIVE_PATH/$project_name/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully archived to network location!${NC}"
        return 0
    else
        echo -e "${RED}Failed to archive to network location!${NC}"
        return 1
    fi
}

# Local archiving only
archive_to_local_only() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Archiving locally...${NC}"
    
    archive_dir="$USER_HOME/projects/archived/$project_name"
    lang_file="$USER_HOME/projects/languages/active/${project_name}.lang"
    lang_archive="$USER_HOME/projects/languages/archived/${project_name}.lang"
    
    if [ -d "$project_dir" ]; then
        sudo mv "$project_dir" "$archive_dir"
        # Also archive language config if exists
        if [ -f "$lang_file" ]; then
            sudo mkdir -p "$USER_HOME/projects/languages/archived"
            sudo mv "$lang_file" "$lang_archive"
        fi
        echo -e "${GREEN}Project '$project_name' archived locally!${NC}"
        return 0
    else
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return 1
    fi
}

# Archive project with remote options
archive_project() {
    list_projects
    read -p "Enter project name to archive: " project_name
    
    project_dir="$USER_HOME/projects/active/$project_name"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return
    fi

    # Show archiving options
    echo -e "${YELLOW}Select archiving method:${NC}"
    echo "1. Local only (move to archived folder)"
    echo "2. Git repository"
    echo "3. Cloud storage"
    echo "4. Network location"
    echo "5. Cancel"
    
    read -p "Choose (1-5): " archive_choice
    
    case $archive_choice in
        1)
            archive_to_local_only "$project_name" "$project_dir"
            ;;
        2)
            if [ -z "$ARCHIVE_PATH" ]; then
                echo -e "${RED}Git archive path not configured!${NC}"
                return
            fi
            archive_to_git "$project_name" "$project_dir"
            ;;
        3)
            if [ -z "$ARCHIVE_PATH" ]; then
                echo -e "${RED}Cloud archive path not configured!${NC}"
                return
            fi
            archive_to_cloud "$project_name" "$project_dir"
            ;;
        4)
            if [ -z "$ARCHIVE_PATH" ]; then
                echo -e "${RED}Network archive path not configured!${NC}"
                return
            fi
            archive_to_local "$project_name" "$project_dir"
            ;;
        5)
            echo -e "${YELLOW}Archive cancelled.${NC}"
            return
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            return
            ;;
    esac
    
    # Only remove local files if archiving was successful
    if [ $? -eq 0 ] && [ $archive_choice -ne 1 ]; then
        sudo rm -rf "$project_dir"
        echo -e "${GREEN}Project '$project_name' archived remotely!${NC}"
    fi
}

# Restore project
restore_project() {
    echo -e "${YELLOW}Archived Projects:${NC}"
    if [ -d "$USER_HOME/projects/archived" ]; then
        ls -la "$USER_HOME/projects/archived"
    else
        echo "No archived projects found."
        return
    fi
    
    read -p "Enter project name to restore: " project_name
    
    active_dir="$USER_HOME/projects/active/$project_name"
    archive_dir="$USER_HOME/projects/archived/$project_name"
    lang_file="$USER_HOME/projects/languages/active/${project_name}.lang"
    lang_archive="$USER_HOME/projects/languages/archived/${project_name}.lang"
    
    if [ -d "$archive_dir" ]; then
        mv "$archive_dir" "$active_dir"
        # Also restore language config if exists
        if [ -f "$lang_archive" ]; then
            sudo mv "$lang_archive" "$lang_file"
        fi
        echo -e "${GREEN}Project '$project_name' restored!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found in archives!${NC}"
    fi
}

# Configure languages for project
configure_project_languages() {
    
    
 
    if [ -f "./language-manager.sh" ]; then
        sudo bash ./language-manager.sh
    elif [ -f "$DEV_DIR/scripts/language-manager.sh" ]; then
        sudo bash "$DEV_DIR/scripts/language-manager.sh"
    else
        echo -e "${RED}Language script not found!${NC}"
    fi

}

# Configure archive settings
configure_archive_settings() {
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
            
            # Update config file
            sed -i "s/ARCHIVE_TYPE=.*/ARCHIVE_TYPE=\"$ARCHIVE_TYPE\"/" ~/.dev-env-config
            echo -e "${GREEN}Archive type updated to: $ARCHIVE_TYPE${NC}"
            ;;
        2)
            read -p "Enter new archive path: " new_path
            ARCHIVE_PATH="$new_path"
            # Update config file
            sed -i "s/ARCHIVE_PATH=.*/ARCHIVE_PATH=\"$ARCHIVE_PATH\"/" ~/.dev-env-config
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
# Create new project
create_new_project() {
    read -p "Enter project name: " project_name
    
    target_dir="$USER_HOME/projects/active/$project_name"
    
    if [ -d "$target_dir" ]; then
        echo -e "${RED}Project '$project_name' already exists!${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Creating new project: $project_name...${NC}"
    sudo mkdir -p "$target_dir"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Project created successfully!${NC}"
        
        # Ask about Git initialization
        read -p "Initialize Git repository? (y/N): " init_git
        if [ "$init_git" = "y" ] || [ "$init_git" = "Y" ]; then
            cd "$target_dir" || return
            sudo git init
            echo -e "${GREEN}Git repository initialized!${NC}"
            
            # Ask about adding remote
            read -p "Add remote GitHub repository? (y/N): " add_remote
            if [ "$add_remote" = "y" ] || [ "$add_remote" = "Y" ]; then
                read -p "Enter GitHub repository URL: " repo_url
                sudo git remote add origin "$repo_url"
                echo -e "${GREEN}Remote repository added!${NC}"
            fi
        fi
        
        # Ask about language configuration
        read -p "Configure languages for this project? (y/N): " configure_lang
        if [ "$configure_lang" = "y" ] || [ "$configure_lang" = "Y" ]; then
            configure_project_languages
        fi
        
        cd "$target_dir" || return
    else
        echo -e "${RED}Failed to create project!${NC}"
    fi
}

# Delete project from archives
delete_project() {
    echo -e "${YELLOW}Archived Projects:${NC}"
    if [ -d "$USER_HOME/projects/archived" ]; then
        archived_projects=$(ls "$USER_HOME/projects/archived")
        if [ -z "$archived_projects" ]; then
            echo "No archived projects found."
            return
        fi
        ls -la "$USER_HOME/projects/archived"
    else
        echo "No archived projects found."
        return
    fi
    
    read -p "Enter project name to delete: " project_name
    
    # Check if project is active (should not delete active projects)
    if [ -d "$USER_HOME/projects/active/$project_name" ]; then
        echo -e "${RED}Cannot delete active project! Please archive it first.${NC}"
        return 1
    fi
    
    archive_dir="$USER_HOME/projects/archived/$project_name"
    lang_archive="$USER_HOME/projects/languages/archived/${project_name}.lang"
    
    if [ -d "$archive_dir" ]; then
        # Confirm deletion
        echo -e "${RED}WARNING: This will permanently delete project '$project_name'${NC}"
        read -p "Are you sure you want to delete? (y/N): " confirm_delete
        
        if [ "$confirm_delete" = "y" ] || [ "$confirm_delete" = "Y" ]; then
            # Delete from remote archive if configured
            if [ "$ARCHIVE_TYPE" != "none" ] && [ -n "$ARCHIVE_PATH" ]; then
                echo -e "${BLUE}Removing from remote archive...${NC}"
                case $ARCHIVE_TYPE in
                    "git")
                        # For git, we'd need to remove the remote branch/repo
                        echo -e "${YELLOW}Note: Git repository must be manually deleted from $ARCHIVE_PATH${NC}"
                        ;;
                    "cloud")
                        # Remove cloud archive
                        cloud_file="$ARCHIVE_PATH/${project_name}.tar.gz"
                        if [ -f "$cloud_file" ]; then
                            sudo rm -f "$cloud_file"
                            echo -e "${GREEN}Removed cloud archive.${NC}"
                        fi
                        ;;
                    "local")
                        # Remove network archive
                        network_dir="$ARCHIVE_PATH/$project_name"
                        if [ -d "$network_dir" ]; then
                            sudo rm -rf "$network_dir"
                            echo -e "${GREEN}Removed network archive.${NC}"
                        fi
                        ;;
                esac
            fi
            
            # Delete local archive
            sudo rm -rf "$archive_dir"
            
            # Delete language config if exists
            if [ -f "$lang_archive" ]; then
                sudo rm -f "$lang_archive"
            fi
            
            echo -e "${GREEN}Project '$project_name' deleted successfully!${NC}"
        else
            echo -e "${YELLOW}Deletion cancelled.${NC}"
        fi
    else
        echo -e "${RED}Project '$project_name' not found in archives!${NC}"
    fi
}

# List imported projects
list_imported_projects() {
    echo -e "${YELLOW}Imported Projects:${NC}"
    if [ -d "$USER_HOME/projects/imported" ]; then
        ls -la "$USER_HOME/projects/imported"
    else
        echo "No imported projects found."
    fi
}

# Activate imported project (move to active)
activate_imported_project() {
    list_imported_projects
    read -p "Enter project name to activate: " project_name
    
    imported_dir="$USER_HOME/projects/imported/$project_name"
    active_dir="$USER_HOME/projects/active/$project_name"
    
    if [ -d "$imported_dir" ]; then
        mv "$imported_dir" "$active_dir"
        echo -e "${GREEN}Project '$project_name' activated and moved to active directory!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found in imported directory!${NC}"
    fi
}

# Archive imported project (move to archived)
archive_imported_project() {
    list_imported_projects
    read -p "Enter project name to archive: " project_name
    
    imported_dir="$USER_HOME/projects/imported/$project_name"
    archive_dir="$USER_HOME/projects/archived/$project_name"
    
    if [ -d "$imported_dir" ]; then
        mv "$imported_dir" "$archive_dir"
        echo -e "${GREEN}Project '$project_name' archived directly!${NC}"
    else
        echo -e "${RED}Project '$project_name' not found in imported directory!${NC}"
    fi
}

# Delete imported project
delete_imported_project() {
    list_imported_projects
    read -p "Enter project name to delete: " project_name
    
    imported_dir="$USER_HOME/projects/imported/$project_name"
    
    if [ -d "$imported_dir" ]; then
        # Confirm deletion
        echo -e "${RED}WARNING: This will permanently delete project '$project_name' from imported directory${NC}"
        read -p "Are you sure you want to delete? (y/N): " confirm_delete
        
        if [ "$confirm_delete" = "y" ] || [ "$confirm_delete" = "Y" ]; then
            rm -rf "$imported_dir"
            echo -e "${GREEN}Project '$project_name' deleted from imported directory!${NC}"
        else
            echo -e "${YELLOW}Deletion cancelled.${NC}"
        fi
    else
        echo -e "${RED}Project '$project_name' not found in imported directory!${NC}"
    fi
}
# Submenu for imported projects
manage_imported_projects() {
    while true; do
        echo -e "\n${YELLOW}=== Manage Imported Projects ===${NC}"
        echo -e "1. List imported projects"
        echo -e "2. Activate project (move to active)"
        echo -e "3. Archive project (move to archived)"
        echo -e "4. Delete imported project"
        echo -e "5. Back to main menu"
        echo -e "${YELLOW}===============================${NC}"
        
        read -p "Choose an option (1-5): " choice
        
        case $choice in
            1) list_imported_projects ;;
            2) activate_imported_project ;;
            3) archive_imported_project ;;
            4) delete_imported_project ;;
            5) break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}
# Main menu
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Project Manager ===${NC}"
        echo -e "1. Create new project"
        echo -e "2. Clone GitHub repository"
        echo -e "3. List all projects"
        echo -e "4. Open project"
        echo -e "5. Archive project"
        echo -e "6. Restore project"
        echo -e "7. Delete project from archives"
        echo -e "8. Batch import projects"
        echo -e "9. Manage imported projects"
        echo -e "10. Configure project languages"
        echo -e "11. Configure archive settings"
        echo -e "12. Back to main menu"
        echo -e "${YELLOW}=======================${NC}"
        
        read -p "Choose an option (1-12): " choice
        
        case $choice in
            1) create_new_project ;;
            2) clone_repo ;;
            3) list_projects ;;
            4) open_project ;;
            5) archive_project ;;
            6) restore_project ;;
            7) delete_project ;;
            8) 
                if [ -f "./batch-import-projects.sh" ]; then
                    ./batch-import-projects.sh
                elif [ -f "$DEV_DIR/scripts/batch-import-projects.sh" ]; then
                    bash "$DEV_DIR/scripts/batch-import-projects.sh"
                else
                    echo -e "${RED}Batch import script not found!${NC}"
                fi
                ;;
            9) manage_imported_projects ;;
            10) configure_project_languages ;;
            11) configure_archive_settings ;;
            12) echo -e "${GREEN}Returning to main menu...${NC}"; break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Main execution
show_menu

