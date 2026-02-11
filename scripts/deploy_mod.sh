#!/bin/bash

# Colors for better readability (compatible with both oh-my-zsh and default terminal)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper function for logging
log_info() {
    echo -e "${BLUE}ℹ${NC} ${CYAN}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Usage function
usage() {
    echo "Usage: $0 <mod_name> [--force|-f]"
    echo ""
    echo "Arguments:"
    echo "  mod_name        Name of the mod (required)"
    echo "                  Pattern: word1_word2_..._number"
    echo "                  - Must use underscore '_' as separator"
    echo "                  - Must end with underscore followed by a number"
    echo "                  - Letter case doesn't matter"
    echo "  --force, -f     Skip confirmation prompt and delete existing files without asking"
    echo ""
    echo "Example:"
    echo "  $0 my_awesome_mod_1"
    echo "  $0 My_Transport_Mod_2 --force"
    exit 1
}

# Function to validate mod name pattern
validate_mod_name() {
    local mod_name="$1"

    # Check if mod name matches pattern: ends with underscore followed by number(s)
    # Also ensures it uses underscores and contains at least one underscore before the number
    if [[ "$mod_name" =~ ^[a-zA-Z0-9_]+_[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if mod_name argument is provided
if [ -z "$1" ]; then
    log_error "Mod name is required!"
    usage
fi

MOD_NAME="$1"
FORCE_DELETE=false

# Check for optional --force or -f argument
if [ "$2" == "--force" ] || [ "$2" == "-f" ]; then
    FORCE_DELETE=true
    log_warning "Force mode enabled - files will be deleted without confirmation"
fi

# Validate mod name pattern
log_info "Validating mod name pattern..."
if ! validate_mod_name "$MOD_NAME"; then
    log_error "Invalid mod name pattern: $MOD_NAME"
    echo ""
    echo "Mod name must follow this pattern:"
    echo "  - Use underscore '_' as separator (not hyphen or space)"
    echo "  - Must end with underscore followed by a number"
    echo "  - Example: my_awesome_mod_1, Transport_Mod_2, test_mod_42"
    echo ""
    exit 1
fi
log_success "Mod name pattern is valid: $MOD_NAME"

# Get the script's directory and calculate project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Translation directories
TRANSLATION_DIR="$PROJECT_ROOT/translation"
TRANSLATION_OUTPUT_DIR="$PROJECT_ROOT/mod/res/strings/zh_HK/LC_MESSAGES"

# Compile translation files (.po to .mo)
if [ -d "$TRANSLATION_DIR" ]; then
    log_info "Checking for translation files..."
    PO_FILES=$(find "$TRANSLATION_DIR" -name "*.po" 2>/dev/null)

    if [ -n "$PO_FILES" ]; then
        log_info "Compiling translation files..."

        # Check if msgfmt is available
        if ! command -v msgfmt &> /dev/null; then
            log_error "msgfmt command not found. Please install gettext package."
            echo "  Ubuntu/Debian: sudo apt-get install gettext"
            echo "  Fedora: sudo dnf install gettext"
            echo "  Arch: sudo pacman -S gettext"
            exit 1
        fi

        # Create output directory if it doesn't exist
        mkdir -p "$TRANSLATION_OUTPUT_DIR"

        # Compile each .po file to .mo
        COMPILED_COUNT=0
        while IFS= read -r po_file; do
            filename=$(basename "$po_file" .po)
            mo_file="$TRANSLATION_OUTPUT_DIR/${filename}.mo"

            log_info "Compiling: $filename.po -> $filename.mo"
            msgfmt "$po_file" -o "$mo_file"

            if [ $? -eq 0 ]; then
                ((COMPILED_COUNT++))
                log_success "Compiled: $filename.mo"
            else
                log_error "Failed to compile: $po_file"
                exit 1
            fi
        done <<< "$PO_FILES"

        log_success "Translation compilation completed: $COMPILED_COUNT file(s)"
    else
        log_warning "No .po files found in $TRANSLATION_DIR"
    fi
else
    log_warning "Translation directory not found: $TRANSLATION_DIR"
fi

# Source directory
SOURCE_DIR="$PROJECT_ROOT/mod"

# Destination directory
LINUX_USER=$(whoami)
STEAM_USERDATA_DIR="/home/$LINUX_USER/.local/share/Steam/userdata"

# Find the Steam user ID directory (usually there's only one)
log_info "Detecting Steam user ID..."
STEAM_USER_ID=$(find "$STEAM_USERDATA_DIR" -maxdepth 1 -type d -name "[0-9]*" -printf "%f\n" | head -n 1)

if [ -z "$STEAM_USER_ID" ]; then
    log_error "Could not detect Steam user ID in $STEAM_USERDATA_DIR"
    exit 1
fi

log_success "Steam user ID detected: $STEAM_USER_ID"

DESTINATION_DIR="$STEAM_USERDATA_DIR/$STEAM_USER_ID/1066780/local/staging_area/$MOD_NAME"

# Verify source directory exists
log_info "Checking source directory..."
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi
log_success "Source directory found: $SOURCE_DIR"

# Check if destination directory exists and contains files
log_info "Checking destination directory..."
if [ -d "$DESTINATION_DIR" ] && [ "$(ls -A "$DESTINATION_DIR" 2>/dev/null)" ]; then
    log_warning "Destination directory contains files: $DESTINATION_DIR"

    if [ "$FORCE_DELETE" = false ]; then
        # Ask user for confirmation
        echo -e "${YELLOW}⚠${NC} Do you want to delete all files in the destination? (y/N): \c"
        read -r response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                log_info "User confirmed deletion"
                ;;
            *)
                log_error "Deployment cancelled by user"
                exit 0
                ;;
        esac
    fi

    # Delete existing files
    log_info "Deleting existing files in destination..."
    rm -rf "${DESTINATION_DIR:?}"/*
    if [ $? -eq 0 ]; then
        log_success "Existing files deleted successfully"
    else
        log_error "Failed to delete existing files"
        exit 1
    fi
else
    log_info "Destination is empty or doesn't exist yet"
fi

# Create destination directory if it doesn't exist
log_info "Creating destination directory structure..."
mkdir -p "$DESTINATION_DIR"
if [ $? -eq 0 ]; then
    log_success "Destination directory ready: $DESTINATION_DIR"
else
    log_error "Failed to create destination directory"
    exit 1
fi

# Copy files
log_info "Copying mod files from $SOURCE_DIR..."
cp -r "$SOURCE_DIR"/* "$DESTINATION_DIR"/
if [ $? -eq 0 ]; then
    log_success "All files copied successfully!"
else
    log_error "Failed to copy files"
    exit 1
fi

# Count copied files
FILE_COUNT=$(find "$DESTINATION_DIR" -type f | wc -l)
log_success "Deployment completed! Total files: $FILE_COUNT"
log_info "Mod '$MOD_NAME' deployed to: $DESTINATION_DIR"