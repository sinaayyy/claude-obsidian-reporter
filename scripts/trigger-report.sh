#!/bin/bash

cd "$(dirname "$0")/.." || exit 1

# --- Load .env if present (for GITHUB_TOKEN, VAULT_NAME, etc.) ---
if [[ -f ".env" ]]; then
  export $(grep -v '^#' .env | xargs)
fi

# --- Corporate SSL bypass (for environments with SSL inspection proxies) ---
export NODE_TLS_REJECT_UNAUTHORIZED=0

# --- Configuration ---
CONFIG_FILE="projects.config"
MODE="${MODE:-daily}"
TARGET_DATE="${TARGET_DATE:-$(date +%Y-%m-%d)}"
FORCE="${FORCE:-false}"

echo "╔══════════════════════════════════════════════════╗"
echo "║        claude-obsidian-reporter                  ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Mode  : $MODE"
echo "║  Date  : $TARGET_DATE"
echo "║  Vault : ${VAULT_NAME:-not set}"
echo "╚══════════════════════════════════════════════════╝"

# --- Argument parsing ---
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --project) PROJECT_NAME="$2"; shift ;;
    --path)    PROJECT_PATH="$2"; shift ;;
    --url)     PROJECT_URL="$2"; shift ;;
    --date)    TARGET_DATE="$2"; shift ;;
    --mode)    MODE="$2"; shift ;;
    --force)   FORCE=true ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# sync_repo: clone or pull a project repo before extracting git log
