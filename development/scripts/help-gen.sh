#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get correct user home directory
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    USER_HOME=$HOME
fi

# Configuration
CONFIG_FILE="$USER_HOME/.dev-env-config"
source "$CONFIG_FILE"

# Help generator configuration
HELP_CONFIG_FILE="$USER_HOME/.help-gen-config"

source "$USER_HOME/development/scripts/parse-py.sh"
source "$USER_HOME/development/scripts/parse-js.sh"
source "$USER_HOME/development/scripts/parse-go.sh"
source "$USER_HOME/development/scripts/parse-rust.sh"
source "$USER_HOME/development/scripts/parse-java.sh"
source "$USER_HOME/development/scripts/parse-ruby.sh"
source "$USER_HOME/development/scripts/parse-php.sh"
source "$USER_HOME/development/scripts/parse-c-cpp.sh"
source "$USER_HOME/development/scripts/parse-dotnet.sh"

SHOW_EXTRA_ARGS="false"

# Default exclude patterns
DEFAULT_EXCLUDE=(
    ".venv" "venv" "env" "__pycache__" ".pytest_cache" ".mypy_cache"
    "node_modules" ".npm" ".yarn" "dist" "build" ".build"
    "target" ".target" ".gradle" ".mvn" ".idea" ".vscode"
    ".vs" ".git" ".svn" ".hg" ".bzr" ".DS_Store" "Thumbs.db"
    ".classpath" ".project" ".settings" "bin" "obj" "out"
    ".next" ".nuxt" ".cache" ".parcel-cache" ".webpack" ".serverless"
)

# Load or create help generator config
load_help_config() {
    if [ -f "$HELP_CONFIG_FILE" ]; then
        source "$HELP_CONFIG_FILE"
    else
        # Default values
        INCLUDE_PRIVATE="false"
        GENERATE_DEV_HELP="true"
        GENERATE_USER_HELP="true"
        OUTPUT_FORMAT="md"
        # Initialize exclude array from defaults
        EXCLUDE_GENERATE=("${DEFAULT_EXCLUDE[@]}")
        save_help_config
    fi
}

# Save help generator config
save_help_config() {
    echo "INCLUDE_PRIVATE=\"$INCLUDE_PRIVATE\"" > "$HELP_CONFIG_FILE"
    echo "GENERATE_DEV_HELP=\"$GENERATE_DEV_HELP\"" >> "$HELP_CONFIG_FILE"
    echo "GENERATE_USER_HELP=\"$GENERATE_USER_HELP\"" >> "$HELP_CONFIG_FILE"
    echo "OUTPUT_FORMAT=\"$OUTPUT_FORMAT\"" >> "$HELP_CONFIG_FILE"
    echo "SHOW_EXTRA_ARGS=\"$SHOW_EXTRA_ARGS\"" >> "$HELP_CONFIG_FILE"
    
    # Save exclude patterns
    echo "EXCLUDE_GENERATE=(" >> "$HELP_CONFIG_FILE"
    for pattern in "${EXCLUDE_GENERATE[@]}"; do
        echo "  \"$pattern\"" >> "$HELP_CONFIG_FILE"
    done
    echo ")" >> "$HELP_CONFIG_FILE"
}

