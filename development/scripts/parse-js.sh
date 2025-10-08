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


# Helper function to extract JSDoc comments
extract_jsdoc() {
    local file_path="$1"
    local trigger_line="$2"
    local jsdoc=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for JSDoc comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # If we find the end of a JSDoc comment, start capturing
        if [[ $prev_line =~ ^[[:space:]]*\*/ ]]; then
            local in_jsdoc=true
            continue
        fi
        
        # If we're in a JSDoc and find the start, we're done
        if [ "$in_jsdoc" = true ] && [[ $prev_line =~ ^[[:space:]]*/\*\* ]]; then
            break
        fi
        
        # Capture JSDoc content
        if [ "$in_jsdoc" = true ]; then
            # Remove leading * and spaces
            local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*\*[[:space:]]*//')
            jsdoc="$clean_line\n$jsdoc"
        fi
    done
    
    echo -e "$jsdoc" | xargs
}

# Parse JavaScript/Node.js files
parse_js_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing JavaScript file: $file_path${NC}"
    
    local current_class=""
    local class_methods=()
    
    while IFS= read -r line; do
        # Function detection
        if [[ "$line" =~ function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local func_name="${BASH_REMATCH[1]}"
            
            # Skip private functions for user help
            if [ "$help_type" = "user" ] && [[ $func_name =~ ^_ ]]; then
                continue
            fi
            
            output+="## Function: \`$func_name\`\n\n"
            
            # Extract function signature
            if [[ "$line" =~ function[[:space:]]+$func_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                output+="#### Signature:\n\`\`\`javascript\nfunction $func_name($params)\n\`\`\`\n\n"
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                    output+="#### Parameters:\n"
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
            
            # Look for JSDoc comments
            local jsdoc=$(extract_jsdoc "$file_path" "$line")
            if [ -n "$jsdoc" ]; then
                output+="#### Description:\n> $jsdoc\n\n"
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`javascript\n${func_name}("
            output+="\n    // parameters here"
            output+="\n);\n\`\`\`\n\n"
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Class detection (ES6)
        if [[ "$line" =~ ^class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local class_name="${BASH_REMATCH[1]}"
            current_class="$class_name"
            class_methods=()
            output+="## Class: \`$class_name\`\n\n"
            
            # Look for class JSDoc
            local class_jsdoc=$(extract_jsdoc "$file_path" "$line")
            if [ -n "$class_jsdoc" ]; then
                output+="#### Description:\n> $class_jsdoc\n\n"
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Method detection (ES6 class methods)
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\([^)]*\)[[:space:]]*\{ ]] && [[ -n "$current_class" ]]; then
            local method_name="${BASH_REMATCH[1]}"
            local params="${BASH_REMATCH[2]}"
            
            # Skip private methods for user help
            if [ "$help_type" = "user" ] && [[ $method_name =~ ^_ ]]; then
                continue
            fi
            
            class_methods+=("$method_name")
            
            output+="### Method: \`$method_name\`\n\n"
            output+="#### Signature:\n\`\`\`javascript\n$method_name($params)\n\`\`\`\n\n"
            
            # Parse parameters if enabled
            if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                output+="#### Parameters:\n"
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
            
            # Look for method JSDoc
            local method_jsdoc=$(extract_jsdoc "$file_path" "$line")
            if [ -n "$method_jsdoc" ]; then
                output+="#### Description:\n> $method_jsdoc\n\n"
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`javascript\nconst instance = new ${current_class}();"
            output+="\ninstance.${method_name}("
            output+="\n    // parameters here"
            output+="\n);\n\`\`\`\n\n"
            
            output+="[Back to ${current_class}](#class-${current_class}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Arrow function detection
        if [[ "$line" =~ ^[[:space:]]*(const|let|var)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*\((.*)\)[[:space:]]*=> ]]; then
            local func_name="${BASH_REMATCH[2]}"
            local params="${BASH_REMATCH[3]}"
            
            # Skip private functions for user help
            if [ "$help_type" = "user" ] && [[ $func_name =~ ^_ ]]; then
                continue
            fi
            
            output+="## Function: \`$func_name\`\n\n"
            output+="#### Signature:\n\`\`\`javascript\nconst $func_name = ($params) => { /* ... */ }\n\`\`\`\n\n"
            
            # Parse parameters if enabled
            if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                output+="#### Parameters:\n"
                IFS=',' read -ra param_list <<< "$params"
                for param in "${param_list[@]}"; do
                    param=$(echo "$param" | xargs)
                    output+="- $param: *\n"
                done
                output+="\n"
            fi
            
            # Look for JSDoc comments
            local jsdoc=$(extract_jsdoc "$file_path" "$line")
            if [ -n "$jsdoc" ]; then
                output+="#### Description:\n> $jsdoc\n\n"
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`javascript\n${func_name}("
            output+="\n    // parameters here"
            output+="\n);\n\`\`\`\n\n"
            
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