# Usage: sync_repo <local_path> <git_url>
# ---------------------------------------------------------------------------
sync_repo() {
  local local_path="$1"
  local git_url="$2"

  # No URL provided → assume already present locally, nothing to do
  if [[ -z "$git_url" ]]; then
    if [[ ! -d "$local_path/.git" ]]; then
      echo "[WARN] No git_url and local path '$local_path' is not a git repo. Skipping."
      return 1
    fi
    return 0
  fi

  # Inject GITHUB_TOKEN for private HTTPS repos
  local effective_url="$git_url"
  if [[ "$git_url" == https://* && -n "$GITHUB_TOKEN" ]]; then
    # Insert token: https://TOKEN@github.com/user/repo
    effective_url="${git_url/https:\/\//https://$GITHUB_TOKEN@}"
  fi

  if [[ ! -d "$local_path/.git" ]]; then
    echo "[INFO]   Cloning $git_url → $local_path"
    mkdir -p "$local_path"
    if ! git clone "$effective_url" "$local_path" --quiet 2>&1; then
      echo "[ERROR] Clone failed for $git_url"
      echo "        → Public repo? Check the URL."
      echo "        → Private repo via HTTPS? Set GITHUB_TOKEN in .env"
      echo "        → Private repo via SSH?   Make sure your SSH key is loaded (ssh-add)"
      return 1
    fi
    echo "[OK]   Clone successful."
  else
    echo "[INFO]   Pulling latest commits for $(basename "$local_path")"
    if ! git -C "$local_path" pull "$effective_url" --quiet 2>&1; then
      echo "[WARN] git pull failed for $local_path (continuing with local state)"
    fi
  fi

  return 0
}

# ---------------------------------------------------------------------------
# run_report: sync + trigger claude report for one project
# ---------------------------------------------------------------------------
run_report() {
  local name="$1"
  local path="$2"
  local url="$3"

  echo ""
  echo "[INFO] ══════════════════════════════════════════════"
  echo "[INFO]  Project : $name"
  echo "[INFO]  Mode    : $MODE"
  echo "[INFO]  Date    : $TARGET_DATE"
  echo "[INFO]  Vault   : $VAULT_NAME"
  echo "[INFO] ══════════════════════════════════════════════"

  # --- Sync repo ---
  sync_repo "$path" "$url" || return 1

  # --- Git log preview ---
  echo "[INFO] Extracting git log for $name on $TARGET_DATE..."
  local commits
  commits=$(git -C "$path" log \
    --after="${TARGET_DATE}T00:00:00" \
    --before="${TARGET_DATE}T23:59:59" \
    --pretty=format:"  - %s (%h) by %an" \
    --no-merges 2>/dev/null)
  local nb_commits
  nb_commits=$(echo "$commits" | grep -c "^  -" 2>/dev/null || echo 0)

  if [[ "$nb_commits" -eq 0 ]]; then
    echo "[INFO] No commits found for $TARGET_DATE: will write empty report."
  else
    echo "[INFO] Found $nb_commits commit(s):"
    echo "$commits"
  fi

  # --- Skip if report already exists ---
  local week_num
  week_num=$(date -d "$TARGET_DATE" +%V 2>/dev/null || date -j -f "%Y-%m-%d" "$TARGET_DATE" +%V)
  local year_month
  year_month=$(date -d "$TARGET_DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m)
  local report_file="${VAULT_PATH}/Reports/${name}/${year_month}/W${week_num}/Daily/${name}-${TARGET_DATE}.md"
  if [[ "$MODE" == "daily" && -f "$report_file" && "$FORCE" != "true" ]]; then
    echo "[SKIP] Report already exists: $report_file (use --force to overwrite)"
    return 0
  fi

  # --- Invoke Claude ---
  echo ""
  echo "[INFO] Invoking Claude (report-orchestrator skill)..."
  echo "[INFO] Started at $(date '+%H:%M:%S'): streaming output below:"
  echo "────────────────────────────────────────────────────"
  local start_ts=$SECONDS
  local raw_output
  raw_output=$(env -u ANTHROPIC_API_KEY claude -p --dangerously-skip-permissions \
    --output-format json \
    "report-orchestrator skill. mode=$MODE project=$name path=$path date=$TARGET_DATE vault=$VAULT_NAME language=${LANGUAGE:-English}" 2>/dev/null)
  local exit_code=$?
  local elapsed=$(( SECONDS - start_ts ))

  # Print Claude's text response + usage stats
  # Parse JSON with grep+awk (no jq/python required)
  _json_get() { printf '%s' "$1" | grep -o "\"$2\":[^,}]*" | grep -o '[0-9.]*$'; }
  _tok_k()    { awk "BEGIN{printf \"%.1fk\", $1/1000}"; }

  local turns cost_usd dur_ms dur_s in_t cread_t cwrite_t out_t
  local result
  turns=$(   _json_get "$raw_output" "num_turns")
  cost_usd=$(  _json_get "$raw_output" "total_cost_usd")
  dur_ms=$(  _json_get "$raw_output" "duration_ms")
  dur_s=$(awk "BEGIN{printf \"%.1f\", ${dur_ms:-0}/1000}")
  in_t=$(    _json_get "$raw_output" "input_tokens")
  cread_t=$( printf '%s' "$raw_output" | grep -o '"cache_read_input_tokens":[^,}]*' | grep -o '[0-9]*$')
  cwrite_t=$(printf '%s' "$raw_output" | grep -o '"cache_creation_input_tokens":[^,}]*' | grep -o '[0-9]*$')
  out_t=$(   _json_get "$raw_output" "output_tokens")
  result=$(  printf '%s' "$raw_output" | grep -o '"result":"[^"]*"' | sed 's/"result":"//;s/"$//' | sed 's/\\n/\n/g')

  echo "$result"
  echo ""
  local total_t total_k cost_fmt
  total_t=$(awk "BEGIN{print ${in_t:-0}+${cwrite_t:-0}+${out_t:-0}}")
  total_k=$(_tok_k ${total_t:-0})
  cost_fmt=$(awk "BEGIN{printf \"%.4f\", ${cost_usd:-0}}")
  echo "┌─ Session ─────────────────────────────────────────┐"
  echo "│  tokens (task) : ${total_k}"
  echo "│  cost          : \$${cost_fmt}"
  echo "│  duration      : ${dur_s}s"
  echo "└───────────────────────────────────────────────────┘"

  echo "────────────────────────────────────────────────────"

  if [[ $exit_code -eq 0 ]]; then
    echo "[OK] $name: done in ${elapsed}s."
  else
    echo "[ERROR] $name: Claude exited with code $exit_code after ${elapsed}s."
  fi
}

# --- Single project via args ---
if [[ -n "$PROJECT_NAME" && -n "$PROJECT_PATH" ]]; then
  run_report "$PROJECT_NAME" "$PROJECT_PATH" "$PROJECT_URL"
  exit $?
fi

# --- All projects from config ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: projects.config not found and no --project/--path provided."
  exit 1
fi

while IFS='|' read -r name path url; do
  [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
  run_report "$name" "$path" "$url"
done < "$CONFIG_FILE"
