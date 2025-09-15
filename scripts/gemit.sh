#!/bin/bash
# This script automates the process of generating a commit message using the
# Gemini CLI and then committing the changes.

# Exit immediately if a command exits with a non-zero status, if an unset
# variable is used, or if a command in a pipeline fails.
set -euo pipefail

# Function to show a spinner while a command is running
show_spinner() {
  local -r frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local -r delay=0.1
  local message="$1"
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

# Check for command line arguments
SUBMODULE_COMMIT=false
STAGE_ALL=false
RUN_RELEASE=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      echo "Usage: $(basename "$0") [-a|--all] [-s|--submodule] [-r|--release]"
      echo ""
      echo "This script automates the process of generating a commit message using the Gemini CLI and then committing the changes."
      echo ""
      echo "Options:"
      echo "  -h, --help         Show this help message and exit."
      echo "  -a, --all          Stage all tracked files before committing."
      echo "  -s, --submodule    If in a submodule, commit the submodule changes in the parent repository."
      echo "  -r, --release      Run 'npm run release' after committing."
      echo ""
      echo "Before running, ensure that you have staged the changes you want to commit, or use the -a/--all flag."
      exit 0
    ;;
    -a|--all)
      STAGE_ALL=true
      shift
    ;;
    -s|--submodule)
      SUBMODULE_COMMIT=true
      shift
    ;;
    -r|--release)
      RUN_RELEASE=true
      shift
    ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
    ;;
  esac
done

ACTION_SUMMARY=""
OPERATIONS=()

if [ "$STAGE_ALL" = true ]; then
  OPERATIONS+=("stage")
  git add -A
fi

OPERATIONS+=("commit")

if [ "$RUN_RELEASE" = true ]; then
  OPERATIONS+=("release")
fi

if [ "$SUBMODULE_COMMIT" = true ]; then
  OPERATIONS+=("submodule")
fi

ACTION_SUMMARY=$(printf " » %s" "${OPERATIONS[@]}")
ACTION_SUMMARY="exec ${ACTION_SUMMARY}"


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
show_spinner "$ACTION_SUMMARY" &
SPINNER_PID=$!
COMMIT_MESSAGE=$(git diff --staged | gemini -m gemini-2.5-flash-lite -p "Generate a concise, one-line GitHub commit message based on the following git diff. The message should be no more than 72 characters. If the diff shows the removal of a comment like '# TODO: #123 ...', the commit message should end with '(fixes #123)'. Only include the issue number if the TODO comment is being removed. You do not have to modify any files. Return only the commit message itself, without any extra text or explanations." 2>/dev/null)
kill "$SPINNER_PID" &>/dev/null
unset SPINNER_PID
tput cnorm # Restore cursor
printf "\r%s\n"

# Check if a message was successfully generated
if [[ -z "${COMMIT_MESSAGE}" ]]; then
  echo "Failed to generate a commit message. Exiting."
  exit 1
fi

# Perform the commit with the generated message.
git commit -m "${COMMIT_MESSAGE}"

if [ "$RUN_RELEASE" = true ]; then
    npm run release
fi

if [ "$SUBMODULE_COMMIT" = true ]; then
  # Check if this is a submodule
  SUPERPROJECT_WORK_TREE=$(git rev-parse --show-superproject-working-tree)
  if [ -n "$SUPERPROJECT_WORK_TREE" ]; then
    SUBMODULE_PATH=$(git rev-parse --show-toplevel)
    SUBMODULE_NAME=$(basename "$SUBMODULE_PATH")
    (cd "$SUPERPROJECT_WORK_TREE" && git add "$SUBMODULE_PATH" && git commit -m "Update submodule ${SUBMODULE_NAME}")
  fi
fi
