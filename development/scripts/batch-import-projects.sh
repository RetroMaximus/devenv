#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
if [ -f ~/.dev-env-config ]; then
    source ~/.dev-env-config
else
    echo -e "${RED}Configuration file not found!${NC}"
    exit 1
fi

# Common directories to exclude (environment directories, cache, etc.)
EXCLUDE_DIRS=(
    ".venv" "venv" "env" "__pycache__" ".pytest_cache" ".mypy_cache"
    "node_modules" ".npm" ".yarn" "dist" "build" ".build"
    "target" ".target" ".gradle" ".mvn" ".idea" ".vscode"
    ".vs" ".git" ".svn" ".hg" ".bzr" ".DS_Store" "Thumbs.db"
    ".classpath" ".project" ".settings" "bin" "obj" "out"
    ".next" ".nuxt" ".cache" ".parcel-cache" ".webpack" ".serverless"
)

# Build rsync exclude pattern
EXCLUDE_PATTERN=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_PATTERN+="--exclude='$dir' "
done

batch_import_projects() {
    echo -e "${YELLOW}=== Batch Project Import ===${NC}"
    
    read -p "Enter source directory path: " source_dir
    read -p "Enter remote machine [user@host] (leave empty for local): " remote_machine
    
    # Validate source directory
    if [ -z "$remote_machine" ]; then
        # Local copy
        if [ ! -d "$source_dir" ]; then
            echo -e "${RED}Source directory does not exist!${NC}"
            return 1
        fi
    else
        # Remote copy - test connection
        if ! ssh -q "$remote_machine" exit; then
            echo -e "${RED}Cannot connect to $remote_machine${NC}"
            return 1
        fi
    fi
    
    # Get list of projects
    echo -e "${BLUE}Scanning for projects...${NC}"
    
    if [ -z "$remote_machine" ]; then
        # Local projects
        projects=$(find "$source_dir" -maxdepth 1 -type d -not -path "$source_dir" -not -name ".*" -exec basename {} \;)
    else
        # Remote projects
        projects=$(ssh "$remote_machine" "find \"$source_dir\" -maxdepth 1 -type d -not -path \"$source_dir\" -not -name \".*\" -exec basename {} \;")
    fi
    
    if [ -z "$projects" ]; then
        echo -e "${YELLOW}No projects found in source directory.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Found projects:${NC}"
    echo "$projects"
    echo ""
    
    # Confirm import
    read -p "Import all these projects? (y/N): " confirm_import
    if [ "$confirm_import" != "y" ] && [ "$confirm_import" != "Y" ]; then
        echo -e "${YELLOW}Import cancelled.${NC}"
        return
    fi
    
    # Import each project
    imported_count=0
    skipped_count=0
    
    for project in $projects; do
        target_dir="$DEV_DIR/projects/active/$project"
        
        # Check if project already exists
        if [ -d "$target_dir" ]; then
            echo -e "${YELLOW}Skipping '$project' - already exists${NC}"
            ((skipped_count++))
            continue
        fi
        
        echo -e "${BLUE}Importing '$project'...${NC}"
        
        if [ -z "$remote_machine" ]; then
            # Local copy using rsync
            mkdir -p "$target_dir"
            if rsync -av --progress $EXCLUDE_PATTERN "$source_dir/$project/" "$target_dir/"; then
                echo -e "${GREEN}Successfully imported '$project'${NC}"
                ((imported_count++))
            else
                echo -e "${RED}Failed to import '$project'${NC}"
            fi
        else
            # Remote copy using rsync over ssh
            mkdir -p "$target_dir"
            if rsync -av --progress -e ssh $EXCLUDE_PATTERN "$remote_machine:$source_dir/$project/" "$target_dir/"; then
                echo -e "${GREEN}Successfully imported '$project'${NC}"
                ((imported_count++))
            else
                echo -e "${RED}Failed to import '$project'${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}Import completed!${NC}"
    echo -e "Imported: ${GREEN}$imported_count${NC} projects"
    echo -e "Skipped: ${YELLOW}$skipped_count${NC} projects (already existed)"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    batch_import_projects
fi