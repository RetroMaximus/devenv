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

# Parse C/C++ files
parse_c_cpp_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing C/C++ file: $file_path${NC}"
    
    local current_namespace=""
    local current_class=""
    local current_struct=""
    local current_union=""
    local current_enum=""
    local class_methods=()
    local in_comment_block=false
    local current_comment=""
    local in_multiline_comment=false
    
    while IFS= read -r line; do
        # Handle multi-line comments
        if [[ "$line" =~ ^[[:space:]]*/\* ]]; then
            in_multiline_comment=true
            current_comment=""
            continue
        fi
        
        if [ "$in_multiline_comment" = true ]; then
            if [[ "$line" =~ \*/ ]]; then
                in_multiline_comment=false
            else
                # Clean comment line
                local clean_line=$(echo "$line" | sed 's/^[[:space:]]*\*[[:space:]]*//')
                current_comment+="$clean_line "
            fi
            continue
        fi
        
        # Single line comments
        if [[ "$line" =~ ^[[:space:]]*// ]] && [ -z "$current_comment" ]; then
            current_comment="${line#*//}"
            current_comment=$(echo "$current_comment" | xargs)
        fi
        
        # Namespace detection (C++)
        if [[ "$line" =~ ^[[:space:]]*namespace[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local namespace_name="${BASH_REMATCH[1]}"
            current_namespace="$namespace_name"
            output+="## Namespace: \`$namespace_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Class detection (C++)
        if [[ "$line" =~ ^[[:space:]]*(class|struct)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*[:{]] ]]; then
            local class_type="${BASH_REMATCH[1]}"
            local class_name="${BASH_REMATCH[2]}"
            
            if [ "$class_type" = "class" ]; then
                current_class="$class_name"
                current_struct=""
                current_union=""
                current_enum=""
                output+="## Class: \`$class_name\`\n\n"
            else
                current_struct="$class_name"
                current_class=""
                current_union=""
                current_enum=""
                output+="## Struct: \`$class_name\`\n\n"
            fi
            
            class_methods=()
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            # Add namespace context if available
            if [ -n "$current_namespace" ]; then
                output+="**Namespace**: $current_namespace\n\n"
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Union detection (C/C++)
        if [[ "$line" =~ ^[[:space:]]*union[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\{ ]]; then
            local union_name="${BASH_REMATCH[1]}"
            current_union="$union_name"
            current_class=""
            current_struct=""
            current_enum=""
            output+="## Union: \`$union_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Enum detection (C++11 style)
        if [[ "$line" =~ ^[[:space:]]*enum[[:space:]]+(class[[:space:]]+)?([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\{ ]]; then
            local enum_name="${BASH_REMATCH[2]}"
            current_enum="$enum_name"
            current_class=""
            current_struct=""
            current_union=""
            
            if [[ $line =~ enum[[:space:]]+class ]]; then
                output+="## Enum Class: \`$enum_name\`\n\n"
            else
                output+="## Enum: \`$enum_name\`\n\n"
            fi
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Function detection
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_<>[:space:]:*]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(([^)]*)\)[[:space:]]*[^{;]*$ ]] && 
           [[ ! "$line" =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^[[:space:]]*/\* ]]; then
            local return_type=$(echo "${BASH_REMATCH[1]}" | xargs)
            local func_name="${BASH_REMATCH[2]}"
            local params="${BASH_REMATCH[3]}"
            
            # Skip destructors and constructors
            if [[ $func_name =~ ^~ ]] || [[ $func_name == "$current_class" ]] || [[ $func_name == "$current_struct" ]]; then
                current_comment=""
                continue
            fi
            
            # Determine if it's a method or function
            local is_method=false
            if [ -n "$current_class" ] || [ -n "$current_struct" ]; then
                is_method=true
                class_methods+=("$func_name")
                output+="### Method: \`$func_name\`\n\n"
            else
                output+="## Function: \`$func_name\`\n\n"
            fi
            
            # Build signature with namespace/class context
            local signature=""
            if [ -n "$current_namespace" ] && [ "$is_method" = false ]; then
                signature+="$current_namespace::"
            fi
            if [ -n "$current_class" ]; then
                signature+="$current_class::"
            elif [ -n "$current_struct" ]; then
                signature+="$current_struct::"
            fi
            signature+="$func_name($params)"
            
            output+="#### Signature:\n\`\`\`cpp\n$return_type $signature\n\`\`\`\n\n"
            
            # Parse parameters if enabled
            if [ "$SHOW_EXTRA_ARGS" = "true" ] && [ -n "$params" ]; then
                output+="#### Parameters:\n"
                # Clean C++ parameter syntax
                local clean_params=$(echo "$params" | sed 's/const//g; s/&//g; s/\*//g')
                IFS=',' read -ra param_list <<< "$clean_params"
                for param in "${param_list[@]}"; do
                    param=$(echo "$param" | xargs)
                    # Handle C++ parameter syntax: Type name
                    if [[ $param =~ [[:space:]] ]]; then
                        local p_type=$(echo "$param" | awk '{print $1}')
                        local p_name=$(echo "$param" | awk '{$1=""; print $0}' | xargs)
                        if [ -n "$p_name" ]; then
                            output+="- $p_name: $p_type\n"
                        else
                            output+="- $p_type\n"
                        fi
                    # Handle parameters with defaults
                    elif [[ $param =~ = ]]; then
                        local p_name=$(echo "$param" | cut -d'=' -f1 | xargs)
                        local p_default=$(echo "$param" | cut -d'=' -f2 | xargs)
                        output+="- $p_name: * = $p_default\n"
                    else
                        output+="- $param: auto\n"
                    fi
                done
                output+="\n"
            fi
            
            # Add comments
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`cpp"
            if [ "$is_method" = true ]; then
                if [ -n "$current_class" ]; then
                    output+="\n${current_class} instance;"
                    output+="\ninstance.${func_name}("
                else
                    output+="\n${current_struct} instance;"
                    output+="\ninstance.${func_name}("
                fi
            else
                if [ -n "$current_namespace" ]; then
                    output+="\n${current_namespace}::${func_name}("
                else
                    output+="\n${func_name}("
                fi
            fi
            
            if [ -n "$params" ] && [[ "$params" != "void" ]] && [[ "$params" != "" ]]; then
                output+="\n    // parameters here"
                output+="\n);"
            else
                output+=");"
            fi
            output+="\n\`\`\`\n\n"
            
            # Navigation links
            if [ "$is_method" = true ]; then
                if [ -n "$current_class" ]; then
                    output+="[Back to ${current_class}](#class-${current_class}) | "
                elif [ -n "$current_struct" ]; then
                    output+="[Back to ${current_struct}](#struct-${current_struct}) | "
                fi
            elif [ -n "$current_namespace" ]; then
                output+="[Back to ${current_namespace}](#namespace-${current_namespace}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Variable declaration (members and globals)
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_<>[:space:]]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*[=;] ]] && 
           [[ ! "$line" =~ ^[[:space:]]*// ]] && [[ ! $line =~ ^[[:space:]]*/\* ]]; then
            local var_type=$(echo "${BASH_REMATCH[1]}" | xargs)
            local var_name="${BASH_REMATCH[2]}"
            
            # Skip if it's a function pointer or complex type
            if [[ $var_type =~ [*&] ]] || [[ $var_name =~ [()] ]]; then
                continue
            fi
            
            # Determine context
            local context=""
            if [ -n "$current_class" ] || [ -n "$current_struct" ] || [ -n "$current_union" ]; then
                output+="#### Member: \`$var_name\`\n\n"
                context="member"
            else
                output+="#### Variable: \`$var_name\`\n\n"
                context="variable"
            fi
            
            output+="**Type**: \`$var_type\`\n\n"
            
            # Extract value if available
            if [[ $line =~ =[[:space:]]*([^;]+) ]]; then
                local var_value="${BASH_REMATCH[1]}"
                output+="**Value**: \`$var_value\`\n\n"
            fi
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            # Navigation links
            if [ "$context" = "member" ]; then
                if [ -n "$current_class" ]; then
                    output+="[Back to ${current_class}](#class-${current_class}) | "
                elif [ -n "$current_struct" ]; then
                    output+="[Back to ${current_struct}](#struct-${current_struct}) | "
                elif [ -n "$current_union" ]; then
                    output+="[Back to ${current_union}](#union-${current_union}) | "
                fi
            elif [ -n "$current_namespace" ]; then
                output+="[Back to ${current_namespace}](#namespace-${current_namespace}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Enum value detection (C style)
        if [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*= ]] && [ -n "$current_enum" ]; then
            local enum_value="${BASH_REMATCH[1]}"
            local enum_val=$(echo "$line" | awk -F'=' '{print $2}' | sed 's/,[[:space:]]*$//' | xargs)
            
            output+="#### Enum Value: \`$enum_value\`\n\n"
            output+="**Value**: $enum_val\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to ${current_enum}](#enum-${current_enum}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Preprocessor macros
        if [[ "$line" =~ ^[[:space:]]*#define[[:space:]]+([A-Z_][A-Z0-9_]*) ]] && [ -z "$current_class" ]; then
            local macro_name="${BASH_REMATCH[1]}"
            local macro_value=$(echo "$line" | awk '{$1=""; $2=""; print $0}' | xargs)
            
            output+="#### Macro: \`$macro_name\`\n\n"
            output+="**Definition**: \`$macro_value\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            if [ -n "$current_namespace" ]; then
                output+="[Back to ${current_namespace}](#namespace-${current_namespace}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Typedef detection
        if [[ "$line" =~ ^[[:space:]]*typedef[[:space:]]+([^;]+); ]] && [ -z "$current_class" ]; then
            local typedef_content="${BASH_REMATCH[1]}"
            # Extract type name (last word)
            local type_name=$(echo "$typedef_content" | awk '{print $NF}')
            local base_type=$(echo "$typedef_content" | awk '{$NF=""; print $0}' | xargs)
            
            output+="#### Typedef: \`$type_name\`\n\n"
            output+="**Base Type**: \`$base_type\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            if [ -n "$current_namespace" ]; then
                output+="[Back to ${current_namespace}](#namespace-${current_namespace}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Reset current_comment if we hit a significant non-comment line
        if [[ ! "$line" =~ ^[[:space:]]*// ]] && [[ ! "$line" =~ ^[[:space:]]*/\* ]] && 
           [[ "$line" =~ [a-zA-Z] ]] && [ -n "$current_comment" ] && [ "$in_multiline_comment" = false ]; then
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
        elif [ -n "$current_struct" ]; then
            output=$(echo "$output" | sed "s/## Struct: \`$current_struct\`/## Struct: \`$current_struct\`\n\n**Methods**: ${methods_links}\n/")
        fi
    fi
    
    echo -e "$output"
}

# Helper function to extract C/C++ comments
extract_cpp_comment() {
    local file_path="$1"
    local trigger_line="$2"
    local comment=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*// ]] && [[ ! $prev_line =~ ^[[:space:]]*/\* ]]; then
            break
        fi
        
        # Skip comment block markers
        if [[ $prev_line =~ ^[[:space:]]*/\* ]] || [[ $prev_line =~ ^[[:space:]]*\*/ ]]; then
            continue
        fi
        
        # Add to comment (in reverse order)
        if [[ $prev_line =~ ^[[:space:]]*// ]]; then
            local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
            comment="$clean_line\n$comment"
        elif [[ $prev_line =~ ^[[:space:]]*\* ]]; then
            local clean_line=$(echo "$prev_line" | sed 's/^[[:space:]]*\*[[:space:]]*//')
            comment="$clean_line\n$comment"
        fi
    done
    
    echo -e "$comment" | xargs
}
