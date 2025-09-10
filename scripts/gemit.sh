#!/bin/bash
# This script automates the process of generating a commit message using the
# Gemini CLI and then committing the changes.
 
# Exit immediately if a command exits with a non-zero status, if an unset
# variable is used, or if a command in a pipeline fails.
set -euo pipefail

# Check if there are any staged changes to commit.
if git diff --staged --quiet; then
    echo "No staged changes to commit. Exiting."
    exit 0
fi

# Check if the Gemini CLI is available.
if ! command -v gemini &> /dev/null
then
    echo "Gemini CLI not found. Please install it to use this script."
    exit 1
fi

# Call the Gemini CLI with the staged diff and request a brief commit message.
COMMIT_MESSAGE=$(git diff --staged | gemini -m gemini-2.5-flash-lite -p "Based on the following git diff, provide a single, brief commit message that no larger than 100 characters. If there were any github issues referenced referenced in comments removed as a part of this commit, close them through the commit message. Just return the message itself, with no extra text or explanations." 2>/dev/null)

# Check if a message was successfully generated
if [[ -z "${COMMIT_MESSAGE}" ]]; then
    echo "Failed to generate a commit message. Exiting."
    exit 1
fi

# Perform the commit with the generated message.
git commit -m "${COMMIT_MESSAGE}"
