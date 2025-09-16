#!/bin/bash
# fix_line_endings.sh - Convert line endings in multiple files/directories

usage() {
    echo "Usage: $0 [-r] <file-or-directory> [file-or-directory2 ...]"
    echo "  -r    Process directories recursively"
    echo "Converts DOS (CRLF) line endings to UNIX (LF) line endings"
}

RECURSIVE=false

while getopts "r" opt; do
    case $opt in
        r) RECURSIVE=true ;;
        *) usage; exit  ;;
    esac
done
shift $((OPTIND-1))

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

process_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found!"
        return 1
    fi
    
    # Check if file needs conversion (contains CRLF)
    if grep -q $'\r' "$file"; then
        echo "Converting $file..."
        sed -i 's/\r$//' "$file"
        echo "✓ Converted $file"
    else
        echo "✓ $file already has UNIX line endings"
    fi
}

process_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' not found!"
        return 1
    fi
    
    echo "Processing directory files for line endings: $dir"
    
    if [ "$RECURSIVE" = true ]; then
        find "$dir" -type f -name "*.sh" -o -name "*.py" -o -name "*.txt" -o -name "*.conf" | while read -r file; do
            process_file "$file"
        echo "Done."
        done
    else
        for file in "$dir"/*; do
            if [ -f "$file" ]; then
                process_file "$file"
            fi
        echo "Done."
        done
    fi
}

for target in "$@"; do
    if [ -f "$target" ]; then
        process_file "$target"
    elif [ -d "$target" ]; then
        process_directory "$target"
    else
        echo "Error: '$target' is not a file or directory!"
    fi
done
