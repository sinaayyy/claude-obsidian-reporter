#!/bin/bash
# check-vault.sh
# Validates the Obsidian vault graph structure:
#   - phantom folders (aggregate .md missing)
#   - cross-hierarchy parent links (daily → wrong week, week → wrong month, etc.)
#   - broken parent links (target file does not exist)
#   - broken Current/ pointers
#   - zero-commit reports
#   - unexpected files at each level
#   - missing or wrong tags (breaks graph coloring)
# Usage: bash scripts/check-vault.sh

cd "$(dirname "$0")/.." || exit 1

source .env 2>/dev/null || { echo "ERROR: .env not found"; exit 1; }
: "${VAULT_PATH:?VAULT_PATH is not set in .env}"

REPORTS="$VAULT_PATH/Reports"
ERRORS=0
WARNINGS=0
PROJECT_ERRORS=0
PROJECT_WARNINGS=0

err()  { echo "    [ERROR] $*"; (( ERRORS++ )); (( PROJECT_ERRORS++ )); }
warn() { echo "    [WARN]  $*"; (( WARNINGS++ )); (( PROJECT_WARNINGS++ )); }

# Extract wikilink target from a "parent: [[...]]" or "[[...]]" line
extract_link() { echo "$1" | grep -oP '(?<=\[\[)[^\|\]]+'; }

# Validate parent field of a file against the expected wikilink target.
# Prints nothing on success: errors only.
check_parent() {
  local file="$1" expected="$2" label="$3"
  local raw actual

  raw=$(grep -m1 "^parent:" "$file" 2>/dev/null)
  if [[ -z "$raw" ]]; then
    err "$label: missing parent field"
    return
  fi

  actual=$(extract_link "$raw")
  if [[ "$actual" != "$expected" ]]; then
    err "$label: cross-hierarchy parent: got [[$actual]], expected [[$expected]]"
    return
  fi

  if [[ ! -f "$REPORTS/$expected.md" ]]; then
    err "$label: parent [[$expected]] target does not exist"
  fi
}

# Check that required tags are present in the frontmatter tags field.
# $1 = file  $2 = label  $3... = required tags (e.g. "report/daily" "project/MyApp")
check_tags() {
  local file="$1" label="$2"; shift 2
  local tags_line
  tags_line=$(grep -m1 "^tags:" "$file" 2>/dev/null)
  if [[ -z "$tags_line" ]]; then
    err "$label: missing tags field (graph coloring will not work)"
    return
  fi
  for tag in "$@"; do
    if ! echo "$tags_line" | grep -q "$tag"; then
      err "$label: missing tag '$tag' in frontmatter (graph coloring broken)"
    fi
  done
}

# Check commits frontmatter: errors if 0 (file should not exist)
check_commits() {
  local file="$1" label="$2"
  local c
  c=$(grep -m1 "^commits:" "$file" | awk '{print $2}')
  [[ "$c" == "0" ]] && err "$label: commits: 0 (report should not have been written)"
}

echo "╔══════════════════════════════════════════════════╗"
echo "║  check-vault: vault conformity check            ║"
echo "╠══════════════════════════════════════════════════╣"
printf  "║  Vault: %-41s║\n" "$VAULT_PATH"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── 1. Dashboard ─────────────────────────────────────────────────────────────
echo "── Dashboard"
[[ -f "$REPORTS/Dashboard.md" ]] \
  && echo "    OK" \
  || { echo "    [ERROR] Dashboard.md missing: run the skill once to bootstrap it"; (( ERRORS++ )); }
echo ""

# ── 2. Current/ pointers ─────────────────────────────────────────────────────
echo "── Current/"
CURRENT_ISSUES=0
for ptr in "$REPORTS/Current/"*.md; do
  [[ -f "$ptr" ]] || continue
  base=$(basename "$ptr")
  link=$(extract_link "$(cat "$ptr")")
  if [[ -z "$link" ]]; then
    err "Current/$base: no wikilink found"; (( CURRENT_ISSUES++ ))
  elif [[ ! -f "$REPORTS/$link.md" ]]; then
    err "Current/$base: points to [[$link]] which does not exist"; (( CURRENT_ISSUES++ ))
  fi
done
[[ $CURRENT_ISSUES -eq 0 ]] && echo "    OK"
echo ""

