#!/bin/bash
# ==============================================================================
# ⚠️ WARNING: NEVER DELETE OR MODIFY THIS SUMMARY BLOCK. ALL DIRECTIONS MUST BE FOLLOWED.
# ⚠️ DIRECTIVE: FOLLOW THE .gitignore CONFIGURATION WITH ABSOLUTE FIDELITY.
# ==============================================================================
# 🎵 myKaraoke Project Toolchain — Git Sync Engine Library
# Script: tools/shell/git_sync.sh
# Purpose: Clean text-only code sync respecting workspace root .gitignore rules.
# Guardrails: Must stay under 50 lines. No force staging flags (-f) allowed.
# ==============================================================================

git_sync() {
    echo "📦 Initializing automated Git synchronization..."

    # 1. Verify repo presence natively before attempting changes
    if [ ! -d ".git" ]; then
        echo "❌ Error: Working directory is not a tracked Git repository tracker."
        return 1
    fi

    # 2. Show clear short status of text and script updates detected
    echo -e "\n🔍 Workspace Changes Detected:"
    git status -s

    echo ""
    read -p "🚀 Do you want to push these text assets to GitHub? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "⏭️  Sync sequence aborted. Returning to menu."
        return 0
    fi

    # 3. Stage changes naturally. Standard '.' relies implicitly on .gitignore
    git add .

    # Generate a lightweight timestamp descriptor log
    local CURRENT_TIME=$(date "+%Y-%m-%d %H:%M")
    git commit -m "Automated myKaraoke pipeline synchronization - $CURRENT_TIME"

    # 4. Push updates upstream safely
    echo -e "\n📡 Deploying code blocks to remote GitHub [main]..."
    git push origin main

    if [ $? -eq 0 ]; then
        echo -e "\n✅ Success! Code assets synced cleanly with GitHub servers."
    else
        echo -e "\n❌ Error: Git push transaction failed."
        return 1
    fi
}