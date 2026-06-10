#!/bin/bash
# Central Guard: tools/shell/validate_json.sh
# Purpose: Prevent execution if script references an invalid/missing assets.json key

PROJECT_DIR="/Users/jim/myKaraoke"
ASSETS_FILE="$PROJECT_DIR/assets.json"

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0;0m'

validate_required_keys() {
    local CALLING_SCRIPT="$1"
    shift
    local REQUIRED_KEYS=("$@")
    local BROKEN_KEYS=0

    if [[ ! -f "$ASSETS_FILE" ]]; then
        echo -e "${RED}❌ System Error: assets.json missing at $ASSETS_FILE${NC}"
        exit 1
    fi

    # Extract all real top-level entries inside the .inputs object as key:value pairs
    local SCHEMA_ENTRIES
    SCHEMA_ENTRIES=$(jq -r '.inputs | to_entries[] | "\(.key):\(.value)"' "$ASSETS_FILE" 2>/dev/null)

    for REQ_KEY in "${REQUIRED_KEYS[@]}"; do
        # Verify if key exists natively
        if ! echo "$SCHEMA_ENTRIES" | grep -q "^${REQ_KEY}:"; then
            echo -e "${RED}⚠️  Key Misalignment Detected in: ${CALLING_SCRIPT}${NC}"
            echo -e "${RED}   Expected Variable Key: \".inputs.${REQ_KEY}\" was NOT found in assets.json${NC}"
            
            # Smart context identification based on what type the script is defining
            local LOOK_EXT=""
            if [[ "$REQ_KEY" == *"srt"* ]]; then
                LOOK_EXT="\.srt"
            elif [[ "$REQ_KEY" == *"ass"* ]]; then
                LOOK_EXT="\.ass"
            fi

            # Collect candidates matching that file extension type inside assets.json
            local MATCHING_CANDIDATES=()
            while IFS= read -r entry; do
                if [[ -n "$entry" ]]; then
                    local k_name="${entry%%:*}"
                    local v_val="${entry#*:}"
                    
                    if [[ -n "$LOOK_EXT" ]]; then
                        if echo "$v_val" | grep -qi "$LOOK_EXT"; then
                            MATCHING_CANDIDATES+=("$k_name")
                        fi
                    else
                        MATCHING_CANDIDATES+=("$k_name")
                    fi
                fi
            done <<< "$SCHEMA_ENTRIES"

            # If there's a valid matching candidate of that asset type, suggest it
            if [[ ${#MATCHING_CANDIDATES[@]} -gt 0 ]]; then
                # Since there are typically only 1 or 2 options of a type (like .srt or .ass), 
                # suggest the first key matching that specific file type context
                local SUGGESTION="${MATCHING_CANDIDATES[0]}"
                echo -e "${CYAN}   👉 Are you referring to \"$SUGGESTION\", as opposed to \"$REQ_KEY\"?${NC}"
            fi
            echo "--------------------------------------------------------"
            ((BROKEN_KEYS++))
        fi
    done

    if [[ $BROKEN_KEYS -gt 0 ]]; then
        echo -e "${RED}💥 A ha... we have a broken variable schema connection!${NC}"
        echo -e "${YELLOW}   Fix the key name alignment before running this task.${NC}"
        echo "--------------------------------------------------------"
        exit 1
    fi
}