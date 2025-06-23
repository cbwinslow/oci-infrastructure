#!/bin/bash
# Fix Permissions Script for Repository Repair Agent

set -euo pipefail

# Default values
TARGET_PATH=""
FIX_EXECUTABLE=true
FIX_OWNERSHIP=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target-path=*)
            TARGET_PATH="${1#*=}"
            shift
            ;;
        --fix-executable=*)
            FIX_EXECUTABLE="${1#*=}"
            shift
            ;;
        --fix-ownership=*)
            FIX_OWNERSHIP="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET_PATH" ]]; then
    echo "Error: --target-path is required"
    exit 1
fi

echo "Fixing permissions in: $TARGET_PATH"
echo "Dry run: $DRY_RUN"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would fix permissions (dry run mode)"
    exit 0
fi

# Fix file permissions
find "$TARGET_PATH" -type f -exec chmod 644 {} \; 2>/dev/null || true

if [[ "$FIX_EXECUTABLE" == "true" ]]; then
    find "$TARGET_PATH" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
fi

if [[ "$FIX_OWNERSHIP" == "true" ]] && [[ $EUID -eq 0 ]]; then
    chown -R "$(logname):$(logname)" "$TARGET_PATH" 2>/dev/null || true
fi

echo "Permissions fixed successfully"
