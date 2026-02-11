#!/bin/bash

# Script: copy_raw.sh
# Purpose: Copy .mo files from TF2 installation and decompile to .po files

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
SOURCE_DIR="/home/$USER/.local/share/Steam/steamapps/common/Transport Fever 2/res/strings"
DEST_DIR="$PROJECT_ROOT/tf2"
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-confirm|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -y, --skip-confirm    Skip deletion confirmation"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

log "Source directory: $SOURCE_DIR"
log "Destination directory: $DEST_DIR"

# Check if destination has any files or folders
if [ -d "$DEST_DIR" ] && [ "$(ls -A "$DEST_DIR" 2>/dev/null)" ]; then
    log_warning "Destination directory contains files or folders."

    if [ "$SKIP_CONFIRM" = false ]; then
        echo -ne "${YELLOW}Do you want to delete and overwrite? (yes/no): ${NC}"
        read -r response

        if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
            log "Operation cancelled by user."
            exit 0
        fi
    else
        log "Skipping confirmation (--skip-confirm flag set)"
    fi

    log "Removing existing destination directory..."
    rm -rf "$DEST_DIR"
fi

# Create destination directory
log "Creating destination directory..."
mkdir -p "$DEST_DIR"

# Count total .mo files first
log "Counting .mo files..."
TOTAL_MO=$(find "$SOURCE_DIR" -type f -name "*.mo" 2>/dev/null | wc -l)

if [ "$TOTAL_MO" -eq 0 ]; then
    log_warning "No .mo files found in source directory!"
    exit 0
fi

log "Found $TOTAL_MO .mo files to copy"

# Use rsync if available (much more reliable), otherwise use cp with find -exec
if command -v rsync &> /dev/null; then
    log "Using rsync to copy files..."
    rsync -av --include='*/' --include='*.mo' --exclude='*' "$SOURCE_DIR/" "$DEST_DIR/" | grep -E '\.mo$' | while read -r line; do
        echo -ne "\r${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Copying files...   "
    done
    echo ""
else
    log "Using cp to copy files (rsync not available)..."
    # Use find with -exec which is more reliable than loops
    find "$SOURCE_DIR" -type f -name "*.mo" -exec sh -c '
        SOURCE_BASE="'"$SOURCE_DIR"'"
        DEST_BASE="'"$DEST_DIR"'"
        for src_file; do
            rel_path="${src_file#$SOURCE_BASE/}"
            dest_file="$DEST_BASE/$rel_path"
            dest_dir="$(dirname "$dest_file")"
            mkdir -p "$dest_dir"
            cp "$src_file" "$dest_file"
            echo "."
        done
    ' sh {} + | {
        count=0
        while read -r; do
            count=$((count + 1))
            if [ $((count % 10)) -eq 0 ]; then
                echo -ne "\r${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Copied $count files...   "
            fi
        done
        echo ""
    }
fi

# Verify copy
COPIED_MO=$(find "$DEST_DIR" -type f -name "*.mo" 2>/dev/null | wc -l)
log "Copied $COPIED_MO/$TOTAL_MO .mo files"

if [ "$COPIED_MO" -eq 0 ]; then
    log_error "No files were copied! Check permissions."
    exit 1
fi

# Check if msgunfmt is available
if ! command -v msgunfmt &> /dev/null; then
    log_error "msgunfmt command not found. Please install gettext package:"
    log_error "  Ubuntu/Debian: sudo apt-get install gettext"
    log_error "  Fedora: sudo dnf install gettext"
    log_error "  Arch: sudo pacman -S gettext"
    exit 1
fi

# Decompile .mo files to .po files
log "Decompiling .mo files to .po files..."

PO_COUNT=0
FAIL_COUNT=0

find "$DEST_DIR" -type f -name "*.mo" -exec sh -c '
    for mo_file; do
        po_file="${mo_file%.mo}.po"
        if msgunfmt "$mo_file" -o "$po_file" 2>/dev/null; then
            echo "ok"
        else
            echo "fail"
        fi
    done
' sh {} + | {
    while read -r result; do
        if [ "$result" = "ok" ]; then
            PO_COUNT=$((PO_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi

        if [ $(((PO_COUNT + FAIL_COUNT) % 10)) -eq 0 ]; then
            echo -ne "\r${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} Decompiled $PO_COUNT files...   "
        fi
    done
    echo ""
    echo "$PO_COUNT $FAIL_COUNT"
} | tail -1 | {
    read -r PO_COUNT FAIL_COUNT
    log "Decompilation complete: $PO_COUNT succeeded, $FAIL_COUNT failed"
}

# Final count
FINAL_PO=$(find "$DEST_DIR" -type f -name "*.po" 2>/dev/null | wc -l)

# Summary
echo ""
log "===== Summary ====="
log "Source: $SOURCE_DIR"
log "Destination: $DEST_DIR"
log ".mo files copied: $COPIED_MO"
log ".po files created: $FINAL_PO"
log "Operation completed successfully!"