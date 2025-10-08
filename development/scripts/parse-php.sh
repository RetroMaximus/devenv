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

# Parse PHP files
parse_php_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing PHP file: $file_path${NC}"
    
    local current_class=""
    local current_interface=""
    local current_trait=""
    local class_methods=()
    local in_doc_comment=false
    local current_doc=""
    local doc_params=()
    local doc_returns=""
    
    while IFS= read -r line; do
        # Handle docblock comments
        if [[ $line =~ ^[[:space:]]*/\*\* ]]; then
            in_doc_comment=true
            current_doc=""
            doc_params=()
            doc_returns=""
            continue
        fi
        
        if [ "$in_doc_comment" = true ]; then
            if [[ $line =~ \*/ ]]; then
                in_doc_comment=false
                continue
            fi
            
            # Extract @param tags
            if [[ $line =~ @param[[:space:]]+([^[:space:]]+)[[:space:]]+(\$[a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*(.*) ]]; then
                local p_type="${BASH_REMATCH[1]}"
                local p_name="${BASH_REMATCH[2]}"
                local p_desc="${BASH_REMATCH[3]}"
                doc_params+=("$p_name: $p_type - $p_desc")
            fi
            
            # Extract @return tag
            if [[ $line =~ @return[[:space:]]+([^[:space:]]+)[[:space:]]*(.*) ]]; then
                doc_returns="${BASH_REMATCH[1]}"
                if [ -n "${BASH_REMATCH[2]}" ]; then
                    doc_returns+=" - ${BASH_REMATCH[2]}"
                fi
            fi
            
            # Extract description (not tags)
            if [[ ! $line =~ @ ]] && [[ $line =~ \*[[:space:]]*(.+) ]]; then
                current_doc+="${BASH_REMATCH[1]} "
            fi
            
            continue
        fi
        
        # Class detection
        if [[ $line =~ ^[[:space:]]*(abstract[[:space:]]+)?class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local class_name="${BASH_REMATCH[2]}"
            current_class="$class_name"
            current_interface=""
            current_trait=""
            class_methods=()
            output+="## Class: \`$class_name\`\n\n"
            
            if [[ $line =~ abstract ]]; then
                output+="**Abstract class**\n\n"
            fi
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Interface detection
        if [[ $line =~ ^[[:space:]]*interface[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local interface_name="${BASH_REMATCH[1]}"
            current_interface="$interface_name"
            current_class=""
            current_trait=""
            output+="## Interface: \`$interface_name\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Trait detection
        if [[ $line =~ ^[[:space:]]*trait[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local trait_name="${BASH_REMATCH[1]}"
            current_trait="$trait_name"
            current_class=""
            current_interface=""
            output+="## Trait: \`$trait_name\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Function/Method detection
        if [[ $line =~ ^[[:space:]]*(public|protected|private|static|abstract|final)[[:space:]]*]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local modifiers=""
            local method_name=""
            
            if [[ $line =~ (public|protected|private|static|abstract|final) ]]; then
                modifiers="${BASH_REMATCH[1]}"
                method_name="${BASH_REMATCH[2]}"
            else
                method_name="${BASH_REMATCH[1]}"
                modifiers="public"
            fi
            
            # Skip private methods for user help
            if [ "$help_type" = "user" ] && [[ $modifiers =~ private ]]; then
                current_doc=""
                doc_params=()
                doc_returns=""
                continue
            fi
            
            if [ -n "$current_class" ] || [ -n "$current_interface" ] || [ -n "$current_trait" ]; then
                class_methods+=("$method_name")
                output+="### Method: \`$method_name\`\n\n"
            else
                output+="## Function: \`$method_name\`\n\n"
            fi
            
            # Extract method signature
            if [[ $line =~ function[[:space:]]+$method_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                local signature=""
                
                if [ -n "$modifiers" ]; then
                    signature+="$modifiers "
                fi
                signature+="function $method_name($params)"
                
                output+="#### Signature:\n\`\`\`php\n$signature\n\`\`\`\n\n"
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ] && [ -n "$params" ]; then
                    output+="#### Parameters:\n"
                    # Clean PHP parameter syntax
                    local clean_params=$(echo "$params" | sed 's/&//g; s/\.\.\.//g')
                    IFS=',' read -ra param_list <<< "$clean_params"
                    for param in "${param_list[@]}"; do
                        param=$(echo "$param" | xargs)
                        # Handle PHP 7+ type hints: Type $name
                        if [[ $param =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]+(\$[a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                            local p_type="${BASH_REMATCH[1]}"
                            local p_name="${BASH_REMATCH[2]}"
                            # Look for docblock description
                            local p_desc=""
                            for doc_param in "${doc_params[@]}"; do
                                if [[ $doc_param =~ ^$p_name: ]]; then
                                    p_desc=" - ${doc_param#*:}"
                                    break
                                fi
                            done
                            output+="- $p_name: $p_type$p_desc\n"
                        # Handle parameters with defaults
                        elif [[ $param =~ = ]]; then
                            local p_name=$(echo "$param" | cut -d'=' -f1 | xargs)
                            local p_default=$(echo "$param" | cut -d'=' -f2 | xargs)
                            output+="- $p_name: * = $p_default\n"
                        else
                            output+="- $param: mixed\n"
                        fi
                    done
                    output+="\n"
                fi
            fi
            
            # Add return type info if available
            if [ -n "$doc_returns" ]; then
                output+="#### Returns:\n\`$doc_returns\`\n\n"
            fi
            
            # Add PHP doc comments
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`php"
            if [ -n "$current_class" ]; then
                output+="\n\$instance = new ${current_class}();"
                output+="\n\$instance->${method_name}("
            elif [ -n "$current_interface" ] || [ -n "$current_trait" ]; then
                output+="\n// Interface/Trait method - must be implemented"
                output+="\n\$object->${method_name}("
            else
                output+="\n${method_name}("
            fi
            
            if [ -n "$params" ] && [[ "$params" != "" ]]; then
                output+="\n    // parameters here"
                output+="\n);"
            else
                output+=");"
            fi
            output+="\n\`\`\`\n\n"
            
            # Navigation links
            if [ -n "$current_class" ]; then
                output+="[Back to ${current_class}](#class-${current_class}) | "
            elif [ -n "$current_interface" ]; then
                output+="[Back to ${current_interface}](#interface-${current_interface}) | "
            elif [ -n "$current_trait" ]; then
                output+="[Back to ${current_trait}](#trait-${current_trait}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
            
            # Reset doc variables
            doc_params=()
            doc_returns=""
        fi
        
        # Property detection (class variables)
        if [[ $line =~ ^[[:space:]]*(public|protected|private|static|var)[[:space:]]+(\$[a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*[=;] ]] && 
           [ -n "$current_class" ]; then
            local modifier="${BASH_REMATCH[1]}"
            local property_name="${BASH_REMATCH[2]}"
            
            # Skip private properties for user help
            if [ "$help_type" = "user" ] && [[ $modifier =~ private ]]; then
                current_doc=""
                continue
            fi
            
            # Extract type from docblock if available
            local property_type="mixed"
            for doc_param in "${doc_params[@]}"; do
                if [[ $doc_param =~ @var ]]; then
                    property_type=$(echo "$doc_param" | awk '{print $2}')
                    break
                fi
            done
            
            output+="#### Property: \`$property_name\`\n\n"
            output+="**Visibility**: $modifier\n"
            output+="**Type**: \`$property_type\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="**Description**: $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to ${current_class}](#class-${current_class}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Constant detection (class constants)
        if [[ $line =~ ^[[:space:]]*const[[:space:]]+([A-Z_][A-Z0-9_]*)[[:space:]]*= ]] && 
           [ -n "$current_class" ]; then
            local const_name="${BASH_REMATCH[1]}"
            local const_value=$(echo "$line" | awk -F'=' '{print $2}' | sed 's/;[[:space:]]*$//' | xargs)
            
            output+="#### Constant: \`$const_name\`\n\n"
            output+="**Value**: \`$const_value\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="**Description**: $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to ${current_class}](#class-${current_class}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Global constant detection
        if [[ $line =~ ^[[:space:]]*define[[:space:]]*\([[:space:]]*['\"]([A-Z_][A-Z0-9_]*)['\"] ]]; then
            local const_name="${BASH_REMATCH[1]}"
            output+="## Constant: \`$const_name\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Reset current_doc if we hit a significant non-comment line
        if [[ ! $line =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^[[:space:]]*/\* ]] && 
           [[ $line =~ [a-zA-Z] ]] && [ -n "$current_doc" ] && [ "$in_doc_comment" = false ]; then
            current_doc=""
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
        elif [ -n "$current_trait" ]; then
            output=$(echo "$output" | sed "s/## Trait: \`$current_trait\`/## Trait: \`$current_trait\`\n\n**Methods**: ${methods_links}\n/")
        fi
    fi
    
    echo -e "$output"
}

# Helper function to extract PHP docblock comments
extract_phpdoc() {
    local file_path="$1"
    local trigger_line="$2"
    local phpdoc=""
    local params=()
    local returns=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for docblock comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*// ]] && [[ ! $prev_line =~ ^[[:space:]]*/\* ]]; then
            break
        fi
        
        # If we find the end of a docblock, process it
        if [[ $prev_line =~ \*/ ]]; then
            local in_docblock=true
            continue
        fi
        
        if [ "$in_docblock" = true ]; then
            if [[ $prev_line =~ /\*\* ]]; then
                break
            fi
            
            # Extract @param tags
            if [[ $prev_line =~ @param[[:space:]]+([^[:space:]]+)[[:space:]]+(\$[a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                params+=("${BASH_REMATCH[2]}: ${BASH_REMATCH[1]}")
            fi
            
            # Extract @return tag
            if [[ $prev_line =~ @return[[:space:]]+([^[:space:]]+) ]]; then
                returns="${BASH_REMATCH[1]}"
            fi
            
            # Extract description
            if [[ ! $prev_line =~ @ ]] && [[ $prev_line =~ \*[[:space:]]*(.+) ]]; then
                phpdoc="${BASH_REMATCH[1]}\n$phpdoc"
            fi
        fi
    done
    
    # Return structured data
    echo -e "DESCRIPTION:$phpdoc"
    echo "PARAMS:${params[*]}"
    echo "RETURNS:$returns"
}
