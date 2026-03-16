#!/bin/bash
# report-orchestrator.sh
# Run at end of day: always daily, weekly on Fridays, monthly on last day of month.
# Usage: bash scripts/report-orchestrator.sh [--date YYYY-MM-DD]

cd "$(dirname "$0")/.." || exit 1

TARGET_DATE="${TARGET_DATE:-$(date +%Y-%m-%d)}"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --date) TARGET_DATE="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# --- Detect day-of-week and last-day-of-month ---
DOW=$(date -d "$TARGET_DATE" +%u 2>/dev/null || date -j -f "%Y-%m-%d" "$TARGET_DATE" +%u 2>/dev/null)
IS_FRIDAY=false
[[ "$DOW" == "5" ]] && IS_FRIDAY=true

YEAR_MONTH=$(date -d "$TARGET_DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m 2>/dev/null)
NEXT_DAY=$(date -d "$TARGET_DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m-%d 2>/dev/null)
NEXT_MONTH=$(date -d "$NEXT_DAY" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$NEXT_DAY" +%Y-%m 2>/dev/null)
IS_LAST_DAY_OF_MONTH=false
[[ "$YEAR_MONTH" != "$NEXT_MONTH" ]] && IS_LAST_DAY_OF_MONTH=true

echo "╔══════════════════════════════════════════════════╗"
echo "║         report-orchestrator                      ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Date      : $TARGET_DATE"
echo "║  Friday    : $IS_FRIDAY"
echo "║  Last day  : $IS_LAST_DAY_OF_MONTH"
echo "╚══════════════════════════════════════════════════╝"

# --- Daily (always) ---
echo ""
echo "▶ Running daily report..."
MODE=daily TARGET_DATE="$TARGET_DATE" bash scripts/trigger-report.sh
DAILY_CODE=$?

# --- Weekly (Fridays only) ---
if [[ "$IS_FRIDAY" == "true" ]]; then
  echo ""
  echo "▶ Friday detected — running weekly report..."
  MODE=weekly TARGET_DATE="$TARGET_DATE" bash scripts/trigger-report.sh
fi

# --- Monthly (last day of month only) ---
if [[ "$IS_LAST_DAY_OF_MONTH" == "true" ]]; then
  echo ""
  echo "▶ Last day of month detected — running monthly report..."
  MODE=monthly TARGET_DATE="$TARGET_DATE" bash scripts/trigger-report.sh
fi

echo ""
echo "✓ Done."
