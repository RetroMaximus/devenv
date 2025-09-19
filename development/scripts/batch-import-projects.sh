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
    
    echo -e "${YELLOW}This will copy projects FROM your local Windows machine TO this server.${NC}"
    echo -e "${YELLOW}Make sure your local machine is accessible and has the projects.${NC}"
    echo ""
    
    read -p "Enter your local Windows machine username: " local_user
    read -p "Enter your local Windows machine IP address: " local_ip
    read -p "Enter source directory on your local machine (e.g., C:\\pythonprojects): " source_dir
    
    if [ -z "$local_user" ] || [ -z "$local_ip" ] || [ -z "$source_dir" ]; then
        echo -e "${RED}All fields are required!${NC}"
        return 1
    fi
    
    local_machine="$local_user@$local_ip"
    
    # Convert Windows path to WSL-style path for rsync
    source_dir=$(echo "$source_dir" | sed 's/\\/\//g' | sed 's/^[Cc]://' | sed 's/\/\//\//g')
    source_dir="/c$source_dir"
    
    echo -e "${BLUE}Testing connection to your local machine ($local_machine)...${NC}"
    
    # Test SSH connection to local machine
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$local_machine" "exit" 2>/dev/null; then
        echo -e "${RED}Cannot connect to $local_machine via SSH${NC}"
        echo -e "${YELLOW}Make sure:${NC}"
        echo -e "1. SSH is enabled on your Windows machine"
        echo -e "2. Password authentication is enabled in sshd_config"
        echo -e "3. The Windows firewall allows SSH connections"
        echo -e "4. You know the password for $local_user"
        echo ""
        echo -e "${YELLOW}On Windows, enable SSH:${NC}"
        echo -e "Settings → Apps → Optional Features → OpenSSH Server"
        return 1
    fi
    
    echo -e "${BLUE}Checking if directory exists on your local machine...${NC}"
    
    # Check if the directory exists on the local machine
    if ! ssh "$local_machine" "[ -d \"$source_dir\" ]"; then
        echo -e "${RED}Directory '$source_dir' does not exist on your local machine${NC}"
        echo -e "${YELLOW}Please check the path. Common examples:${NC}"
        echo -e "C:\\pythonprojects  →  /c/pythonprojects"
        echo -e "D:\\projects       →  /d/projects"
        echo -e "C:\\Users\\$local_user\\projects → /c/Users/$local_user/projects"
        return 1
    fi
    
    echo -e "${BLUE}Scanning for projects in $source_dir on your local machine...${NC}"
    
    # Get list of projects from local machine
    projects=$(ssh "$local_machine" "cd \"$source_dir\" && ls -1d */ 2>/dev/null | sed 's/\/$//'")
    
    if [ $? -ne 0 ] || [ -z "$projects" ]; then
        echo -e "${YELLOW}No project directories found in $source_dir${NC}"
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
    failed_count=0
    
    for project in $projects; do
        target_dir="$DEV_DIR/projects/imported/$project"
        
        # Check if project already exists in any location
        if [ -d "$DEV_DIR/projects/active/$project" ] || [ -d "$DEV_DIR/projects/archived/$project" ] || [ -d "$DEV_DIR/projects/imported/$project" ]; then
            echo -e "${YELLOW}Skipping '$project' - already exists in projects directory${NC}"
            ((skipped_count++))
            continue
        fi
        
        echo -e "${BLUE}Importing '$project'...${NC}"
        
        # Copy from local machine to imported directory using rsync
        mkdir -p "$target_dir"
        if rsync -av --progress -e ssh $EXCLUDE_PATTERN "$local_machine:$source_dir/$project/" "$target_dir/"; then
            echo -e "${GREEN}Successfully imported '$project'${NC}"
            ((imported_count++))
        else
            echo -e "${RED}Failed to import '$project'${NC}"
            ((failed_count++))
        fi
    done
    
    echo -e "${GREEN}Import completed!${NC}"
    echo -e "Imported: ${GREEN}$imported_count${NC} projects"
    echo -e "Skipped: ${YELLOW}$skipped_count${NC} projects (already existed)"
    echo -e "Failed: ${RED}$failed_count${NC} projects"
    echo -e ""
    echo -e "${YELLOW}Projects are in: ~/devenv/development/projects/imported/${NC}"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    batch_import_projects
fi