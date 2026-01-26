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
VERBOSE=false
SHOW_PREVIEW=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --version)
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      PACKAGE_JSON="$SCRIPT_DIR/../package.json"
      if [ -f "$PACKAGE_JSON" ]; then
        VERSION=$(grep -oP '(?<="version": ")[^"]*' "$PACKAGE_JSON")
        echo "gemit version $VERSION"
      else
        echo "Version information not available"
      fi
      exit 0
    ;;
    -h|--help)
      echo "Usage: $(basename "$0") [-a|--all] [-s|--submodule] [-r|--release] [-v|--verbose] [-p|--preview]"
      echo ""
      echo "This script automates the process of generating a commit message using the Gemini CLI and then committing the changes."
      echo ""
      echo "Options:"
      echo "  -h, --help         Show this help message and exit."
      echo "  --version          Show version information."
      echo "  -a, --all          Stage all tracked files before committing."
      echo "  -s, --submodule    If in a submodule, commit the submodule changes in the parent repository."
      echo "  -r, --release      Run 'npm run release' after committing."
      echo "  -v, --verbose      Enable verbose mode to show all messages for debugging."
      echo "  -p, --preview      Preview all changes before committing."
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
    -v|--verbose)
      VERBOSE=true
      shift
    ;;
    -p|--preview)
      SHOW_PREVIEW=true
      shift
    ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
    ;;
  esac
done

# Ensure we are inside a git repository before proceeding.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: This script must be run inside a git repository."
  exit 1
fi

ACTION_SUMMARY=""
OPERATIONS=()

if [ "$STAGE_ALL" = true ]; then
  OPERATIONS+=("stage")
  if [ "$VERBOSE" = true ]; then
    echo "Staging all tracked files..."
  fi
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
ACTION_SUMMARY="exec${ACTION_SUMMARY}"

# Check if there are any changes (staged, unstaged, or new files) to work with
HAS_STAGED=$(! git diff --staged --quiet; echo $?)
HAS_UNSTAGED=$(! git diff --quiet; echo $?)
HAS_UNTRACKED=$(git ls-files --others --exclude-standard | wc -l)

if [ "$HAS_STAGED" -ne 0 ] && [ "$HAS_UNSTAGED" -ne 0 ] && [ "$HAS_UNTRACKED" -eq 0 ]; then
  echo "No changes detected. Exiting."
  exit 0
fi

# Configuration for Gemini CLI
GEMINI_MODEL="gemini-2.5-flash-lite"
COMMIT_PROMPT="Generate a concise git commit message (max 72 chars) for this diff. If a TODO comment with issue number is removed, end with '(fixes #123)'. Return only the commit message."
CHANGES_PREVIEW_PROMPT="Provide a concise summary of the changes in this diff using a bulleted list. Focus on what was changed and why. Keep it short and scannable. For new files, describe what they contain."

