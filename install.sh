#!/bin/bash

# This script installs all executable scripts in this directory by creating aliases for them.

# The directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The file to which aliases will be added
ALIAS_FILE="$HOME/.bash_aliases"
BASHRC_FILE="$HOME/.bashrc"

# A marker to identify aliases managed by this script
MARKER="# Added by gemini-cli-helpers installer"

echo "Installing scripts from $SCRIPT_DIR..."

# Ensure the alias file exists
touch "$ALIAS_FILE"

# Add sourcing of alias file to .bashrc if not already present
if ! grep -q "source $ALIAS_FILE" "$BASHRC_FILE" && ! grep -q ". $ALIAS_FILE" "$BASHRC_FILE"; then
    echo "Adding source for $ALIAS_FILE to $BASHRC_FILE..."
    echo -e "\n# Source shell script aliases" >> "$BASHRC_FILE"
    echo "if [ -f \"$ALIAS_FILE\" ]; then" >> "$BASHRC_FILE"
    echo "    . \"$ALIAS_FILE\"" >> "$BASHRC_FILE"
    echo "fi" >> "$BASHRC_FILE"
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
        # Skip the installer script itself
        if [ "$script_name" == "install.sh" ]; then
            continue
        fi
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