# Check if a file should be excluded
should_exclude() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    for pattern in "${EXCLUDE_GENERATE[@]}"; do
        # Check if filename matches pattern
        if [[ "$filename" == "$pattern" ]]; then
            return 0
        fi
        
        # Check if path contains pattern
        if [[ "$file_path" == *"/$pattern/"* ]] || [[ "$file_path" == *"/$pattern" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Find files with exclude support
find_files() {
    local directory="$1"
    local extensions="$2"
    local found_files=()
    
    while IFS= read -r -d '' file; do
        if ! should_exclude "$file"; then
            found_files+=("$file")
        fi
    done < <(find "$directory" -type f \( $extensions \) -print0 2>/dev/null)
    
    printf '%s\n' "${found_files[@]}"
}



# Generate help documentation (updated with exclude-aware file finding)
generate_help() {
    local project_name="$1"
    local help_type="$2"
    
    local project_dir="$USER_HOME/projects/active/$project_name"
    local lang_file="$USER_HOME/projects/languages/${project_name}.lang"
    local docs_dir="$project_dir/docs"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}Project '$project_name' not found!${NC}"
        return 1
    fi
    
    if [ ! -f "$lang_file" ]; then
        echo -e "${RED}Language configuration not found for project '$project_name'!${NC}"
        return 1
    fi
    
    # Create docs directory if it doesn't exist
    mkdir -p "$docs_dir"
    
    local output_file="$docs_dir/${project_name}-${help_type}-help.md"
    
    # Don't overwrite existing files
    if [ -f "$output_file" ]; then
        echo -e "${YELLOW}Help file already exists: $output_file${NC}"
        echo -e "${YELLOW}Skipping generation to avoid overwriting.${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Generating $help_type help for project: $project_name${NC}"
    echo -e "${YELLOW}Excluding patterns: ${EXCLUDE_GENERATE[*]}${NC}"
    
    # Start help document
    local help_content="# $project_name - $help_type Help\n\n"
    help_content+="Generated on: $(date)\n\n"
    help_content+="Excluded patterns: ${EXCLUDE_GENERATE[*]}\n\n"
    help_content+="## Table of Contents\n\n"
    
    # Read languages from .lang file
    local languages=()
    while IFS= read -r lang; do
        languages+=("$lang")
    done < "$lang_file"
    
    # Generate language-specific sections
    for lang in "${languages[@]}"; do
        help_content+="- [${lang^} Code Documentation](#${lang}-code-documentation)\n"
    done
    help_content+="\n"
    
    # Process each language
    for lang in "${languages[@]}"; do
        help_content+="## ${lang^} Code Documentation\n\n"
        
        case $lang in
            "python")
                while IFS= read -r py_file; do
                    help_content+="### File: $(basename "$py_file")\n\n"
                    help_content+="$(parse_python_file "$py_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.py'")
                ;;
            "nodejs")
                while IFS= read -r js_file; do
                    help_content+="### File: $(basename "$js_file")\n\n"
                    help_content+="$(parse_js_file "$js_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx'")
                ;;
            "go")
                while IFS= read -r go_file; do
                    help_content+="### File: $(basename "$go_file")\n\n"
                    help_content+="$(parse_go_file "$go_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.go'")
                ;;
            "rust")
                while IFS= read -r rs_file; do
                    help_content+="### File: $(basename "$rs_file")\n\n"
                    help_content+="$(parse_rs_file "$rs_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.rs'")
                ;;
            "java")
                while IFS= read -r java_file; do
                    help_content+="### File: $(basename "$java_file")\n\n"
                    help_content+="$(parse_java_file "$java_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.java'")
                ;;
            "ruby")
                while IFS= read -r rb_file; do
                    help_content+="### File: $(basename "$rb_file")\n\n"
                    help_content+="$(parse_ruby_file "$rb_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.rb' -o -name '*.rake' -o -name 'Gemfile' -o -name '*.gemspec'")
                ;;
            "php")
                while IFS= read -r php_file; do
                    help_content+="### File: $(basename "$php_file")\n\n"
                    help_content+="$(parse_php_file "$php_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.php' -o -name '*.php5' -o -name '*.php7'")
                ;;
            "dotnet")
                while IFS= read -r cs_file; do
                    help_content+="### File: $(basename "$cs_file")\n\n"
                    help_content+="$(parse_dotnet_file "$cs_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.cs' -o -name '*.vb' -o -name '*.fs'")
                ;;
            "c_cpp")
                while IFS= read -r c_file; do
                    help_content+="### File: $(basename "$c_file")\n\n"
                    help_content+="$(parse_c_cpp_file "$c_file" "$help_type")\n"
                done < <(find_files "$project_dir" "-name '*.c' -o -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' -o -name '*.h' -o -name '*.hpp' -o -name '*.hh' -o -name '*.hxx'")
                ;;
            *)
                help_content+="*Language parser for $lang not yet implemented*\n\n"
                ;;
        esac
    done
    
    # Write to file
    echo -e "$help_content" > "$output_file"
    echo -e "${GREEN}Help documentation generated: $output_file${NC}"
    
    # Also generate a simplified version without file breakdowns if requested
    if [ "$help_type" = "user" ]; then
        generate_simplified_help "$project_name" "$help_content"
    fi
}

# Generate a simplified version without per-file breakdowns
generate_simplified_help() {
    local project_name="$1"
    local full_content="$2"
    local simplified_file="$USER_HOME/projects/active/$project_name/docs/${project_name}-user-help-simple.md"
    
    if [ -f "$simplified_file" ]; then
        return 0
    fi
    
    # Remove file-level headers and keep only the structured content
    local simplified_content=$(echo -e "$full_content" | \
        sed '/### File: /d' | \
        sed '/#### Signature:/,/#### Usage:/ { /#### Usage:/!d; }' | \
        sed 's/#### \(Signature\|Parameters\|Returns\|Description\|Usage\):/### \1:/g')
    
    echo -e "$simplified_content" > "$simplified_file"
    echo -e "${GREEN}Simplified help documentation generated: $simplified_file${NC}"
}

