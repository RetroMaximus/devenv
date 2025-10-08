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

# Parse Ruby files
parse_ruby_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing Ruby file: $file_path${NC}"
    
    local current_class=""
    local current_module=""
    local class_methods=()
    local in_comment_block=false
    local current_comment=""
    
    while IFS= read -r line; do
        # Handle multi-line comments
        if echo "$line" | grep -q '^=begin'; then
            in_comment_block=true
            current_comment=""
            continue
        fi
        
        if [ "$in_comment_block" = true ]; then
            if [[ "$line" =~ ^=end ]]; then
                in_comment_block=false
            else
                current_comment+=""$line"\n"
            fi
            continue
        fi
        
        # Single line comments
        if [[ "$line" =~ ^[[:space:]]*# ]] && [ -z "$current_comment" ]; then
            current_comment="${line#*#}"
            current_comment=$(echo "$current_comment" | xargs)
        fi
        
        # Class detection
        if [[ "$line" =~ ^[[:space:]]*class[[:space:]]+([A-Z][a-zA-Z0-9_:]*) ]]; then
            local class_name="${BASH_REMATCH[1]}"
            current_class="$class_name"
            current_module=""
            class_methods=()
            output+="## Class: \`$class_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Module detection
        if [[ "$line" =~ ^[[:space:]]*module[[:space:]]+([A-Z][a-zA-Z0-9_:]*) ]]; then
            local module_name="${BASH_REMATCH[1]}"
            current_module="$module_name"
            current_class=""
            output+="## Module: \`$module_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Method detection (instance methods)
        if [[ "$line" =~ ^[[:space:]]*def[[:space:]]+([a-z_][a-zA-Z0-9_?!]*) ]]; then
            local method_name="${BASH_REMATCH[1]}"
            
            # Skip private methods for user help (Ruby convention: _prefix)
            if [ "$help_type" = "user" ] && [[ $method_name =~ ^_ ]]; then
                current_comment=""
                continue
            fi
            
            if [ -n "$current_class" ] || [ -n "$current_module" ]; then
                class_methods+=("$method_name")
                output+="### Method: \`$method_name\`\n\n"
            else
                output+="## Method: \`$method_name\`\n\n"
            fi
            
            # Extract method signature
            if [[ "$line" =~ def[[:space:]]+$method_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                output+="#### Signature:\n\`\`\`ruby\ndef $method_name($params)\n\`\`\`\n\n"
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ] && [ -n "$params" ]; then
                    output+="#### Parameters:\n"
                    # Clean Ruby parameter syntax
                    local clean_params=$(echo "$params" | sed 's/\\//g; s/\*//g')
                    IFS=',' read -ra param_list <<< "$clean_params"
                    for param in "${param_list[@]}"; do
                        param=$(echo "$param" | xargs)
                        # Handle Ruby parameter syntax with defaults
                        if [[ $param =~ = ]]; then
                            local p_name=$(echo "$param" | cut -d'=' -f1 | xargs)
                            local p_default=$(echo "$param" | cut -d'=' -f2 | xargs)
                            output+="- $p_name: * = $p_default\n"
                        # Handle splat args
                        elif [[ $param =~ ^\* ]]; then
                            local p_name="${param:1}"
                            output+="- $p_name: Array\n"
                        # Handle block args
                        elif [[ $param =~ & ]]; then
                            local p_name=$(echo "$param" | sed 's/&//')
                            output+="- $p_name: Block\n"
                        else
                            output+="- $param: Object\n"
                        fi
                    done
                    output+="\n"
                fi
            else
                # Method without parentheses
                output+="#### Signature:\n\`\`\`ruby\ndef $method_name\n\`\`\`\n\n"
            fi
            
            # Add Ruby comments
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`ruby"
            if [ -n "$current_class" ]; then
                output+="\ninstance = ${current_class}.new"
                output+="\ninstance.${method_name}("
            elif [ -n "$current_module" ]; then
                output+="\ninclude ${current_module}"
                output+="\n${method_name}("
            else
                output+="\n${method_name}("
            fi
            
            if [ -n "$params" ]; then
                output+="\n    # parameters here"
                output+="\n)"
            else
                output+=")"
            fi
            output+="\n\`\`\`\n\n"
            
            # Navigation links
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            elif [ -n "$current_module" ]; then
                output+="[Back to ${current_module}](#module-${current_module}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Class method detection (self.method)
        if [[ "$line" =~ ^[[:space:]]*def[[:space:]]+self\.([a-z_][a-zA-Z0-9_?!]*) ]]; then
            local method_name="${BASH_REMATCH[1]}"
            
            # Skip private methods for user help
            if [ "$help_type" = "user" ] && [[ $method_name =~ ^_ ]]; then
                current_comment=""
                continue
            fi
            
            if [ -n "$current_class" ] || [ -n "$current_module" ]; then
                class_methods+=("self.$method_name")
                output+="### Class Method: \`$method_name\`\n\n"
            else
                output+="## Class Method: \`$method_name\`\n\n"
            fi
            
            # Extract method signature
            if [[ "$line" =~ def[[:space:]]+self\.$method_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                output+="#### Signature:\n\`\`\`ruby\ndef self.$method_name($params)\n\`\`\`\n\n"
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ] && [ -n "$params" ]; then
                    output+="#### Parameters:\n"
                    IFS=',' read -ra param_list <<< "$params"
                    for param in "${param_list[@]}"; do
                        param=$(echo "$param" | xargs)
                        if [[ $param =~ = ]]; then
                            local p_name=$(echo "$param" | cut -d'=' -f1 | xargs)
                            local p_default=$(echo "$param" | cut -d'=' -f2 | xargs)
                            output+="- $p_name: * = $p_default\n"
                        else
                            output+="- $param: Object\n"
                        fi
                    done
                    output+="\n"
                fi
            fi
            
            # Add Ruby comments
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`ruby"
            if [ -n "$current_class" ]; then
                output+="\n${current_class}.${method_name}("
            elif [ -n "$current_module" ]; then
                output+="\n${current_module}.${method_name}("
            else
                output+="\n${method_name}("
            fi
            
            if [ -n "$params" ]; then
                output+="\n    # parameters here"
                output+="\n)"
            else
                output+=")"
            fi
            output+="\n\`\`\`\n\n"
            
            # Navigation links
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            elif [ -n "$current_module" ]; then
                output+="[Back to ${current_module}](#module-${current_module}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Attribute accessors
        if [[ "$line" =~ ^[[:space:]]*(attr_reader|attr_writer|attr_accessor)[[:space:]]+([a-z_][a-zA-Z0-9_?!]*) ]]; then
            local attr_type="${BASH_REMATCH[1]}"
            local attr_name="${BASH_REMATCH[2]}"
            
            output+="#### Attribute: \`$attr_name\`\n\n"
            output+="**Type**: $attr_type\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            elif [ -n "$current_module" ]; then
                output+="[Back to ${current_module}](#module-${current_module}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Constant detection
        if [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*= ]]; then
            local const_name=$(echo "$line" | awk -F'=' '{print $1}' | xargs)
            local const_value=$(echo "$line" | awk -F'=' '{print $2}' | xargs)
            
            output+="#### Constant: \`$const_name\`\n\n"
            output+="**Value**: \`$const_value\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            elif [ -n "$current_module" ]; then
                output+="[Back to ${current_module}](#module-${current_module}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Reset current_comment if we hit a significant non-comment line
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^=begin ]] && [[ ! "$line" =~ ^=end ]] &&
           [[ "$line" =~ [a-zA-Z] ]] && [ -n "$current_comment" ] && [ "$in_comment_block" = false ]; then
            current_comment=""
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
        elif [ -n "$current_module" ]; then
            output=$(echo "$output" | sed "s/## Module: \`$current_module\`/## Module: \`$current_module\`\n\n**Methods**: ${methods_links}\n/")
        fi
    fi
    
    echo -e "$output"
}

# Helper function to extract Ruby comments
extract_ruby_comment() {
    local file_path="$1"
    local trigger_line="$2"
    local comment=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*# ]] && [[ ! $prev_line =~ ^=begin ]]; then
            break
        fi
        
        # Skip comment block markers
        if [[ $prev_line =~ ^=begin ]] || [[ $prev_line =~ ^=end ]]; then
            continue
        fi
        
        # Add to comment (in reverse order)
        local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*#[[:space:]]*//')
        comment="$clean_line\n$comment"
    done
    
    echo -e "$comment" | xargs
}
