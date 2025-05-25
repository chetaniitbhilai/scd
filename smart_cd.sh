#!/bin/bash

# Smart CD - Enhanced directory navigation with history and fuzzy search
# Usage: 
#   scd [partial_path]  - Fuzzy search and navigate
#   scd -l              - List recent directories
#   scd -c              - Clear history
#   scd --stats         - Show usage statistics

# Configuration
SMART_CD_HISTORY_FILE="${HOME}/.smart_cd_history"
SMART_CD_MAX_ENTRIES=1000

# Initialize history file if it doesn't exist
if [[ ! -f "$SMART_CD_HISTORY_FILE" ]]; then
    touch "$SMART_CD_HISTORY_FILE"
fi

# Function to add directory to history with frequency tracking
_smart_cd_add_to_history() {
    local dir="$1"
    local temp_file=$(mktemp)
    local found=false
    
    # Read existing history and update frequency
    while IFS='|' read -r count path timestamp || [[ -n "$path" ]]; do
        if [[ "$path" == "$dir" ]]; then
            echo "$((count + 1))|$path|$(date +%s)" >> "$temp_file"
            found=true
        else
            echo "$count|$path|$timestamp" >> "$temp_file"
        fi
    done < "$SMART_CD_HISTORY_FILE" 2>/dev/null
    
    # Add new entry if not found
    if [[ "$found" == false ]]; then
        echo "1|$dir|$(date +%s)" >> "$temp_file"
    fi
    
    # Sort by frequency (descending) and keep only max entries
    sort -t'|' -k1,1nr -k3,3nr "$temp_file" 2>/dev/null | head -n "$SMART_CD_MAX_ENTRIES" > "$SMART_CD_HISTORY_FILE"
    rm -f "$temp_file"
}

