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


# Helper function to extract docstrings
extract_docstring() {
    local file_path="$1"
    local trigger_line="$2"
    local docstring=""
    local in_docstring=false
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Read next lines to find docstring
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\"\"\" ]]; then
            if [ "$in_docstring" = true ]; then
                break
            else
                in_docstring=true
                continue
            fi
        fi
        if [ "$in_docstring" = true ]; then
            docstring+="${line#*#} "
        fi
    done < <(tail -n +$((line_num + 1)) "$file_path")
    
    echo "$docstring" | xargs
}

# Parse Python files
parse_python_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing Python file: $file_path${NC}"
    
    local current_class=""
    local class_methods=()
    
    while IFS= read -r line; do
        # Class detection
        if [[ "$line" =~ ^class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local class_name="${BASH_REMATCH[1]}"
            current_class="$class_name"
            class_methods=()
            output+="## Class: \`$class_name\`\n\n"
            
            # Look for class docstring
            local class_docstring=$(extract_docstring "$file_path" "$line")
            if [ -n "$class_docstring" ]; then
                output+="#### Description:\n> $class_docstring\n\n"
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Method detection
        if [[ "$line" =~ ^[[:space:]]*def[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local method_name="${BASH_REMATCH[1]}"
            
            # Skip private methods for user help
            if [ "$help_type" = "user" ] && [[ $method_name =~ ^_ ]]; then
                continue
            fi
            
            class_methods+=("$method_name")
            
            output+="### Method: \`$method_name\`\n\n"
            
            # Extract method signature
            if [[ "$line" =~ def[[:space:]]+$method_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                output+="#### Signature:\n\`\`\`python\ndef $method_name($params)\n\`\`\`\n\n"
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                    output+="#### Arguments:\n"
                    IFS=',' read -ra param_list <<< "$params"
                    for param in "${param_list[@]}"; do
                        param=$(echo "$param" | xargs)
                        if [[ $param =~ = ]]; then
                            local p_name=$(echo "$param" | cut -d'=' -f1 | xargs)
                            local p_default=$(echo "$param" | cut -d'=' -f2 | xargs)
                            output+="- $p_name: * = $p_default\n"
                        else
                            output+="- $param: *\n"
                        fi
                    done
                    output+="\n"
                fi
            fi
            
            # Look for method docstring
            local method_docstring=$(extract_docstring "$file_path" "$line")
            if [ -n "$method_docstring" ]; then
                output+="#### Help:\n> $method_docstring\n\n"
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`python"
            if [ -n "$current_class" ]; then
                output+="\nobj = ${current_class}()"
                output+="\nobj.${method_name}("
            else
                output+="\n${method_name}("
            fi
            output+="\n    # parameters here"
            output+="\n)\n\`\`\`\n\n"
            
            # Navigation links
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
    done < "$file_path"
    
    # Add class methods summary if we found a class
    if [ -n "$current_class" ] && [ ${#class_methods[@]} -gt 0 ]; then
        local methods_links=""
        for method in "${class_methods[@]}"; do
            methods_links+="[\`$method\`](#method-$method) | "
        done
        methods_links=${methods_links% | }  # Remove trailing separator
        
        # Insert methods summary after class header
        output=$(echo "$output" | sed "s/## Class: \`$current_class\`/## Class: \`$current_class\`\n\n**Methods**: ${methods_links}\n/")
    fi
    
    echo -e "$output"
}
