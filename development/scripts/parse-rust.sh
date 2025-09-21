#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


# Helper function to extract Rust doc comments
extract_rustdoc() {
    local file_path="$1"
    local trigger_line="$2"
    local rustdoc=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for doc comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-doc-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*/// ]] && [[ ! $prev_line =~ ^[[:space:]]*//! ]] && 
           [[ ! $prev_line =~ ^[[:space:]]*/\* ]] && [[ ! $prev_line =~ ^[[:space:]]*/\*! ]]; then
            break
        fi
        
        # Add to rustdoc (in reverse order)
        if [[ $prev_line =~ ^[[:space:]]*/// ]]; then
            local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*\/\/\/[[:space:]]*//')
            rustdoc="$clean_line\n$rustdoc"
        elif [[ $prev_line =~ ^[[:space:]]*//! ]]; then
            local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*\/\/\![[:space:]]*//')
            rustdoc="$clean_line\n$rustdoc"
        fi
    done
    
    echo -e "$rustdoc" | xargs
}

# Parse Rust files
parse_rs_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing Rust file: $file_path${NC}"
    
    local current_struct=""
    local current_impl=""
    local struct_methods=()
    local in_doc_comment=false
    local current_doc=""
    
    while IFS= read -r line; do
        # Handle doc comments
        if [[ $line =~ ^[[:space:]]*/// ]]; then
            in_doc_comment=true
            local clean_line=$(echo "$line" | sed 's/^[[:space:]]*\/\/\/[[:space:]]*//')
            current_doc+="$clean_line "
            continue
        elif [[ $line =~ ^[[:space:]]*//! ]]; then
            in_doc_comment=true
            local clean_line=$(echo "$line" | sed 's/^[[:space:]]*\/\/\![[:space:]]*//')
            current_doc+="$clean_line "
            continue
        elif [[ $line =~ ^[[:space:]]*/\*\! ]] || [[ $line =~ ^[[:space:]]*/\*\* ]]; then
            in_doc_comment=true
            current_doc=""
            continue
        fi
        
        if [ "$in_doc_comment" = true ]; then
            if [[ $line =~ \*/ ]]; then
                in_doc_comment=false
            else
                local clean_line=$(echo "$line" | sed 's/^[[:space:]]*\*[[:space:]]*//')
                current_doc+="$clean_line "
            fi
            continue
        fi
        
        # Reset doc if we hit a non-comment line
        if [[ ! $line =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^[[:space:]]*/\* ]]; then
            if [ -n "$current_doc" ]; then
                current_doc=$(echo "$current_doc" | xargs)
            fi
        fi
        
        # Struct detection
        if [[ $line =~ ^[[:space:]]*pub[[:space:]]+struct[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*struct[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local struct_name="${BASH_REMATCH[1]}"
            current_struct="$struct_name"
            struct_methods=()
            output+="## Struct: \`$struct_name\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Enum detection
        if [[ $line =~ ^[[:space:]]*pub[[:space:]]+enum[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*enum[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local enum_name="${BASH_REMATCH[1]}"
            output+="## Enum: \`$enum_name\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Trait detection
        if [[ $line =~ ^[[:space:]]*pub[[:space:]]+trait[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*trait[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local trait_name="${BASH_REMATCH[1]}"
            output+="## Trait: \`$trait_name\`\n\n"
            
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Impl block detection
        if [[ $line =~ ^[[:space:]]*impl[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            current_impl="${BASH_REMATCH[1]}"
            if [ -n "$current_doc" ]; then
                output+="#### Implementation Notes:\n> $current_doc\n\n"
                current_doc=""
            fi
        fi
        
        # Function detection (methods and free functions)
        if [[ $line =~ ^[[:space:]]*pub[[:space:]]+fn[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]] || 
           [[ $line =~ ^[[:space:]]*fn[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local func_name="${BASH_REMATCH[1]}"
            
            # Skip private functions for user help
            if [ "$help_type" = "user" ] && [[ ! $line =~ pub[[:space:]]+fn ]]; then
                current_doc=""
                continue
            fi
            
            # Check if it's a method (has self parameter)
            local is_method=false
            if [[ $line =~ fn[[:space:]]+$func_name[[:space:]]*\((&?self) ]]; then
                is_method=true
                if [ -n "$current_impl" ] && [ "$current_impl" != "$current_struct" ]; then
                    struct_methods+=("$func_name")
                fi
            fi
            
            if [ "$is_method" = true ] && [ -n "$current_impl" ]; then
                output+="### Method: \`$func_name\`\n\n"
            else
                output+="## Function: \`$func_name\`\n\n"
            fi
            
            # Extract function signature
            if [[ $line =~ fn[[:space:]]+$func_name[[:space:]]*\((.*)\) ]]; then
                local params="${BASH_REMATCH[1]}"
                if [ "$is_method" = true ]; then
                    output+="#### Signature:\n\`\`\`rust\nfn $func_name($params)\n\`\`\`\n\n"
                else
                    output+="#### Signature:\n\`\`\`rust\nfn $func_name($params)\n\`\`\`\n\n"
                fi
                
                # Parse parameters if enabled
                if [ "$SHOW_EXTRA_ARGS" = "true" ]; then
                    output+="#### Parameters:\n"
                    # Clean up Rust parameter syntax
                    local clean_params=$(echo "$params" | sed 's/&mut //g; s/&//g; s/mut //g')
                    IFS=',' read -ra param_list <<< "$clean_params"
                    for param in "${param_list[@]}"; do
                        param=$(echo "$param" | xargs)
                        # Handle Rust parameter syntax: name: type
                        if [[ $param =~ : ]]; then
                            local p_name=$(echo "$param" | cut -d: -f1 | xargs)
                            local p_type=$(echo "$param" | cut -d: -f2 | xargs)
                            output+="- $p_name: $p_type\n"
                        elif [[ $param =~ ^self ]]; then
                            output+="- self: Self\n"
                        else
                            output+="- $param: _\n"
                        fi
                    done
                    output+="\n"
                fi
            fi
            
            # Extract return type if present
            if [[ $line =~ -\>[[:space:]]*([^{]+) ]]; then
                local return_type="${BASH_REMATCH[1]}"
                output+="#### Returns:\n\`$return_type\`\n\n"
            fi
            
            # Add Rust doc comments
            if [ -n "$current_doc" ]; then
                output+="#### Description:\n> $current_doc\n\n"
                current_doc=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`rust"
            if [ "$is_method" = true ] && [ -n "$current_impl" ]; then
                output+="\nlet mut instance = ${current_impl}::new();"
                output+="\ninstance.${func_name}("
            else
                output+="\n${func_name}("
            fi
            output+="\n    // parameters here"
            output+="\n);\n\`\`\`\n\n"
            
            # Navigation links
            if [ "$is_method" = true ] && [ -n "$current_impl" ]; then
                output+="[Back to ${current_impl}](#struct-${current_impl}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Reset current_doc if we're not in a comment and hit a significant line
        if [[ ! $line =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^[[:space:]]*/\* ]] && 
           [[ $line =~ [a-zA-Z] ]] && [ -n "$current_doc" ]; then
            current_doc=""
        fi
        
    done < "$file_path"
    
    # Add struct methods summary if we found a struct with methods
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