# ── 3. Per-project checks ────────────────────────────────────────────────────
while IFS='|' read -r name path url branches tags || [[ -n "$name" ]]; do
  [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
  name=$(echo "$name" | tr -d ' ')
  PROJECT_ERRORS=0; PROJECT_WARNINGS=0

  PROJECT_DIR="$REPORTS/$name"

  # Project index: parent must be exactly [[Dashboard]]
  INDEX="$PROJECT_DIR/$name.md"
  if [[ ! -f "$INDEX" ]]; then
    err "$name/$name.md missing (project index)"
  else
    check_parent "$INDEX" "Dashboard" "$name/$name.md"
    check_tags   "$INDEX" "$name/$name.md" "project/$name"
  fi

  # Walk Y-YYYY/
  for year_dir in "$PROJECT_DIR"/Y-[0-9][0-9][0-9][0-9]; do
    [[ -d "$year_dir" ]] || continue
    Y=$(basename "$year_dir")

    # Phantom folder
    if [[ ! -f "$year_dir/$Y.md" ]]; then
      err "$name/$Y/: phantom folder ($Y.md missing)"
    else
      check_parent "$year_dir/$Y.md" "$name/$name" "$name/$Y/$Y.md"
      check_tags   "$year_dir/$Y.md" "$name/$Y/$Y.md" "report/yearly" "project/$name"
      check_commits "$year_dir/$Y.md" "$name/$Y/$Y.md"
    fi

    # Unexpected files in year folder
    for f in "$year_dir"/*.md; do
      [[ -f "$f" ]] || continue
      [[ "$(basename "$f")" == "$Y.md" ]] && continue
      warn "$name/$Y/$(basename "$f"): unexpected file in year folder"
    done

    # Walk M-MM/
    for month_dir in "$year_dir"/M-[0-9][0-9]; do
      [[ -d "$month_dir" ]] || continue
      M=$(basename "$month_dir")

      if [[ ! -f "$month_dir/$M.md" ]]; then
        err "$name/$Y/$M/: phantom folder ($M.md missing)"
      else
        check_parent "$month_dir/$M.md" "$name/$Y/$Y" "$name/$Y/$M/$M.md"
        check_tags   "$month_dir/$M.md" "$name/$Y/$M/$M.md" "report/monthly" "project/$name"
        check_commits "$month_dir/$M.md" "$name/$Y/$M/$M.md"
      fi

      for f in "$month_dir"/*.md; do
        [[ -f "$f" ]] || continue
        [[ "$(basename "$f")" == "$M.md" ]] && continue
        warn "$name/$Y/$M/$(basename "$f"): unexpected file in month folder"
      done

      # Walk W-NN/ (ISO week numbers: W-01 to W-52, or within-month W-1 to W-5)
      for week_dir in "$month_dir"/W-[0-9]*; do
        [[ -d "$week_dir" ]] || continue
        W=$(basename "$week_dir")

        if [[ ! -f "$week_dir/$W.md" ]]; then
          err "$name/$Y/$M/$W/: phantom folder ($W.md missing)"
        else
          check_parent "$week_dir/$W.md" "$name/$Y/$M/$M" "$name/$Y/$M/$W/$W.md"
          check_tags   "$week_dir/$W.md" "$name/$Y/$M/$W/$W.md" "report/weekly" "project/$name"
          check_commits "$week_dir/$W.md" "$name/$Y/$M/$W/$W.md"
        fi

        # Walk D-DD.md
        for daily in "$week_dir"/D-[0-9][0-9].md; do
          [[ -f "$daily" ]] || continue
          D=$(basename "$daily")
          # Daily parent must be [[NAME/Y-YYYY/M-MM/W-N/W-N]]
          check_parent "$daily" "$name/$Y/$M/$W/$W" "$name/$Y/$M/$W/$D"
          check_tags   "$daily" "$name/$Y/$M/$W/$D" "report/daily" "project/$name"
          check_commits "$daily" "$name/$Y/$M/$W/$D"
        done

        # Unexpected files in week folder
        for f in "$week_dir"/*.md; do
          [[ -f "$f" ]] || continue
          base=$(basename "$f")
          [[ "$base" == "$W.md" ]] && continue
          [[ "$base" =~ ^D-[0-9]{2}\.md$ ]] && continue
          warn "$name/$Y/$M/$W/$base: unexpected file in week folder"
        done
      done
    done
  done

  if [[ $PROJECT_ERRORS -eq 0 && $PROJECT_WARNINGS -eq 0 ]]; then
    echo "── $name: OK"
  else
    echo "── $name: $PROJECT_ERRORS error(s), $PROJECT_WARNINGS warning(s)"
  fi
  echo ""

done < projects.config

# ── 4. Summary ────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════╗"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "║  ✓ Vault is clean: no issues found              ║"
elif [[ $ERRORS -eq 0 ]]; then
  printf "║  ✓ No errors: %d warning(s)%-23s║\n" "$WARNINGS" ""
else
  printf "║  ✗ %d error(s), %d warning(s)%-27s║\n" "$ERRORS" "$WARNINGS" ""
fi
echo "╚══════════════════════════════════════════════════╝"

[[ $ERRORS -gt 0 ]] && exit 1 || exit 0
