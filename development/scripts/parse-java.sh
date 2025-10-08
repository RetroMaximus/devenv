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

# Configuration
CONFIG_FILE="$USER_HOME/.dev-env-config"
source "$CONFIG_FILE"

# Helper function to extract Javadoc comments
extract_javadoc() {
    local file_path="$1"
    local trigger_line="$2"
    local javadoc=""
    local params=()
    local returns=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for Javadoc comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*// ]] && [[ ! $prev_line =~ ^[[:space:]]*/\* ]]; then
            break
        fi
        
        # If we find the end of a Javadoc comment, process it
        if [[ $prev_line =~ \*/ ]]; then
            local in_javadoc=true
            continue
        fi
        
        if [ "$in_javadoc" = true ]; then
            if [[ $prev_line =~ /\*\* ]]; then
                break
            fi
            
            # Extract @param tags
            if [[ $prev_line =~ @param[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+(.+) ]]; then
                params+=("${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}")
            fi
            
            # Extract @return tag
            if [[ $prev_line =~ @return[[:space:]]+(.+) ]]; then
                returns="${BASH_REMATCH[1]}"
            fi
            
            # Extract regular description
            if [[ ! $prev_line =~ @ ]] && [[ $prev_line =~ \*[[:space:]]*(.+) ]]; then
                javadoc="${BASH_REMATCH[1]}\n$javadoc"
            fi
        fi
    done
    
    # Return structured data
    echo -e "DESCRIPTION:$javadoc"
    echo "PARAMS:${params[*]}"
    echo "RETURNS:$returns"
}

# Parse Java files
parse_java_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing Java file: $file_path${NC}"
    
    local current_class=""
    local current_interface=""
    local class_methods=()
    local in_javadoc=false
    local current_javadoc=""
    local javadoc_params=()
    local javadoc_returns=""
    
    while IFS= read -r line; do
        # Handle Javadoc comments
        if [[ $line =~ ^[[:space:]]*/\*\* ]]; then
            in_javadoc=true
            current_javadoc=""
            javadoc_params=()
            javadoc_returns=""
            continue
        fi
        
        if [ "$in_javadoc" = true ]; then
            if [[ $line =~ \*/ ]]; then
                in_javadoc=false
                continue
            fi
            
            # Extract @param tags
            if [[ $line =~ @param[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+(.+) ]]; then
                local p_name="${BASH_REMATCH[1]}"
                local p_desc="${BASH_REMATCH[2]}"
                javadoc_params+=("$p_name: $p_desc")
            fi
            
            # Extract @return tag
            if [[ $line =~ @return[[:space:]]+(.+) ]]; then
                javadoc_returns="${BASH_REMATCH[1]}"
            fi
            
            # Extract regular description (not tags)
            if [[ ! $line =~ @ ]] && [[ $line =~ \*[[:space:]]*(.+) ]]; then
                current_javadoc+="${BASH_REMATCH[1]} "
            fi
            
            continue
        fi
        
        # Class detection
        if [[ $line =~ ^[[:space:]]*public[[:space:]]+class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local class_name="${BASH_REMATCH[1]}"
            current_class="$class_name"
            current_interface=""
            class_methods=()
            output+="## Class: \`$class_name\`\n\n"
            
            if [ -n "$current_javadoc" ]; then
                output+="#### Description:\n> $current_javadoc\n\n"
                current_javadoc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Interface detection
        if [[ $line =~ ^[[:space:]]*public[[:space:]]+interface[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*interface[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local interface_name="${BASH_REMATCH[1]}"
            current_interface="$interface_name"
            current_class=""
            class_methods=()
            output+="## Interface: \`$interface_name\`\n\n"
            
            if [ -n "$current_javadoc" ]; then
                output+="#### Description:\n> $current_javadoc\n\n"
                current_javadoc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Method detection
        if [[ $line =~ ^[[:space:]]*(public|protected|private)[[:space:]]+([^[:space:]]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(([^)]*)\) ]] || 
           [[ $line =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(([^)]*)\) ]]; then
            local modifier=""
            local return_type=""
            local method_name=""
            local params=""
            
            if [[ $line =~ (public|protected|private) ]]; then
                modifier="${BASH_REMATCH[1]}"
                return_type="${BASH_REMATCH[2]}"
                method_name="${BASH_REMATCH[3]}"
                params="${BASH_REMATCH[4]}"
            else
                method_name="${BASH_REMATCH[1]}"
                params="${BASH_REMATCH[2]}"
                return_type="void"
            fi
            
            # Skip private methods for user help
            if [ "$help_type" = "user" ] && [[ $modifier == "private" ]]; then
                current_javadoc=""
                continue
            fi
            
            # Skip constructors for method listing
            if [[ $method_name == "$current_class" ]]; then
                current_javadoc=""
                continue
            fi
            
            if [ -n "$current_class" ] || [ -n "$current_interface" ]; then
                class_methods+=("$method_name")
                if [ -n "$current_class" ]; then
                    output+="### Method: \`$method_name\`\n\n"
                else
                    output+="### Interface Method: \`$method_name\`\n\n"
                fi
            else
                output+="## Method: \`$method_name\`\n\n"
            fi
            
            # Build full signature
            local full_signature=""
            if [ -n "$modifier" ]; then
                full_signature+="$modifier "
            fi
            if [[ $return_type != "void" ]] && [[ ! $line =~ constructor ]]; then
                full_signature+="$return_type "
            fi
            full_signature+="$method_name($params)"
            
            output+="#### Signature:\n\`\`\`java\n$full_signature\n\`\`\`\n\n"
            
            # Parse parameters if enabled
            if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                output+="#### Parameters:\n"
                # Clean Java parameter syntax
                local clean_params=$(echo "$params" | sed 's/final //g')
                IFS=',' read -ra param_list <<< "$clean_params"
                for param in "${param_list[@]}"; do
                    param=$(echo "$param" | xargs)
                    # Handle Java parameter syntax: Type name
                    if [[ $param =~ [[:space:]] ]]; then
                        local p_type=$(echo "$param" | awk '{print $1}')
                        local p_name=$(echo "$param" | awk '{print $2}')
                        # Look for Javadoc description
                        local p_desc=""
                        for javadoc_param in "${javadoc_params[@]}"; do
                            if [[ $javadoc_param =~ ^$p_name: ]]; then
                                p_desc=" - ${javadoc_param#*:}"
                                break
                            fi
                        done
                        output+="- $p_name: $p_type$p_desc\n"
                    else
                        output+="- $param: _\n"
                    fi
                done
                output+="\n"
            fi
            
            # Add return type info
            if [[ $return_type != "void" ]] && [[ ! $line =~ constructor ]]; then
                output+="#### Returns:\n\`$return_type\`"
                if [ -n "$javadoc_returns" ]; then
                    output+=" - $javadoc_returns"
                fi
                output+="\n\n"
            fi
            
            # Add Javadoc comments
            if [ -n "$current_javadoc" ]; then
                output+="#### Description:\n> $current_javadoc\n\n"
                current_javadoc=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`java"
            if [ -n "$current_class" ]; then
                output+="\n${current_class} instance = new ${current_class}();"
                output+="\ninstance.${method_name}("
            else
                output+="\n${method_name}("
            fi
            output+="\n    // parameters here"
            output+="\n);\n\`\`\`\n\n"
            
            # Navigation links
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            elif [ -n "$current_interface" ]; then
                output+="[Back to ${current_interface}](#interface-${current_interface}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
            
            # Reset Javadoc variables
            javadoc_params=()
            javadoc_returns=""
        fi
        
        # Field detection (class variables)
        if [[ $line =~ ^[[:space:]]*(public|protected|private)[[:space:]]+([^[:space:]]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*[=;] ]] && 
           [ -n "$current_class" ]; then
            local modifier="${BASH_REMATCH[1]}"
            local field_type="${BASH_REMATCH[2]}"
            local field_name="${BASH_REMATCH[3]}"
            
            # Skip private fields for user help
            if [ "$help_type" = "user" ] && [[ $modifier == "private" ]]; then
                current_javadoc=""
                continue
            fi
            
            output+="#### Field: \`$field_name\`\n\n"
            output+="**Type**: \`$field_type\`\n\n"
            
            if [ -n "$current_javadoc" ]; then
                output+="**Description**: $current_javadoc\n\n"
                current_javadoc=""
            fi
            
            output+="[Back to ${current_class}](#class-${current_class}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Reset current_javadoc if we're not in a comment and hit a significant line
        if [[ ! $line =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^[[:space:]]*/\* ]] && 
           [[ $line =~ [a-zA-Z] ]] && [ -n "$current_javadoc" ] && [ "$in_javadoc" = false ]; then
            current_javadoc=""
        fi
        
    done < "$file_path"
    
    # Add class methods summary if we found a class with methods
    if [ -n "$current_class" ] && [ ${#class_methods[@]} -gt 0 ]; then
        local methods_links=""
        for method in "${class_methods[@]}"; do
            methods_links+="[\`$method\`](#method-$method) | "
        done
        methods_links=${methods_links% | }  # Remove trailing separator
        
        # Insert methods summary after class header
        if [ -n "$current_class" ]; then
            output=$(echo "$output" | sed "s/## Class: \`$current_class\`/## Class: \`$current_class\`\n\n**Methods**: ${methods_links}\n/")
        elif [ -n "$current_interface" ]; then
            output=$(echo "$output" | sed "s/## Interface: \`$current_interface\`/## Interface: \`$current_interface\`\n\n**Methods**: ${methods_links}\n/")
        fi
    fi
    
    echo -e "$output"
}

