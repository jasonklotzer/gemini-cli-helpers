#!/bin/bash
# This script automates the process of generating a commit message using the
# Gemini CLI and then committing the changes.

# Exit immediately if a command exits with a non-zero status, if an unset
# variable is used, or if a command in a pipeline fails.
set -euo pipefail

# TODO: #2 Create animated spinner while waiting for Gemini CLI to respond.

# Function to show a spinner while a command is running
show_spinner() {
    local -r frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local -r delay=0.1
    local -r message="$1"
    local i=0
    tput civis # Hide cursor
    while :; do
        printf "\r%s %s" "${frames:i++%${#frames}:1}" "$message"
        sleep "$delay"
    done
}

# Trap to clean up spinner on exit
cleanup() {
    if [[ -n "${SPINNER_PID-}" ]]; then
        kill "$SPINNER_PID" &>/dev/null
    fi
    tput cnorm # Restore cursor
    printf "\r"
}
trap cleanup EXIT

# TODO: #1 Create help flag that explains how to use this script.

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $(basename "$0")"
  echo ""
  echo "This script automates the process of generating a commit message using the Gemini CLI and then committing the changes."
  echo ""
  echo "Before running, ensure that you have staged the changes you want to commit."
  exit 0
fi

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
show_spinner "Generating commit message..." &
SPINNER_PID=$!
COMMIT_MESSAGE=$(git diff --staged | gemini -m gemini-2.5-flash-lite -p "Based on the following git diff, provide a single explanatory commit message, no larger than 100 characters. As long as the total commit message is within the 100 character limit, other lines can be used to describe important changes. If there were any github issues referenced in TODO comments removed as a part of this commit, close them through the commit message (e.g. fixes #1). Just return the message itself, with no extra text or explanations." 2>/dev/null)
kill "$SPINNER_PID" &>/dev/null
tput cnorm # Restore cursor
printf "\r%s\n" "✔ Commit message generated."

# Check if a message was successfully generated
if [[ -z "${COMMIT_MESSAGE}" ]]; then
  echo "Failed to generate a commit message. Exiting."
  exit 1
fi

# Perform the commit with the generated message.
git commit -m "${COMMIT_MESSAGE}"
