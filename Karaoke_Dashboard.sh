#!/bin/bash
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Central Management Dashboard Router
# Script: Karaoke_Dashboard.sh
# Purpose: Master routing controller. Features an isolated tracking variable
#          to prevent interactive sub-menus from breaking the auto-run hook.
# ==============================================================================

PROJECT_DIR="${PROJECT_DIR:-/Users/jim/myKaraoke}"
ASSETS_FILE="$PROJECT_DIR/assets.json"

# Source UI library and Asset Manager suite
source "$PROJECT_DIR/tools/shell/ui_lib.sh" || exit 1
source "$PROJECT_DIR/tools/shell/asset_manager.sh" || exit 1

# 🛡️ PHASE 1: FORCE REAL-TIME ASSET VERIFICATION AT BOOT
initialize_or_verify_session

# 🎛️ PHASE 2: DYNAMIC UTILITY ROUTING MENU LOOP
while true; do
    display_menu  # Reads assets.json live to draw the current track header
    echo -n -e "👉 Select option [0-13] (or hit Enter to re-display menu): "
    read -r choice

    if [[ -z "$choice" ]]; then
        continue
    fi

    # 💡 LOCK SELECTION: Protects original input from being overwritten by sub-scripts
    DASHBOARD_TRACK_CHOICE="$choice"

    echo -e "\n⚡ Executing option [$DASHBOARD_TRACK_CHOICE] from assets.json blueprint..."
    
    # Extract execution parameters live from the master JSON file
    SCRIPT_PATH=$(jq -r ".dashboard_routing.\"$DASHBOARD_TRACK_CHOICE\".script // \"\"" "$ASSETS_FILE")
    FUNC_NAME=$(jq -r ".dashboard_routing.\"$DASHBOARD_TRACK_CHOICE\".function // \"\"" "$ASSETS_FILE")
    ROUTING_NOTE=$(jq -r ".dashboard_routing.\"$DASHBOARD_TRACK_CHOICE\".note // \"\"" "$ASSETS_FILE")

    if [[ -n "$ROUTING_NOTE" && "$ROUTING_NOTE" != "null" ]]; then
        echo -e "📝 Dependent Script Note: $ROUTING_NOTE\n"
    fi

    if [[ "$DASHBOARD_TRACK_CHOICE" == "0" ]]; then
        echo "👋 Exiting myKaraoke control room. Keep creating!"
        exit 0
    elif [[ -n "$SCRIPT_PATH" && -f "$PROJECT_DIR/$SCRIPT_PATH" ]]; then
        source "$PROJECT_DIR/$SCRIPT_PATH"
        $FUNC_NAME  # Runs the sub-level function
        
        # ⚡ AUTOMATION HOOK: Protected by isolated tracking architecture
        if [[ "$DASHBOARD_TRACK_CHOICE" == "1" ]]; then
            echo -e "\n🔄 Option [1] complete. Auto-triggering Option [5] to compile MIDI to .ass..."
            
            # Safely query Option 5 routing specs live from assets database
            OPT5_SCRIPT=$(jq -r '.dashboard_routing."5".script // ""' "$ASSETS_FILE")
            OPT5_FUNC=$(jq -r '.dashboard_routing."5".function // ""' "$ASSETS_FILE")
            
            if [[ -n "$OPT5_SCRIPT" && -f "$PROJECT_DIR/$OPT5_SCRIPT" ]]; then
                echo -e "🎼 Launching MIDI Compiler core engine..."
                source "$PROJECT_DIR/$OPT5_SCRIPT"
                $OPT5_FUNC
            else
                echo "⚠️  Automation Hook Error: Option 5 script path could not be resolved."
            fi
        fi
    else
        echo "❌ Invalid selection or target library script missing for option [$DASHBOARD_TRACK_CHOICE]."
    fi

    echo ""
    read -p "Press [Enter] to return to the master dashboard menu..."
done