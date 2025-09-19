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
    
    read -p "Enter source directory path (on your local machine): " source_dir
    read -p "Enter your local machine username@hostname: " local_machine
    
    if [ -z "$source_dir" ] || [ -z "$local_machine" ]; then
        echo -e "${RED}Source directory and local machine are required!${NC}"
        return 1
    fi
    
    # Convert Windows paths to Unix-style for rsync
    source_dir=$(echo "$source_dir" | sed 's/\\/\//g' | sed 's/C:/\/c/g' | sed 's/\/\//\//g')
    
    echo -e "${BLUE}Scanning for projects on $local_machine...${NC}"
    
    # Get list of projects from local machine
    projects=$(sudo ssh "$local_machine" "sudo find \"$source_dir\" -maxdepth 1 -type d -not -path \"$source_dir\" -not -name \".*\" -exec basename {} \; 2>/dev/null")
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to connect to $local_machine or access directory${NC}"
        echo -e "${YELLOW}Make sure:${NC}"
        echo -e "1. SSH key authentication is set up"
        echo -e "2. The directory exists on your local machine"
        echo -e "3. You have read permissions"
        return 1
    fi
    
    if [ -z "$projects" ]; then
        echo -e "${YELLOW}No projects found in source directory.${NC}"
        echo -e "${YELLOW}Checked: $source_dir on $local_machine${NC}"
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
    
    # Import each project to imported directory
    imported_count=0
    skipped_count=0
    
    for project in $projects; do
        target_dir="$DEV_DIR/projects/imported/$project"
        
        # Check if project already exists in any location
        if [ -d "$DEV_DIR/projects/active/$project" ] || [ -d "$DEV_DIR/projects/archived/$project" ] || [ -d "$DEV_DIR/projects/imported/$project" ]; then
            echo -e "${YELLOW}Skipping '$project' - already exists in projects directory${NC}"
            ((skipped_count++))
            continue
        fi
        
        echo -e "${BLUE}Importing '$project'...${NC}"
        
        # Copy from local machine to imported directory
        mkdir -p "$target_dir"
        if rsync -av --progress -e ssh $EXCLUDE_PATTERN "$local_machine:$source_dir/$project/" "$target_dir/"; then
            echo -e "${GREEN}Successfully imported '$project' to imported directory${NC}"
            ((imported_count++))
        else
            echo -e "${RED}Failed to import '$project'${NC}"
        fi
    done
    
    echo -e "${GREEN}Import completed!${NC}"
    echo -e "Imported: ${GREEN}$imported_count${NC} projects to ~/devenv/development/projects/imported/"
    echo -e "Skipped: ${YELLOW}$skipped_count${NC} projects (already existed)"
    echo -e ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Use 'projects' command to manage projects"
    echo -e "2. Move projects from imported to active/archived as needed"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    batch_import_projects
fi