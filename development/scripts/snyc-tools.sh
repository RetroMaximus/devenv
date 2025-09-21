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
CONFIG_FILE="$USER_HOME/.dev_env_config"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo -e "${RED}Configuration file not found! Run setup-dev-env.sh first.${NC}"
        exit 1
    fi
}

# Load config
load_config

# Sync project to configured archive
sync_project() {
    local project_name=$1
    local project_dir="$USER_HOME/projects/active/$project_name"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return 1
    fi

    case $ARCHIVE_TYPE in
        "git")
            sync_to_git "$project_name" "$project_dir"
            ;;
        "dropbox")
            sync_to_dropbox "$project_name" "$project_dir"
            ;;
        "googledrive")
            sync_to_google_drive "$project_name" "$project_dir"
            ;;
        "onedrive")
            sync_to_onedrive "$project_name" "$project_dir"
            ;;
        "local")
            sync_to_local "$project_name" "$project_dir"
            ;;
        *)
            echo -e "${RED}Unknown archive type: $ARCHIVE_TYPE${NC}"
            return 1
            ;;
    esac
}

# Git synchronization
sync_to_git() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Syncing '$project_name' to Git repository...${NC}"
    
    cd "$project_dir" || return 1
    
    # Initialize git if not already
    if [ ! -d ".git" ]; then
        git init
        git config user.name "$GIT_USER"
        git config user.email "$GIT_EMAIL"
    fi
    
    # Add all changes
    git add .
    
    # Check if there are changes to commit
    if git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}No changes to commit.${NC}"
        return 0
    fi
    
    # Commit changes
    git commit -m "Sync: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Add remote if not exists
    if ! git remote get-url archive &>/dev/null; then
        git remote add archive "$ARCHIVE_PATH"
    fi
    
    # Push to remote
    if git push archive main 2>/dev/null; then
        echo -e "${GREEN}Successfully synced to Git repository!${NC}"
    else
        # If push fails, try force push for first time
        if git push -u archive main --force; then
            echo -e "${GREEN}Successfully synced to Git repository!${NC}"
        else
            echo -e "${RED}Failed to sync to Git repository!${NC}"
            return 1
        fi
    fi
}

# Dropbox synchronization
sync_to_dropbox() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Syncing '$project_name' to Dropbox...${NC}"
    
    # Create compressed archive
    local archive_name="${project_name}_$(date '+%Y%m%d_%H%M%S').tar.gz"
    local temp_archive="/tmp/$archive_name"
    
    tar -czf "$temp_archive" -C "$project_dir" .
    
    # Copy to Dropbox location
    local dropbox_path="$ARCHIVE_PATH/$archive_name"
    
    if cp "$temp_archive" "$dropbox_path"; then
        echo -e "${GREEN}Successfully synced to Dropbox!${NC}"
        # Keep only last 5 backups
        ls -t "$ARCHIVE_PATH/${project_name}_"*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f --
    else
        echo -e "${RED}Failed to sync to Dropbox!${NC}"
    fi
    
    rm -f "$temp_archive"
}

# Google Drive synchronization (using rclone)
sync_to_google_drive() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Syncing '$project_name' to Google Drive...${NC}"
    
    if ! command -v rclone &> /dev/null; then
        echo -e "${RED}rclone not installed! Install with: sudo apt install rclone${NC}"
        return 1
    fi
    
    # Create compressed archive
    local archive_name="${project_name}_$(date '+%Y%m%d_%H%M%S').tar.gz"
    local temp_archive="/tmp/$archive_name"
    
    tar -czf "$temp_archive" -C "$project_dir" .
    
    # Sync using rclone
    if rclone copy "$temp_archive" "$ARCHIVE_PATH"; then
        echo -e "${GREEN}Successfully synced to Google Drive!${NC}"
    else
        echo -e "${RED}Failed to sync to Google Drive!${NC}"
    fi
    
    rm -f "$temp_archive"
}

# OneDrive synchronization (using rclone)
sync_to_onedrive() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Syncing '$project_name' to OneDrive...${NC}"
    
    if ! command -v rclone &> /dev/null; then
        echo -e "${RED}rclone not installed! Install with: sudo apt install rclone${NC}"
        return 1
    fi
    
    # Create compressed archive
    local archive_name="${project_name}_$(date '+%Y%m%d_%H%M%S').tar.gz"
    local temp_archive="/tmp/$archive_name"
    
    tar -czf "$temp_archive" -C "$project_dir" .
    
    # Sync using rclone
    if rclone copy "$temp_archive" "$ARCHIVE_PATH"; then
        echo -e "${GREEN}Successfully synced to OneDrive!${NC}"
    else
        echo -e "${RED}Failed to sync to OneDrive!${NC}"
    fi
    
    rm -f "$temp_archive"
}

