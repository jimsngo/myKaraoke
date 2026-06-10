#!/bin/bash
# Library: tools/shell/git_sync.sh

git_sync() {
    # Define clean, local environment contexts independent of the master dashboard state
    local PROJECT_ROOT="/Users/jim/myKaraoke"
    
    echo "📦 Initializing automated Git synchronization..."
    echo "📁 Target Project Canvas: $PROJECT_ROOT"
    echo ""

    # Navigate to your project directory
    cd "$PROJECT_ROOT" || {
        echo "❌ Error: Could not access project root folder path."
        return 1
    }

    # 1. Sanity Check: Ensure this is an active Git repository tracker
    if [ ! -d ".git" ]; then
        echo "❌ Error: This folder is not initialized as a Git repository."
        echo "   Please run 'git init' and set up your remote origin branch first!"
        return 1
    fi

    # 2. Check current status variations
    echo "🔍 Scanning workspace for timeline updates or file mutations..."
    git status -s

    echo ""
    read -p "Do you want to stage these mutations and push updates to GitHub? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "⏭️  Sync sequence aborted. Returning to master menu."
        return 0
    fi

    echo ""
    echo "🚀 Staging all project canvas changes..."
    git add .

    # Generate a clean runtime timestamp descriptor string (e.g., "2026-06-09 14:30")
    local CURRENT_TIME=$(date "+%Y-%m-%d %H:%M")
    local COMMIT_MSG="Automated myKaraoke pipeline synchronization - $CURRENT_TIME"

    echo "📝 Committing alterations with safe tracking timestamp..."
    git commit -m "$COMMIT_MSG"

    # 3. Securely push updates to your main cloud tracking branch
    echo "📡 Deploying code blocks to remote GitHub repository branch [main]..."
    git push origin main

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Success! Project canvas state is perfectly synced with cloud servers."
    else
        echo ""
        echo "❌ Error: Git push pipeline encountered a network or authentication block."
        return 1
    fi
}