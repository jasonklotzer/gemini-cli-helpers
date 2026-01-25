#!/bin/bash

# This script installs or uninstalls aliases for the gemini-cli-helpers scripts.

# Help message
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $(basename "$0") [option]"
    echo ""
    echo "Installs or uninstalls aliases for the gemini-cli-helpers scripts."
    echo ""
    echo "Options:"
    echo "  (no option)      Install the script aliases."
    echo "  -u, --uninstall  Remove the script aliases."
    echo "  -h, --help       Show this help message and exit."
    exit 0
fi

# Check if gemini CLI is installed
if ! command -v gemini &> /dev/null; then
    echo "Error: gemini CLI is not installed. Please install it before running this installer."
    exit 1
fi

# The directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The file to which aliases will be added
ALIAS_FILE="$HOME/.bash_aliases"
BASHRC_FILE="$HOME/.bashrc"

# A marker to identify aliases managed by this script
MARKER="# Added by gemini-cli-helpers installer"

# Uninstall logic
if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
    if [[ -f "$ALIAS_FILE" ]] && grep -q "$MARKER" "$ALIAS_FILE"; then
        echo "Uninstalling gemini-cli-helpers aliases..."
        sed -i "/$MARKER/d" "$ALIAS_FILE"
        # Unalias currently-loaded aliases in this shell session
        for script_path in "$SCRIPT_DIR"/scripts/*.sh; do
            if [ -f "$script_path" ]; then
                alias_name="$(basename "${script_path%.sh}")"
                if alias "$alias_name" >/dev/null 2>&1; then
                    unalias "$alias_name"
                fi
            fi
        done
        echo "Aliases removed from $ALIAS_FILE and cleared from the current shell (if loaded)."
        echo "Restart your shell to ensure all sessions pick up the removal."
    else
        echo "No gemini-cli-helpers aliases found to uninstall."
    fi
    exit 0
fi

echo "Installing scripts from $SCRIPT_DIR..."

# Ensure the alias file exists
touch "$ALIAS_FILE"

# Add sourcing of alias file to .bashrc if not already present
BASHRC_MARKER="# Source shell script aliases (added by gemini-cli-helpers installer)"
if ! grep -q "$BASHRC_MARKER" "$BASHRC_FILE"; then
    if grep -Eq "\\.bash_aliases" "$BASHRC_FILE"; then
        echo "Existing .bash_aliases sourcing found in $BASHRC_FILE; leaving as-is."
    else
        echo "Adding source for $ALIAS_FILE to $BASHRC_FILE..."
        echo "" >> "$BASHRC_FILE"
        echo "$BASHRC_MARKER" >> "$BASHRC_FILE"
        echo "if [ -f \"$ALIAS_FILE\" ]; then" >> "$BASHRC_FILE"
        echo "    . \"$ALIAS_FILE\"" >> "$BASHRC_FILE"
        echo "fi" >> "$BASHRC_FILE"
    fi
fi

# Remove old aliases managed by this script
if grep -q "$MARKER" "$ALIAS_FILE"; then
    echo "Removing old aliases..."
    sed -i "/$MARKER/d" "$ALIAS_FILE"
fi

# Add new aliases for all .sh files in the scripts directory
for script_path in "$SCRIPT_DIR"/scripts/*.sh; do
    if [ -f "$script_path" ]; then
        script_name=$(basename "$script_path")
        alias_name="${script_name%.sh}"
        echo "Adding alias: $alias_name"
        # Make the script executable
        chmod +x "$script_path"
        echo "alias $alias_name='bash $script_path' $MARKER" >> "$ALIAS_FILE"
    fi
done

echo ""
echo "Installation complete!"
echo "Please run the following command to apply the changes:"
echo "source $BASHRC_FILE"