# Local network synchronization
sync_to_local() {
    local project_name=$1
    local project_dir=$2
    
    echo -e "${BLUE}Syncing '$project_name' to network location...${NC}"
    
    # Create destination directory
    mkdir -p "$ARCHIVE_PATH/$project_name"
    
    # Use rsync for efficient sync
    if rsync -av --delete "$project_dir/" "$ARCHIVE_PATH/$project_name/"; then
        echo -e "${GREEN}Successfully synced to network location!${NC}"
    else
        echo -e "${RED}Failed to sync to network location!${NC}"
        return 1
    fi
}

# Git-based archiving with hooks
setup_git_archiving() {
    local project_name=$1
    local project_dir="$DEV_DIR/projects/active/$project_name"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return 1
    fi
    
    cd "$project_dir" || return 1
    
    # Create post-commit hook for auto-sync
    local hook_file=".git/hooks/post-commit"
    
    cat > "$hook_file" << EOF
#!/bin/bash
# Auto-sync hook for project $project_name
~/development/scripts/sync-tools.sh sync "$project_name"
EOF
    
    chmod +x "$hook_file"
    echo -e "${GREEN}Git auto-sync hook installed for '$project_name'!${NC}"
}

# Automated backup scheduler
setup_backup_schedule() {
    local project_name=$1
    local schedule=$2  # e.g., "daily", "weekly", "0 2 * * *" (cron format)
    
    local project_dir="$DEV_DIR/projects/active/$project_name"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return 1
    fi
    
    # Convert human-readable schedule to cron format
    local cron_schedule
    case $schedule in
        "daily")
            cron_schedule="0 2 * * *"  # 2 AM daily
            ;;
        "weekly")
            cron_schedule="0 2 * * 0"  # 2 AM every Sunday
            ;;
        "hourly")
            cron_schedule="0 * * * *"  # Every hour
            ;;
        *)
            cron_schedule="$schedule"  # Assume it's already in cron format
            ;;
    esac
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$cron_schedule ~/development/scripts/sync-tools.sh sync \"$project_name\"") | crontab -
    
    echo -e "${GREEN}Scheduled automatic sync for '$project_name' at: $cron_schedule${NC}"
}

# List sync status
list_sync_status() {
    echo -e "${YELLOW}=== Sync Configuration ===${NC}"
    echo "Archive Type: $ARCHIVE_TYPE"
    echo "Archive Path: $ARCHIVE_PATH"
    echo "Cloud Type: $CLOUD_TYPE"
    echo ""
    
    echo -e "${YELLOW}=== Project Sync Status ===${NC}"
    
    if [ -d "$DEV_DIR/projects/active" ]; then
        for project in "$DEV_DIR/projects/active"/*; do
            if [ -d "$project" ]; then
                local project_name=$(basename "$project")
                local sync_status="Not configured"
                
                if [ -f "$project/.git/hooks/post-commit" ]; then
                    sync_status="Git auto-sync enabled"
                fi
                
                echo "- $project_name: $sync_status"
            fi
        done
    else
        echo "No active projects found."
    fi
}

# Main function
main() {
    case $1 in
        "sync")
            if [ -z "$2" ]; then
                echo -e "${RED}Usage: $0 sync <project-name>${NC}"
                exit 1
            fi
            sync_project "$2"
            ;;
        "setup-hook")
            if [ -z "$2" ]; then
                echo -e "${RED}Usage: $0 setup-hook <project-name>${NC}"
                exit 1
            fi
            setup_git_archiving "$2"
            ;;
        "schedule")
            if [ -z "$3" ]; then
                echo -e "${RED}Usage: $0 schedule <project-name> <schedule>${NC}"
                echo "Schedule examples: daily, weekly, hourly, or cron format like '0 2 * * *'"
                exit 1
            fi
            setup_backup_schedule "$2" "$3"
            ;;
        "status")
            list_sync_status
            ;;
        "help"|"")
            echo -e "${YELLOW}Sync Tools Usage:${NC}"
            echo "  $0 sync <project-name>      - Sync a project to archive"
            echo "  $0 setup-hook <project-name> - Setup git auto-sync hook"
            echo "  $0 schedule <project> <time> - Schedule automatic sync"
            echo "  $0 status                  - Show sync status"
            echo "  $0 help                    - Show this help"
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo "Use: $0 help"
            exit 1
            ;;
    esac
}

# Run main function with arguments
main "$@"