# Manage exclude patterns
manage_exclude_patterns() {
    while true; do
        echo -e "\n${YELLOW}=== Exclude Patterns Management ===${NC}"
        echo -e "1. List current exclude patterns"
        echo -e "2. Add exclude pattern"
        echo -e "3. Remove exclude pattern"
        echo -e "4. Reset to defaults"
        echo -e "5. Back to help config"
        echo -e "${YELLOW}====================================${NC}"
        
        read -p "Choose an option (1-5): " choice
        
        case $choice in
            1)
                echo -e "${BLUE}Current exclude patterns:${NC}"
                for i in "${!EXCLUDE_GENERATE[@]}"; do
                    echo "$((i+1)). ${EXCLUDE_GENERATE[$i]}"
                done
                ;;
            2)
                read -p "Enter pattern to exclude: " pattern
                if [ -n "$pattern" ]; then
                    EXCLUDE_GENERATE+=("$pattern")
                    save_help_config
                    echo -e "${GREEN}Pattern added: $pattern${NC}"
                fi
                ;;
            3)
                echo -e "${BLUE}Current exclude patterns:${NC}"
                for i in "${!EXCLUDE_GENERATE[@]}"; do
                    echo "$((i+1)). ${EXCLUDE_GENERATE[$i]}"
                done
                read -p "Enter number to remove: " num
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#EXCLUDE_GENERATE[@]}" ]; then
                    local removed="${EXCLUDE_GENERATE[$((num-1))]}"
                    unset "EXCLUDE_GENERATE[$((num-1))]"
                    EXCLUDE_GENERATE=("${EXCLUDE_GENERATE[@]}")  # Reindex array
                    save_help_config
                    echo -e "${GREEN}Pattern removed: $removed${NC}"
                else
                    echo -e "${RED}Invalid selection!${NC}"
                fi
                ;;
            4)
                EXCLUDE_GENERATE=("${DEFAULT_EXCLUDE[@]}")
                save_help_config
                echo -e "${GREEN}Exclude patterns reset to defaults${NC}"
                ;;
            5) break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Configuration menu for help generator (updated with exclude management)
configure_help_gen() {
    load_help_config
    
    while true; do
        echo -e "\n${YELLOW}=== Help Generator Configuration ===${NC}"
        echo -e "1. Include private members: $INCLUDE_PRIVATE"
        echo -e "2. Generate developer help: $GENERATE_DEV_HELP"
        echo -e "3. Generate user help: $GENERATE_USER_HELP"
        echo -e "4. Output format: $OUTPUT_FORMAT"
        echo -e "5. Show extra arguments: $SHOW_EXTRA_ARGS"
        echo -e "6. Manage exclude patterns"
        echo -e "7. Generate help for project"
        echo -e "8. Back to main menu"
        echo -e "${YELLOW}=====================================${NC}"
        
        read -p "Choose an option (1-7): " choice
        
        case $choice in
            1)
                if [ "$INCLUDE_PRIVATE" = "true" ]; then
                    INCLUDE_PRIVATE="false"
                else
                    INCLUDE_PRIVATE="true"
                fi
                save_help_config
                ;;
            2)
                if [ "$GENERATE_DEV_HELP" = "true" ]; then
                    GENERATE_DEV_HELP="false"
                else
                    GENERATE_DEV_HELP="true"
                fi
                save_help_config
                ;;
            3)
                if [ "$GENERATE_USER_HELP" = "true" ]; then
                    GENERATE_USER_HELP="false"
                else
                    GENERATE_USER_HELP="true"
                fi
                save_help_config
                ;;
            4)
                echo -e "Available formats: md, txt, html"
                read -p "Enter output format: " format
                if [[ "$format" =~ ^(md|txt|html)$ ]]; then
                    OUTPUT_FORMAT="$format"
                    save_help_config
                else
                    echo -e "${RED}Invalid format!${NC}"
                fi
                ;;
            5)
                if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                    SHOW_EXTRA_ARGS="false"
                else
                    SHOW_EXTRA_ARGS="true"
                fi
                save_help_config
                ;;
            6) manage_exclude_patterns ;;
            7)
                list_projects
                read -p "Enter project name: " project_name
                read -p "Generate for (dev/user/both): " help_type
                
                case $help_type in
                    "dev") generate_help "$project_name" "dev" ;;
                    "user") generate_help "$project_name" "user" ;;
                    "both")
                        generate_help "$project_name" "dev"
                        generate_help "$project_name" "user"
                        ;;
                    *) echo -e "${RED}Invalid choice!${NC}" ;;
                esac
                ;;
            8) break ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_help_config
    configure_help_gen
fi
