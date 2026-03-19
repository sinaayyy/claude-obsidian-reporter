#!/bin/bash
# check-vault.sh
# Validates the Obsidian vault structure: detects phantom nodes, broken parent
# links, missing aggregate reports, and zero-commit reports.
# Usage: bash scripts/check-vault.sh

cd "$(dirname "$0")/.." || exit 1

source .env 2>/dev/null || { echo "ERROR: .env not found"; exit 1; }

: "${VAULT_PATH:?VAULT_PATH is not set in .env}"

REPORTS="$VAULT_PATH/Reports"
ERRORS=0
WARNINGS=0

err()  { echo "  [ERROR]   $*"; (( ERRORS++ )); }
warn() { echo "  [WARN]    $*"; (( WARNINGS++ )); }
ok()   { echo "  [OK]      $*"; }

# Resolve wikilink path to an actual file path
# [[PROJECT/Y-2026/M-03/W-1/W-1]] → $REPORTS/PROJECT/Y-2026/M-03/W-1/W-1.md
resolve_link() {
  local raw
  raw=$(echo "$1" | grep -oP '(?<=\[\[)[^\]]+(?=\]\])')
  echo "$REPORTS/$raw.md"
}

echo "╔══════════════════════════════════════════════════╗"
echo "║  check-vault — vault conformity check            ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Vault: $VAULT_PATH"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── 1. Dashboard ────────────────────────────────────────────────────────────
echo "── Dashboard"
if [[ -f "$REPORTS/Dashboard.md" ]]; then
  ok "Dashboard.md exists"
else
  err "Dashboard.md missing — run the skill once to bootstrap it"
fi
echo ""

# ── 2. Per-project checks ────────────────────────────────────────────────────
while IFS='|' read -r name path url branches tags || [[ -n "$name" ]]; do
  [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
  name=$(echo "$name" | tr -d ' ')

  echo "── Project: $name"
  PROJECT_DIR="$REPORTS/$name"

  # 2a. Project index
  INDEX="$PROJECT_DIR/$name.md"
  if [[ ! -f "$INDEX" ]]; then
    err "$name/$name.md missing (project index)"
  else
    parent=$(grep -E "^parent:" "$INDEX" | head -1)
    target=$(resolve_link "$parent")
    if [[ ! -f "$target" ]]; then
      err "$name/$name.md — broken parent link: $parent → file not found"
    else
      ok "$name/$name.md — parent OK"
    fi
    commits_val=$(grep -E "^commits:" "$INDEX" | awk '{print $2}')
    # project index has no commits field — skip
  fi

  # 2b. Walk Y-YYYY/
  for year_dir in "$PROJECT_DIR"/Y-[0-9][0-9][0-9][0-9]; do
    [[ -d "$year_dir" ]] || continue
    Y=$(basename "$year_dir")
    yearly="$year_dir/$Y.md"

    # Phantom check: folder exists but no yearly report
    if [[ ! -f "$yearly" ]]; then
      err "$name/$Y/ — folder exists but $Y.md is missing (phantom folder)"
    else
      # Broken parent link
      parent=$(grep -E "^parent:" "$yearly" | head -1)
      target=$(resolve_link "$parent")
      if [[ ! -f "$target" ]]; then
        err "$name/$Y/$Y.md — broken parent: $parent"
      fi
      # Zero commits
      c=$(grep -E "^commits:" "$yearly" | awk '{print $2}')
      [[ "$c" == "0" ]] && err "$name/$Y/$Y.md — commits: 0 (should not exist)"
    fi

    # 2c. Walk M-MM/
    for month_dir in "$year_dir"/M-[0-9][0-9]; do
      [[ -d "$month_dir" ]] || continue
      M=$(basename "$month_dir")
      monthly="$month_dir/$M.md"

      if [[ ! -f "$monthly" ]]; then
        err "$name/$Y/$M/ — folder exists but $M.md is missing (phantom folder)"
      else
        parent=$(grep -E "^parent:" "$monthly" | head -1)
        target=$(resolve_link "$parent")
        if [[ ! -f "$target" ]]; then
          err "$name/$Y/$M/$M.md — broken parent: $parent"
        fi
        c=$(grep -E "^commits:" "$monthly" | awk '{print $2}')
        [[ "$c" == "0" ]] && err "$name/$Y/$M/$M.md — commits: 0 (should not exist)"
      fi

      # 2d. Walk W-N/
      for week_dir in "$month_dir"/W-[0-9]; do
        [[ -d "$week_dir" ]] || continue
        W=$(basename "$week_dir")
        weekly="$week_dir/$W.md"

        if [[ ! -f "$weekly" ]]; then
          err "$name/$Y/$M/$W/ — folder exists but $W.md is missing (phantom folder)"
        else
          parent=$(grep -E "^parent:" "$weekly" | head -1)
          target=$(resolve_link "$parent")
          if [[ ! -f "$target" ]]; then
            err "$name/$Y/$M/$W/$W.md — broken parent: $parent"
          fi
          c=$(grep -E "^commits:" "$weekly" | awk '{print $2}')
          [[ "$c" == "0" ]] && err "$name/$Y/$M/$W/$W.md — commits: 0 (should not exist)"
        fi

        # 2e. Walk D-DD.md
        for daily in "$week_dir"/D-[0-9][0-9].md; do
          [[ -f "$daily" ]] || continue
          D=$(basename "$daily")
          parent=$(grep -E "^parent:" "$daily" | head -1)
          target=$(resolve_link "$parent")
          if [[ ! -f "$target" ]]; then
            err "$name/$Y/$M/$W/$D — broken parent: $parent"
          fi
          c=$(grep -E "^commits:" "$daily" | awk '{print $2}')
          [[ "$c" == "0" ]] && err "$name/$Y/$M/$W/$D — commits: 0 (should not exist)"
        done

        # 2f. Orphan files in week folder (not D-DD.md and not W-N.md)
        for f in "$week_dir"/*.md; do
          [[ -f "$f" ]] || continue
          base=$(basename "$f")
          [[ "$base" == "$W.md" ]] && continue
          [[ "$base" =~ ^D-[0-9]{2}\.md$ ]] && continue
          warn "$name/$Y/$M/$W/$base — unexpected file in week folder"
        done
      done

      # 2g. Orphan files in month folder (not M-MM.md and not W-N/)
      for f in "$month_dir"/*.md; do
        [[ -f "$f" ]] || continue
        base=$(basename "$f")
        [[ "$base" == "$M.md" ]] && continue
        warn "$name/$Y/$M/$base — unexpected file in month folder"
      done
    done

    # 2h. Orphan files in year folder (not Y-YYYY.md and not M-MM/)
    for f in "$year_dir"/*.md; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f")
      [[ "$base" == "$Y.md" ]] && continue
      warn "$name/$Y/$base — unexpected file in year folder"
    done
  done

  echo ""
done < projects.config

# ── 3. Summary ───────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════╗"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "║  ✓ Vault is clean — no issues found              ║"
elif [[ $ERRORS -eq 0 ]]; then
  echo "║  ✓ No errors — $WARNINGS warning(s)$(printf '%*s' $((40 - ${#WARNINGS})) '')║"
else
  echo "║  ✗ $ERRORS error(s)  $WARNINGS warning(s)$(printf '%*s' $((35 - ${#ERRORS} - ${#WARNINGS})) '')║"
fi
echo "╚══════════════════════════════════════════════════╝"

[[ $ERRORS -gt 0 ]] && exit 1 || exit 0