# Display changes preview if requested
if [ "$SHOW_PREVIEW" = true ]; then
  # Determine which diff to show (staged or unstaged)
  if [ "$HAS_STAGED" -eq 0 ]; then
    # Show staged changes
    DIFF_SOURCE="staged"
    DISPLAY_DIFF=$(git diff --staged)
  else
    # Show unstaged changes
    DIFF_SOURCE="unstaged"
    DISPLAY_DIFF=$(git diff)
  fi
  
  # Include untracked files info for Gemini analysis
  if [ "$HAS_UNTRACKED" -gt 0 ]; then
    # Add file contents for small untracked files (up to 100 lines each)
    while IFS= read -r file; do
      if [ -f "$file" ]; then
        LINE_COUNT=$(wc -l < "$file" 2>/dev/null || echo 0)
        if [ "$LINE_COUNT" -le 100 ]; then
          DISPLAY_DIFF+=$'\n\n'"--- New file: $file ---"$'\n'
          DISPLAY_DIFF+=$(cat "$file" 2>/dev/null)
          DISPLAY_DIFF+=$'\n'
        else
          DISPLAY_DIFF+=$'\n\n'"--- New file: $file (large file, $LINE_COUNT lines) ---"
        fi
      fi
    done < <(git ls-files --others --exclude-standard)
  fi
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  printf "║ %-58s ║\n" "CHANGES PREVIEW ($DIFF_SOURCE changes)"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  
  # Show changed files and statistics
  echo "Files Changed:"
  echo "--------------"
  if [ "$DIFF_SOURCE" = "staged" ]; then
    git diff --staged --stat
  else
    git diff --stat
  fi
  
  # Show untracked files if any exist
  if [ "$HAS_UNTRACKED" -gt 0 ]; then
    echo ""
    echo "Untracked files (not staged):"
    git ls-files --others --exclude-standard | sed 's/^/  /'
  fi
  echo ""
  
  # Check if the Gemini CLI is available for summary generation
  if command -v gemini &> /dev/null; then
    # Check if there's any content to analyze
    if [ -n "$DISPLAY_DIFF" ] && [ "$DISPLAY_DIFF" != "" ]; then
      if [ "$VERBOSE" = true ]; then
        echo "Generating comprehensive changes summary with Gemini CLI..."
      fi
      show_spinner "Analyzing changes" &
      SPINNER_PID=$!
      CHANGES_SUMMARY=$(echo "$DISPLAY_DIFF" | gemini -m "$GEMINI_MODEL" -p "$CHANGES_PREVIEW_PROMPT" 2>/dev/null)
      kill "$SPINNER_PID" &>/dev/null
      unset SPINNER_PID
      tput cnorm # Restore cursor
      printf "\n"
      
      if [[ -n "${CHANGES_SUMMARY}" ]]; then
        echo "Summary:"
        echo "--------"
        echo "$CHANGES_SUMMARY"
        echo ""
      fi
    fi
  fi
  
  exit 0
fi

# Check if there are any staged changes to commit.
if [ "$HAS_STAGED" -ne 0 ]; then
  echo "No staged changes to commit. Exiting."
  exit 0
fi

if [ "$VERBOSE" = true ]; then
  echo "Staged changes detected."
fi

# Check if the Gemini CLI is available.
if ! command -v gemini &> /dev/null
then
  echo "Gemini CLI not found. Please install it to use this script."
  exit 1
fi

# Call the Gemini CLI with the staged diff and request a brief commit message.
if [ "$VERBOSE" = true ]; then
  echo "Generating commit message with Gemini CLI..."
  COMMIT_MESSAGE=$(git diff --staged | gemini -m "$GEMINI_MODEL" -p "$COMMIT_PROMPT")
else
  show_spinner "$ACTION_SUMMARY" &
  SPINNER_PID=$!
  COMMIT_MESSAGE=$(git diff --staged | gemini -m "$GEMINI_MODEL" -p "$COMMIT_PROMPT" 2>/dev/null)
  kill "$SPINNER_PID" &>/dev/null
  unset SPINNER_PID
  tput cnorm # Restore cursor
  printf "\r%s\n"
fi

# Check if a message was successfully generated
if [[ -z "${COMMIT_MESSAGE}" ]]; then
  echo "Failed to generate a commit message. Exiting."
  exit 1
fi

if [ "$VERBOSE" = true ]; then
  echo "Generated commit message: ${COMMIT_MESSAGE}"
fi

# Perform the commit with the generated message.
if [ "$VERBOSE" = true ]; then
  echo "Committing changes..."
fi
git commit -m "${COMMIT_MESSAGE}"

if [ "$RUN_RELEASE" = true ]; then
    if [ "$VERBOSE" = true ]; then
      echo "Running npm release..."
    fi
    npm run release
fi

if [ "$SUBMODULE_COMMIT" = true ]; then
  # Check if this is a submodule
  SUPERPROJECT_WORK_TREE=$(git rev-parse --show-superproject-working-tree)
  if [ -n "$SUPERPROJECT_WORK_TREE" ]; then
    SUBMODULE_PATH=$(git rev-parse --show-toplevel)
    SUBMODULE_NAME=$(basename "$SUBMODULE_PATH")
    if [ "$VERBOSE" = true ]; then
      echo "Committing submodule changes in parent repository..."
    fi
    (cd "$SUPERPROJECT_WORK_TREE" && git add "$SUBMODULE_PATH" && git commit -m "Update submodule ${SUBMODULE_NAME}")
  fi
fi
