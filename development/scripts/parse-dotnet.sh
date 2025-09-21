#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse .NET files (C#)
parse_dotnet_file() {
    local file_path="$1"
    local help_type="$2"
    
    if should_exclude "$file_path"; then
        echo -e "${YELLOW}Skipping excluded file: $file_path${NC}"
        return
    fi
    
    local output=""
    echo -e "${BLUE}Parsing .NET file: $file_path${NC}"
    
    local current_class=""
    local current_interface=""
    local current_struct=""
    local current_enum=""
    local class_methods=()
    local in_xml_comment=false
    local current_comment=""
    local comment_params=()
    local comment_returns=""
    local comment_summary=""
    
    while IFS= read -r line; do
        # Handle XML documentation comments
        if [[ $line =~ ^[[:space:]]*///[[:space:]]*<summary> ]]; then
            in_xml_comment=true
            current_comment=""
            comment_params=()
            comment_returns=""
            comment_summary=""
            continue
        fi
        
        if [ "$in_xml_comment" = true ]; then
            # Check for param tags
            if [[ $line =~ \<param[[:space:]]+name=\"([^\"]+)\"[^>]*>([^<]+) ]]; then
                local p_name="${BASH_REMATCH[1]}"
                local p_desc="${BASH_REMATCH[2]}"
                comment_params+=("$p_name: $p_desc")
            fi
            
            # Check for returns tags
            if [[ $line =~ \<returns>([^<]+) ]]; then
                comment_returns="${BASH_REMATCH[1]}"
            fi
            
            # Check for summary content
            if [[ $line =~ ^[[:space:]]*///[[:space:]]*([^<].+) ]] && [[ ! $line =~ \< ]]; then
                comment_summary+="${BASH_REMATCH[1]} "
            fi
            
            # Check for end of summary
            if [[ $line =~ \</summary> ]]; then
                in_xml_comment=false
                current_comment="$comment_summary"
            fi
            
            continue
        fi
        
        # Class detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private|abstract|sealed|static)[[:space:]]+class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local class_name="${BASH_REMATCH[2]}"
            current_class="$class_name"
            current_interface=""
            current_struct=""
            current_enum=""
            class_methods=()
            output+="## Class: \`$class_name\`\n\n"
            
            if [[ $line =~ abstract ]]; then
                output+="**Abstract class**\n\n"
            fi
            if [[ $line =~ sealed ]]; then
                output+="**Sealed class**\n\n"
            fi
            if [[ $line =~ static ]]; then
                output+="**Static class**\n\n"
            fi
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Interface detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private)[[:space:]]+interface[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local interface_name="${BASH_REMATCH[2]}"
            current_interface="$interface_name"
            current_class=""
            current_struct=""
            current_enum=""
            output+="## Interface: \`$interface_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Struct detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private)[[:space:]]+struct[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local struct_name="${BASH_REMATCH[2]}"
            current_struct="$struct_name"
            current_class=""
            current_interface=""
            current_enum=""
            output+="## Struct: \`$struct_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Enum detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private)[[:space:]]+enum[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            local enum_name="${BASH_REMATCH[2]}"
            current_enum="$enum_name"
            current_class=""
            current_interface=""
            current_struct=""
            output+="## Enum: \`$enum_name\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to Top](#table-of-contents)\n\n"
        fi
        
        # Method detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private|static|virtual|override|abstract|async)[[:space:]]+([^[:space:]]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(([^)]*)\) ]]; then
            local modifiers="${BASH_REMATCH[1]}"
            local return_type="${BASH_REMATCH[2]}"
            local method_name="${BASH_REMATCH[3]}"
            local params="${BASH_REMATCH[4]}"
            
            # Skip private methods for user help
            if [ "$help_type" = "user" ] && [[ $modifiers =~ private ]]; then
                current_comment=""
                comment_params=()
                comment_returns=""
                continue
            fi
            
            if [ -n "$current_class" ] || [ -n "$current_interface" ] || [ -n "$current_struct" ]; then
                class_methods+=("$method_name")
                output+="### Method: \`$method_name\`\n\n"
            else
                output+="## Method: \`$method_name\`\n\n"
            fi
            
            # Build signature
            local signature=""
            if [ -n "$modifiers" ]; then
                signature+="$modifiers "
            fi
            signature+="$return_type $method_name($params)"
            
            output+="#### Signature:\n\`\`\`csharp\n$signature\n\`\`\`\n\n"
            
            # Parse parameters if enabled
            if [ "$SHOW_EXTRA_ARGS" = "true" ] && [ -n "$params" ]; then
                output+="#### Parameters:\n"
                IFS=',' read -ra param_list <<< "$params"
                for param in "${param_list[@]}"; do
                    param=$(echo "$param" | xargs)
                    # Handle C# parameter syntax: Type name
                    if [[ $param =~ ^([a-zA-Z_][a-zA-Z0-9_<>\.]*)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                        local p_type="${BASH_REMATCH[1]}"
                        local p_name="${BASH_REMATCH[2]}"
                        # Look for XML doc description
                        local p_desc=""
                        for comment_param in "${comment_params[@]}"; do
                            if [[ $comment_param =~ ^$p_name: ]]; then
                                p_desc=" - ${comment_param#*:}"
                                break
                            fi
                        done
                        output+="- $p_name: $p_type$p_desc\n"
                    # Handle ref/out parameters
                    elif [[ $param =~ ^(ref|out)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_<>\.]*)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                        local p_modifier="${BASH_REMATCH[1]}"
                        local p_type="${BASH_REMATCH[2]}"
                        local p_name="${BASH_REMATCH[3]}"
                        output+="- $p_name: $p_modifier $p_type\n"
                    # Handle parameters with defaults
                    elif [[ $param =~ = ]]; then
                        local p_name=$(echo "$param" | cut -d'=' -f1 | xargs)
                        local p_default=$(echo "$param" | cut -d'=' -f2 | xargs)
                        output+="- $p_name: * = $p_default\n"
                    else
                        output+="- $param: object\n"
                    fi
                done
                output+="\n"
            fi
            
            # Add return type info
            if [[ $return_type != "void" ]]; then
                output+="#### Returns:\n\`$return_type\`"
                if [ -n "$comment_returns" ]; then
                    output+=" - $comment_returns"
                fi
                output+="\n\n"
            fi
            
            # Add XML doc comments
            if [ -n "$current_comment" ]; then
                output+="#### Description:\n> $current_comment\n\n"
                current_comment=""
            fi
            
            # Add usage example
            output+="#### Usage:\n\`\`\`csharp"
            if [ -n "$current_class" ]; then
                if [[ $modifiers =~ static ]]; then
                    output+="\n${current_class}.${method_name}("
                else
                    output+="\nvar instance = new ${current_class}();"
                    output+="\ninstance.${method_name}("
                fi
            elif [ -n "$current_struct" ]; then
                output+="\nvar instance = new ${current_struct}();"
                output+="\ninstance.${method_name}("
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
            elif [ -n "$current_struct" ]; then
                output+="[Back to ${current_struct}](#struct-${current_struct}) | "
            fi
            output+="[Back to Top](#table-of-contents)\n\n"
            
            # Reset comment variables
            comment_params=()
            comment_returns=""
        fi
        
        # Property detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private|static)[[:space:]]+([^[:space:]]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\{\s*get;\s*set;\s*\} ]] && 
           [ -n "$current_class" ]; then
            local modifiers="${BASH_REMATCH[1]}"
            local property_type="${BASH_REMATCH[2]}"
            local property_name="${BASH_REMATCH[3]}"
            
            # Skip private properties for user help
            if [ "$help_type" = "user" ] && [[ $modifiers =~ private ]]; then
                current_comment=""
                continue
            fi
            
            output+="#### Property: \`$property_name\`\n\n"
            output+="**Type**: \`$property_type\`\n"
            output+="**Accessors**: get; set;\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to ${current_class}](#class-${current_class}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Field detection
        if [[ $line =~ ^[[:space:]]*(public|internal|protected|private|static|readonly)[[:space:]]+([^[:space:]]+)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*[=;] ]] && 
           [ -n "$current_class" ]; then
            local modifiers="${BASH_REMATCH[1]}"
            local field_type="${BASH_REMATCH[2]}"
            local field_name="${BASH_REMATCH[3]}"
            
            # Skip private fields for user help
            if [ "$help_type" = "user" ] && [[ $modifiers =~ private ]]; then
                current_comment=""
                continue
            fi
            
            output+="#### Field: \`$field_name\`\n\n"
            output+="**Type**: \`$field_type\`\n\n"
            
            if [ -n "$current_comment" ]; then
                output+="**Description**: $current_comment\n\n"
                current_comment=""
            fi
            
            output+="[Back to ${current_class}](#class-${current_class}) | [Back to Top](#table-of-contents)\n\n"
        fi
        
        # Enum value detection
        if [[ $line =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*= ]] && [ -n "$current_enum" ]; then
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
        
        # Reset current_comment if we hit a significant non-comment line
        if [[ ! $line =~ ^[[:space:]]*// ]] && [[ $line =~ [a-zA-Z] ]] && [ -n "$current_comment" ] && [ "$in_xml_comment" = false ]; then
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
        elif [ -n "$current_interface" ]; then
            output=$(echo "$output" | sed "s/## Interface: \`$current_interface\`/## Interface: \`$current_interface\`\n\n**Methods**: ${methods_links}\n/")
        elif [ -n "$current_struct" ]; then
            output=$(echo "$output" | sed "s/## Struct: \`$current_struct\`/## Struct: \`$current_struct\`\n\n**Methods**: ${methods_links}\n/")
        fi
    fi
    
    echo -e "$output"
}

# Helper function to extract XML documentation comments
extract_xmldoc() {
    local file_path="$1"
    local trigger_line="$2"
    local xmldoc=""
    local params=()
    local returns=""
    
    # Get line number of the trigger line
    local line_num=$(grep -n "$trigger_line" "$file_path" | cut -d: -f1)
    
    # Look backwards for XML comments
    for ((i=line_num-1; i>=1; i--)); do
        local prev_line=$(sed "${i}q;d" "$file_path")
        
        # Stop if we hit a non-comment line
        if [[ ! $prev_line =~ ^[[:space:]]*// ]]; then
            break
        fi
        
        # Extract param tags
        if [[ $prev_line =~ \<param[[:space:]]+name=\"([^\"]+)\"[^>]*>([^<]+) ]]; then
            params+=("${BASH_REMATCH[1]}: ${BASH_REMATCH[2]}")
        fi
        
        # Extract returns tags
        if [[ $prev_line =~ \<returns>([^<]+) ]]; then
            returns="${BASH_REMATCH[1]}"
        fi
        
        # Extract summary content
        if [[ $prev_line =~ ^[[:space:]]*///[[:space:]]*([^<].+) ]] && [[ ! $prev_line =~ \< ]]; then
            xmldoc="${BASH_REMATCH[1]}\n$xmldoc"
        fi
    done
    
    # Return structured data
    echo -e "DESCRIPTION:$xmldoc"
    echo "PARAMS:${params[*]}"
    echo "RETURNS:$returns"
}