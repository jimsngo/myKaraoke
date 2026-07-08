#!/bin/bash
# Library: tools/shell/ui_lib.sh

get_dashboard_option_max() {
    local presets_file="${1:-$PROJECT_DIR/assets.json}"
    if [[ ! -f "$presets_file" ]]; then
        echo "0"
        return
    fi

    jq -r '
        .dashboard_routing
        | to_entries
        | map(select(.key | test("^[0-9]+$")))
        | map(.key | tonumber)
        | if length == 0 then 0 else max end
    ' "$presets_file" 2>/dev/null || echo "0"
}

display_menu() {
    clear
    
    # Establish local path references for real-time asset checks
    local PRESETS_FILE="$PROJECT_DIR/assets.json"
    local CURRENT_TRACK="No Active Song Session"
    
    if [[ -f "$PRESETS_FILE" ]]; then
        local TITLE=$(jq -r '.inputs.song_title // ""' "$PRESETS_FILE")
        local AUTHOR=$(jq -r '.inputs.song_author // ""' "$PRESETS_FILE")
        
        if [[ -n "$TITLE" ]]; then
            if [[ -n "$AUTHOR" ]]; then
                CURRENT_TRACK="$TITLE ($AUTHOR)"
            else
                CURRENT_TRACK="$TITLE"
            fi
        fi
    fi

    echo -e "\033[1;36m=========================================================\033[0m"
    echo -e "\033[1;36m             🎤  myKaraoke Automation Console  🎤        \033[0m"
    echo -e "\033[1;36m=========================================================\033[0m"
    echo -e "🎵 Active Project: \033[1;32m$CURRENT_TRACK\033[0m"
    echo -e "\033[1;36m=========================================================\033[0m"
    echo ""
    
    local menu_rows
    if [[ -f "$PRESETS_FILE" ]]; then
        menu_rows=$(jq -r '
            (.dashboard_routing // {})
            | to_entries
            | map(select(.key | test("^[0-9]+$")))
            | sort_by(.key | tonumber)
            | .[]
            | [
                .key,
                (.value.category // "Other"),
                (.value.label // "Unnamed option")
              ]
            | @tsv
        ' "$PRESETS_FILE" 2>/dev/null)
    fi

    if [[ -n "$menu_rows" ]]; then
        local current_category=""
        while IFS=$'\t' read -r option_key category label; do
            [[ -z "$option_key" ]] && continue
            if [[ "$category" != "$current_category" ]]; then
                [[ -n "$current_category" ]] && echo ""
                echo -e "\033[1;33m${category}:\033[0m"
                current_category="$category"
            fi
            printf " %2s) %s\n" "$option_key" "$label"
        done <<< "$menu_rows"
        echo ""
    else
        echo -e "\033[1;33m⚠️  Menu configuration missing in assets.json\033[0m"
        echo ""
    fi

    echo "  0) Exit Dashboard"
    echo ""
    echo -e "\033[1;36m=========================================================\033[0m"
}
# Utility to open a macOS native file picker dialog
pick_file() {
    local prompt_text="${1:-Select a file}"
    # Use AppleScript to open a Finder dialog and return the POSIX path
    local file_path=$(osascript -e "POSIX path of (choose file with prompt \"$prompt_text\")" 2>/dev/null)
    
    if [[ -z "$file_path" ]]; then
        return 1 # User cancelled
    fi
    echo "$file_path"
}