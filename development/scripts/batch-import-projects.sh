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

# Function to normalize paths
normalize_path() {
    local path="$1"
    # Convert backslashes to forward slashes
    path=$(echo "$path" | sed 's/\\/\//g')
    # Convert Windows drive letters to Unix style
    path=$(echo "$path" | sed 's/^[Cc]:/\/c/')
    path=$(echo "$path" | sed 's/^[Dd]:/\/d/')
    # Remove any double slashes
    path=$(echo "$path" | sed 's/\/\//\//g')
    # Ensure no trailing slash for directory comparison
    echo "$path" | sed 's/\/$//'
}

batch_import_projects() {
    echo -e "${YELLOW}=== Batch Project Import ===${NC}"
    
    read -p "Enter source directory path (on your local machine): " source_dir
    read -p "Enter your local machine username@hostname: " local_machine
    
    if [ -z "$source_dir" ] || [ -z "$local_machine" ]; then
        echo -e "${RED}Source directory and local machine are required!${NC}"
        return 1
    fi
    
    # Normalize the source directory path
    source_dir=$(normalize_path "$source_dir")
    
    echo -e "${BLUE}Testing connection to $local_machine...${NC}"
    
    # Test SSH connection first
    if ! ssh "$local_machine" "exit"; then
        echo -e "${RED}Failed to connect to $local_machine${NC}"
        echo -e "${YELLOW}Make sure:${NC}"
        echo -e "1. SSH key authentication is set up"
        echo -e "2. The host is reachable"
        echo -e "3. SSH is running on the local machine"
        return 1
    fi
    
    echo -e "${BLUE}Checking if directory exists on $local_machine...${NC}"
    
    # Check if the directory exists on the remote machine
    if ! ssh "$local_machine" "[ -d \"$source_dir\" ]"; then
        echo -e "${RED}Directory '$source_dir' does not exist on $local_machine${NC}"
        echo -e "${YELLOW}Trying common alternatives...${NC}"
        
        # Try some common alternatives
        alternatives=(
            "$(echo "$source_dir" | sed 's/\/c\//\/mnt\/c\//')"
            "$(echo "$source_dir" | sed 's/^\/c\//C:\//' | sed 's/\//\\/g')"
            "$(echo "$source_dir" | sed 's/^\/c\//\/cygdrive\/c\//')"
            "/home/$(echo "$local_machine" | cut -d'@' -f1)/$(basename "$source_dir")"
        )
        
        for alt_dir in "${alternatives[@]}"; do
            if ssh "$local_machine" "[ -d \"$alt_dir\" ]"; then
                echo -e "${GREEN}Found alternative directory: $alt_dir${NC}"
                read -p "Use this directory instead? (y/N): " use_alt
                if [ "$use_alt" = "y" ] || [ "$use_alt" = "Y" ]; then
                    source_dir="$alt_dir"
                    break
                fi
            fi
        done
        
        if ! ssh "$local_machine" "[ -d \"$source_dir\" ]"; then
            echo -e "${RED}Could not find the directory. Please check the path and try again.${NC}"
            echo -e "${YELLOW}Common path formats:${NC}"
            echo -e "Windows: C:\\pythonprojects, /c/pythonprojects, /mnt/c/pythonprojects"
            echo -e "Linux: /home/username/projects, /path/to/projects"
            return 1
        fi
    fi
    
    echo -e "${BLUE}Scanning for projects in $source_dir on $local_machine...${NC}"
    
    # Get list of projects from local machine using ls instead of find (more reliable)
    projects=$(ssh "$local_machine" "ls -1 \"$source_dir\" 2>/dev/null | while read item; do if [ -d \"$source_dir/\$item\" ] && [ \"\$item\" != \".\" ] && [ \"\$item\" != \"..\" ] && [ \"\${item:0:1}\" != \".\" ]; then echo \"\$item\"; fi; done")
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to list directory contents${NC}"
        return 1
    fi
    
    if [ -z "$projects" ]; then
        echo -e "${YELLOW}No projects found in source directory.${NC}"
        echo -e "${YELLOW}Checked: $source_dir on $local_machine${NC}"
        echo -e "${YELLOW}Directory contents:${NC}"
        ssh "$local_machine" "ls -la \"$source_dir\""
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