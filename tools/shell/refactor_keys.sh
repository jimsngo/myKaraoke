#!/bin/bash
# Standalone Utility: tools/shell/refactor_keys.sh
# Purpose: Scan for variable string drift across assets, layouts, and automation tools

PROJECT_DIR="/Users/jim/myKaraoke"
TMP_MATCHES="/tmp/mykaraoke_matches.txt"
rm -f "$TMP_MATCHES"

echo "🔍 myKaraoke Variable Dependency & Code Refactoring Utility"
echo "========================================================="

# 1. Capture user search constraints
read -p "📂 Enter the OLD variable name to search for (e.g., subtitles_srt): " OLD_VAR
if [[ -z "$OLD_VAR" ]]; then
    echo "❌ Error: Search target string cannot be empty."
    exit 1
fi

read -p "🚀 Enter the NEW replacement variable name (e.g., srt): " NEW_VAR
if [[ -z "$NEW_VAR" ]]; then
    echo "❌ Error: Replacement target string cannot be empty."
    exit 1
fi

echo ""
echo "📡 Phase 1: Scanning repository codebase for occurrences of '$OLD_VAR'..."
echo "--------------------------------------------------------="

# Safely find matching text files (.sh, .js, .html, .json), skipping hidden .git directories
FOUND_ANY=false
MATCHING_FILES=$(find "$PROJECT_DIR" -type f \( -name "*.sh" -o -name "*.js" -o -name "*.html" -o -name "*.json" \) ! -path "*/.*")

for FILE in $MATCHING_FILES; do
    # Skip this refactoring script itself to prevent it from altering its own variables
    if [[ "$FILE" == *"/refactor_keys.sh"* ]]; then
        continue
    fi

    # Scan safely for strict standalone keyword matches
    LINE_COUNT=$(grep -c -w "$OLD_VAR" "$FILE" 2>/dev/null)
    if [[ $LINE_COUNT -gt 0 ]]; then
        FOUND_ANY=true
        echo "$FILE" >> "$TMP_MATCHES"
        echo "📂 Found $LINE_COUNT match(es) inside: ${FILE#$PROJECT_DIR/}"
        
        # Display line matches clearly with line numbers
        grep -n -w "$OLD_VAR" "$FILE" | sed 's/^/  👉 Line /'
        echo "--------------------------------------------------------="
    fi
done

if [ "$FOUND_ANY" = false ] || [ ! -f "$TMP_MATCHES" ]; then
    echo "✅ Clean Scan: No active references to '$OLD_VAR' found in any automation script."
    rm -f "$TMP_MATCHES"
    exit 0
fi

# 2. Phase 2: Interactive Authorization Confirmation
echo ""
echo "⚠️ WARNING: You are about to refactor code dependencies."
echo "   Changing '$OLD_VAR' ➔ '$NEW_VAR'"
read -p "❓ Would you like to auto-update these file dependencies now? [y/N]: " CHOICE
CHOICE=$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]')

if [[ "$CHOICE" == "y" || "$CHOICE" == "yes" ]]; then
    echo ""
    echo "⚙️ Executing regular-expression codebase refactor..."
    echo "========================================================="
    
    # Read the file targets line by line from our temporary matching log
    while IFS= read -r FILE; do
        if [[ -f "$FILE" ]]; then
            echo "🛠️ Refactoring: ${FILE#$PROJECT_DIR/}"
            
            # Using strict word boundaries [[:<:]] and [[::>:]] optimized specifically for macOS sed
            sed -i '' "s/[[:<:]]${OLD_VAR}[[::>:]]/${NEW_VAR}/g" "$FILE"
        fi
    done < "$TMP_MATCHES"
    
    echo ""
    echo "🎯 Complete: Code base alignment finished successfully!"
else
    echo "❌ Execution aborted: Code assets left completely untouched."
fi

# Clean up our temporary cache file
rm -f "$TMP_MATCHES"