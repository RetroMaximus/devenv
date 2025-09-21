#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to extract Go doc comments
extract_godoc() {
    local file_path="$1"
    local trigger_line="$2"
    local godoc=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*// ]]; then
            break
        fi
        
        # Add to godoc (in reverse order)
        local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
        godoc="$clean_line\n$godoc"
    done
    
    echo -e "$godoc" | xargs
}

# Parse Go files
parse_go_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing Go file: $file_path${NC}"
    
    local current_struct=""
    local struct_methods=()
    local in_comment_block=false
    local current_comment=""
    
    while IFS= read -r line; do
        # Handle block comments
        if [[ $line =~ ^[[:space:]]*/\* ]]; then
            in_comment_block=true
            current_comment=""
            continue
        fi
        
        if [ "$in_comment_block" = true ]; then
            if [[ $line =~ \*/ ]]; then
                in_comment_block=false
            else
                # Clean comment line
                local clean_line=$(echo "$line" | sed 's/^[[:space:]]*\*[[:space:]]*//')
                current_comment+="$clean_line "
            fi
            continue
        fi
        
        # Function detection
        if [[ $line =~ ^func[[:space:]]+(\([^)]+\)[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local func_name="${BASH_REMATCH[2]}"
            local receiver=""
            
            # Extract receiver if present
            if [[ $line =~ func[[:space:]]+\(([^)]+)\) ]]; then
                receiver="${BASH_REMATCH[1]}"
            fi
            
            # Skip private functions for user help
            if [ "$help_type" = "user" ] && [[ $func_name =~ ^[a-z] ]]; then
                continue
            fi
            
            # Determine if it's a method or function
            if [ -n "$receiver" ]; then
                # It's a method
                local struct_name=$(echo "$receiver" | awk '{print $2}')
                if [ "$current_struct" != "$struct_name" ]; then
                    current_struct="$struct_name"
                    struct_methods=()
                    output+="## Struct: \`$struct_name\`\n\n"
                    
                    if [ -n "$current_comment" ]; then
                        output+="#### Description:\n> $current_comment\n\n"
                        current_comment=""
                    fi
                    
                    output+="[Back to Top](#table-of-contents)\n\n"
                fi
                
                struct_methods+=("$func_name")
                output+="### Method: \`$func_name\`\n\n"
            else
                # It's a function
                output+="## Function: \`$func_name\`\n\n"
            fi
            
            # Extract function signature
            if [[ $line =~ func[[:space:]]+.*$func_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                if [ -n "$receiver" ]; then
                    output+="#### Signature:\n\`\`\`go\nfunc ($receiver) $func_name($params)\n\`\`\`\n\n"
                else
                    output+="#### Signature:\n\`\`\`go\nfunc $func_name($params)\n\`\`\`\n\n"
                fi
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                    output+="#### Parameters:\n"
                    IFS=',' read -ra param_list <<< "$params"
                    for param in "${param_list[@]}"; do
                        param=$(echo "$param" | xargs)
                        # Handle Go parameter syntax: name type
                        if [[ $param =~ [[:space:]] ]]; then
                            local p_name=$(echo "$param" | awk '{print $1}')
                            local p_type=$(echo "$param" | awk '{print $2}')
                            output+="- $p_name: $p_type\n"
                        else
                            output+="- $param: interface{}\n"
                        fi
                    done
                    output+="\n"
                fi
            fi
            
            # Add Go doc comments
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`go"
            if [ -n "$receiver" ]; then
                output+="\nvar s ${struct_name}"
                output+="\ns.${func_name}("
            else
                output+="\n${func_name}("
            fi
            output+="\n    // parameters here"
            output+="\n)\n\`\`\`\n\n"
            
            # Navigation links
            if [ -n "$receiver" ]; then
                output+="[Back to ${struct_name}](#struct-${struct_name}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Single line comments
        if [[ $line =~ ^// ]] && [ -z "$current_comment" ]; then
            current_comment="${line#*//}"
            current_comment=$(echo "$current_comment" | xargs)
        fi
        
        # Reset comment if we hit a non-comment, non-function line
        if [[ ! $line =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^func ]] && [ -n "$current_comment" ]; then
            current_comment=""
        fi
        
        # Struct/type detection
        if [[ $line =~ ^type[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+struct ]]; then
            local struct_name="${BASH_REMATCH[1]}"
            current_struct="$struct_name"
            struct_methods=()
            output+="## Struct: \`$struct_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
    done < "$file_path"
    
    # Add struct methods summary if we found a struct
    if [ -n "$current_struct" ] && [ ${#struct_methods[@]} -gt 0 ]; then
        local methods_links=""
        for method in "${struct_methods[@]}"; do
            methods_links+="[\`$method\`](#method-$method) | "
        done
        methods_links=${methods_links% | }  # Remove trailing separator
        
        # Insert methods summary after struct header
        output=$(echo "$output" | sed "s/## Struct: \`$current_struct\`/## Struct: \`$current_struct\`\n\n**Methods**: ${methods_links}\n/")
    fi
    
    echo -e "$output"
}