# Function to get all possible directory matches
_smart_cd_get_matches() {
    local query="$1"
    local matches=()
    
    # If empty query, return recent directories
    if [[ -z "$query" ]]; then
        while IFS='|' read -r count path timestamp || [[ -n "$path" ]]; do
            if [[ -d "$path" ]]; then
                matches+=("$path")
            fi
        done < "$SMART_CD_HISTORY_FILE" 2>/dev/null
        printf '%s\n' "${matches[@]}" | head -10
        return
    fi
    
    # 1. Check if it's an exact directory path
    if [[ -d "$query" ]]; then
        echo "$query"
        return
    fi
    
    # 2. Search history for matches with proper scoring (PRIORITIZED)
    local history_matches=()
    local history_scores=()
    while IFS='|' read -r count path timestamp || [[ -n "$path" ]]; do
        if [[ -d "$path" ]]; then
            local basename=$(basename "$path")
            local score=0
            
            # Exact basename match gets highest score
            if [[ "$basename" == "$query" ]]; then
                score=$((1000 + count * 50))
            # Basename starts with query
            elif [[ "$basename" == "$query"* ]]; then
                score=$((500 + count * 30))
            # Basename contains query (case insensitive)
            elif [[ "${basename,,}" == *"${query,,}"* ]]; then
                score=$((300 + count * 20))
            # Full path contains query
            elif [[ "${path,,}" == *"${query,,}"* ]]; then
                score=$((100 + count * 10))
            fi
            
            # Add recency bonus
            local age=$(($(date +%s) - timestamp))
            local recency_bonus=$((50 - (age / 86400)))
            if [[ $recency_bonus -gt 0 ]]; then
                score=$((score + recency_bonus))
            fi
            
            if [[ $score -gt 0 ]]; then
                history_matches+=("$path")
                history_scores+=("$score")
            fi
        fi
    done < "$SMART_CD_HISTORY_FILE" 2>/dev/null
    
    # Sort history matches by score (descending)
    local sorted_history=()
    if [[ ${#history_matches[@]} -gt 0 ]]; then
        local indexed_matches=()
        for i in "${!history_matches[@]}"; do
            indexed_matches+=("${history_scores[$i]}|${history_matches[$i]}")
        done
        
        while IFS='|' read -r score path; do
            sorted_history+=("$path")
        done < <(printf '%s\n' "${indexed_matches[@]}" | sort -t'|' -k1,1nr)
    fi
    
    # 3. Only check current directory if NO history matches found
    local current_matches=()
    if [[ ${#sorted_history[@]} -eq 0 ]]; then
        for dir in */; do
            if [[ -d "$dir" ]]; then
                local dirname="${dir%/}"
                if [[ "$dirname" == "$query"* ]] || [[ "$dirname" == *"$query"* ]]; then
                    current_matches+=("$(pwd)/$dirname")
                fi
            fi
        done
    fi
    
    # 4. Combine matches, prioritizing history first
    local all_matches=()
    
    # Add sorted history matches first (they get priority)
    for match in "${sorted_history[@]}"; do
        all_matches+=("$match")
    done
    
    # Add current directory matches only if no history matches
    for match in "${current_matches[@]}"; do
        all_matches+=("$match")
    done
    
    printf '%s\n' "${all_matches[@]}"
}

# Function to list recent directories
_smart_cd_list() {
    echo "Recent directories (frequency|path|last_accessed):"
    echo "=================================================="
    local count=0
    while IFS='|' read -r freq path timestamp || [[ -n "$path" ]]; do
        if [[ -d "$path" ]]; then
            local date_str=$(date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "unknown")
            printf "%3d × %-50s %s\n" "$freq" "$path" "$date_str"
            ((count++))
            if [[ $count -ge 20 ]]; then break; fi
        fi
    done < "$SMART_CD_HISTORY_FILE" 2>/dev/null
}

# Function to show statistics
_smart_cd_stats() {
    local total_entries=0
    local total_visits=0
    local most_visited=""
    local max_count=0
    
    while IFS='|' read -r count path timestamp || [[ -n "$path" ]]; do
        if [[ -d "$path" ]]; then
            total_entries=$((total_entries + 1))
            total_visits=$((total_visits + count))
            if [[ $count -gt $max_count ]]; then
                max_count=$count
                most_visited="$path"
            fi
        fi
    done < "$SMART_CD_HISTORY_FILE" 2>/dev/null
    
    echo "Smart CD Statistics:"
    echo "==================="
    echo "Total unique directories: $total_entries"
    echo "Total visits tracked: $total_visits"
    if [[ -n "$most_visited" ]]; then
        echo "Most visited: $most_visited ($max_count visits)"
    fi
}

# Function to clear history
_smart_cd_clear() {
    echo -n "Clear directory history? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        > "$SMART_CD_HISTORY_FILE"
        echo "History cleared."
    else
        echo "Cancelled."
    fi
}

# Interactive selection for multiple matches
_smart_cd_interactive_select() {
    local query="$1"
    local matches=("$@")
    matches=("${matches[@]:1}")  # Remove first element (query)
    
    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "No directories found matching: $query"
        return 1
    fi
    
    echo "Multiple matches found:"
    for i in "${!matches[@]}"; do
        printf "%2d) %s\n" $((i + 1)) "${matches[$i]}"
    done
    
    echo -n "Select directory (1-${#matches[@]}): "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#matches[@]} ]]; then
        local selected_dir="${matches[$((selection - 1))]}"
        echo "→ $selected_dir"
        builtin cd "$selected_dir" && _smart_cd_add_to_history "$(pwd)"
    else
        echo "Invalid selection."
        return 1
    fi
}

# Main smart cd function
scd() {
    case "$1" in
        -l|--list)
            _smart_cd_list
            ;;
        -c|--clear)
            _smart_cd_clear
            ;;
        --stats)
            _smart_cd_stats
            ;;
        -h|--help)
            cat << 'EOF'
Smart CD - Enhanced directory navigation with fuzzy search

Usage:
  scd [query]     Navigate to directory using fuzzy search
  scd             Show recent directories for selection
  scd -l          List recent directories with stats
  scd -c          Clear navigation history
  scd --stats     Show usage statistics
  scd -h          Show this help

Examples:
  scd doc         # Navigate to Documents, docs, or any dir containing "doc"
  scd proj        # Navigate to projects, project-name, etc.
  scd /path       # Navigate to exact path
  scd<TAB>        # Tab completion with history and current dirs

Priority: History matches first (by frequency), then current directory matches.
EOF
            ;;
        "")
            # No arguments, go to home directory (like regular cd)
            echo "→ $HOME"
            builtin cd "$HOME" && _smart_cd_add_to_history "$(pwd)"
            ;;
        *)
            local matches
            mapfile -t matches < <(_smart_cd_get_matches "$1")
            
            if [[ ${#matches[@]} -eq 0 ]]; then
                echo "No directories found matching: $1"
                return 1
            else
                # Always go to the first (best) match
                local best_match="${matches[0]}"
                echo "→ $best_match"
                
                # Show other matches if there are multiple (for user awareness)
                if [[ ${#matches[@]} -gt 1 ]]; then
                    echo "   (other matches: $(basename "${matches[1]}")$(if [[ ${#matches[@]} -gt 2 ]]; then echo ", +$((${#matches[@]} - 2)) more"; fi))"
                fi
                
                builtin cd "$best_match" && _smart_cd_add_to_history "$(pwd)"
            fi
            ;;
    esac
}

# Enhanced tab completion
_scd_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    
    # Handle command options
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-l --list -c --clear --stats -h --help" -- "$cur"))
        return 0
    fi
    
    # Check if current input looks like a path with subdirectories
    # This handles cases like "Documents/", "Documents/sub", etc.
    if [[ "$cur" == */* ]]; then
        # Extract the base directory and the partial subdirectory
        local base_dir="${cur%/*}"
        local sub_partial="${cur##*/}"
        
        # Try to resolve the base directory
        local resolved_base=""
        
        # First try if it's an absolute or relative path
        if [[ -d "$base_dir" ]]; then
            resolved_base="$base_dir"
        else
            # Try to find the base directory using our smart matching
            local base_matches
            mapfile -t base_matches < <(_smart_cd_get_matches "$base_dir")
            if [[ ${#base_matches[@]} -gt 0 ]] && [[ -d "${base_matches[0]}" ]]; then
                resolved_base="${base_matches[0]}"
            fi
        fi
        
        # If we found a valid base directory, complete its subdirectories
        if [[ -n "$resolved_base" ]] && [[ -d "$resolved_base" ]]; then
            local subdirs=()
            while IFS= read -r -d '' dir; do
                local dirname=$(basename "$dir")
                if [[ "$dirname" == "$sub_partial"* ]]; then
                    # Use relative path format for completion
                    if [[ "$resolved_base" == "$base_dir" ]]; then
                        subdirs+=("$base_dir/$dirname/")
                    else
                        subdirs+=("$base_dir/$dirname/")
                    fi
                fi
            done < <(find "$resolved_base" -maxdepth 1 -type d -not -path "$resolved_base" -print0 2>/dev/null)
            
            if [[ ${#subdirs[@]} -gt 0 ]]; then
                COMPREPLY=($(compgen -W "${subdirs[*]}" -- "$cur"))
                return 0
            fi
        fi
        
        # Fall back to default directory completion if smart matching fails
        COMPREPLY=($(compgen -d -- "$cur"))
        return 0
    fi
    
    # Get matches for the current input (original logic for simple cases)
    local matches
    mapfile -t matches < <(_smart_cd_get_matches "$cur")
    
    # Convert full paths to basenames for completion when appropriate
    local completions=()
    for match in "${matches[@]}"; do
        local basename_match=$(basename "$match")
        # If we're in the directory or it's a well-known path, use basename with trailing slash
        if [[ "$match" == "$(pwd)/"* ]] || [[ ${#matches[@]} -eq 1 ]]; then
            completions+=("$basename_match/")
        else
            # For history matches, offer both basename and full path options
            completions+=("$basename_match/")
            # Only add full path if it's different and not too long
            if [[ "$basename_match" != "$match" ]] && [[ ${#match} -lt 60 ]]; then
                completions+=("$match/")
            fi
        fi
    done
    
    # Also add current directory subdirectories for immediate completion
    for dir in */; do
        if [[ -d "$dir" ]]; then
            local dirname="${dir%/}"
            if [[ "$dirname" == "$cur"* ]]; then
                completions+=("$dirname/")
            fi
        fi
    done
    
    # Remove duplicates and limit results
    local unique_completions=($(printf '%s\n' "${completions[@]}" | sort -u | head -20))
    
    COMPREPLY=($(compgen -W "${unique_completions[*]}" -- "$cur"))
}

# Override regular cd to track history (optional)
cd() {
    builtin cd "$@" && _smart_cd_add_to_history "$(pwd)"
}

# Register completion with nospace option to prevent automatic space after completion
complete -o nospace -F _scd_completion scd

