#!/bin/bash

cd "$(dirname "$0")/.." || exit 1

# --- Configuration ---
CONFIG_FILE="projects.config"
MODE="${MODE:-daily}"

# --- Argument parsing ---
START_DATE=""
END_DATE="$(date +%Y-%m-%d)"

FORCE=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --from)  START_DATE="$2"; shift ;;
    --to)    END_DATE="$2"; shift ;;
    --mode)  MODE="$2"; shift ;;
    --force) FORCE=true ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

if [[ -z "$START_DATE" ]]; then
  echo "ERROR: --from <YYYY-MM-DD> is required."
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: projects.config not found."
  exit 1
fi

echo "[INFO] Catching up from $START_DATE to $END_DATE in $MODE mode"

# --- Iterate over date range ---
current="$START_DATE"
while [[ "$current" < "$END_DATE" || "$current" == "$END_DATE" ]]; do
  echo "[INFO] Processing date: $current"

  while IFS='|' read -r name path url; do
    [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue

    echo "[INFO]   → Project: $name at $path"

    TARGET_DATE="$current" MODE="$MODE" FORCE="$FORCE" PROJECT_NAME="$name" PROJECT_PATH="$path" \
      bash "$(dirname "$0")/trigger-report.sh" \
        --project "$name" \
        --path "$path" \
        --date "$current" \
        --mode "$MODE" \
        $( [[ "$FORCE" == "true" ]] && echo "--force" )

    # Brief pause to avoid hammering the API
    sleep 5

  done < "$CONFIG_FILE"

  # Advance to next day
  current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -j -f "%Y-%m-%d" "$current" +%Y-%m-%d)

done

echo "[DONE] Catch-up complete from $START_DATE to $END_DATE."
