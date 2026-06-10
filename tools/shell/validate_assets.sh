#!/bin/bash
# Library: tools/shell/validate_assets.sh

validate_project_assets() {
    local PROJECT_DIR="${PROJECT_DIR:-/Users/jim/myKaraoke}"
    local PY_SCRIPT="$PROJECT_DIR/tools/python/validate_assets.py"

    if [[ ! -f "$PY_SCRIPT" ]]; then
        echo "❌ Error: Validation script missing at: $PY_SCRIPT"
        return 1
    fi

    python3 "$PY_SCRIPT" "$PROJECT_DIR"
}
