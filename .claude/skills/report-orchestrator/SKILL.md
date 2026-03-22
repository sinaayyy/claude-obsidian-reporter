---
name: report-orchestrator
description: End-of-day skill for Claude Code: generates daily, weekly, monthly, and yearly Git activity reports into your Obsidian vault. Auto-detects end of week (weekly), last day of month (monthly), and Dec 31 (yearly). Supports multiple languages.
allowed-tools: Bash, Read
---

# report-orchestrator
<description>End-of-day report skill: generates daily, weekly, monthly, and yearly reports on every run (all overwritten with period-to-date commits). Structure: PROJECT/Y-YYYY/Y-YYYY.md, M-MM/M-MM.md, W-NN/W-NN.md, D-DD.md for daily.</description>
<instructions>

You are the end-of-day report orchestrator. You run entirely within this Claude session: no subprocesses, no background tasks.

## Input (optional)
- `date`: YYYY-MM-DD (defaults to today if not provided)
- `language`: language for all generated text (defaults to `English`)
- `backfill`: YYYY-MM-DD or `all`: if provided, generate all missing reports from that date up to `$DATE` before running the normal flow
- `tags`: comma-separated extra tags to add to all reports in this run (e.g. `tags=client/acme,sprint/42`)
- `check`: run vault conformity audit only (no reports generated): see [Check mode](#check-mode)
- `fix`: run audit then auto-fix all detected issues: see [Fix mode](#fix-mode)
- `add-project`: add a project to `projects.config`: see [Add-project mode](#add-project-mode)
- `remove-project`: remove a project from `projects.config`: see [Remove-project mode](#remove-project-mode)
- `discover`: scan local directories for git repos not yet in `projects.config`: see [Discover mode](#discover-mode)
- `status`: show the reporting status of every tracked project directly from the vault: see [Status mode](#status-mode)

If any of `check`, `fix`, `add-project`, `remove-project`, `discover`, `status` is present, **skip the normal report flow entirely** and jump to the corresponding mode.

## Vault structure

```
Reports/
├── Current/
│   └── PROJECT.md                    ← today's daily (overwritten on every run)
└── PROJECT/
    └── Y-YYYY/                       ← yearly folder
        ├── Y-YYYY.md          ← yearly report (node shows "Y-2026" in graph)
        └── M-MM/                     ← monthly folder
            ├── M-MM.md          ← monthly report (node shows "M-03" in graph)
            └── W-NN/                 ← weekly folder
                ├── W-NN.md      ← weekly report (node shows "W-1" to "W-5" in graph)
                └── D-DD.md           ← daily report (no project prefix needed)
```

Examples:
- `Reports/Current/ProjectAlpha.md`
- `Reports/ProjectAlpha/Y-2026/Y-2026.md`
- `Reports/ProjectAlpha/Y-2026/M-03/M-03.md`
- `Reports/ProjectAlpha/Y-2026/M-03/W-12/W-12.md`
- `Reports/ProjectAlpha/Y-2026/M-03/W-12/D-18.md`

## Step 1: Resolve language and date

```bash
LANGUAGE="${language:-English}"
```

Write all report content (section headings, summaries, highlights) in `$LANGUAGE`. Keep frontmatter keys and values in English regardless of language (they are metadata, not prose).

## Step 2: Resolve date and detect which reports to run

```bash
DATE="${date:-$(date +%Y-%m-%d)}"

# Read WEEK_END_DAY from .env (default: 5 = Friday)
WEEK_END_DAY=$(grep -E "^WEEK_END_DAY=" .env 2>/dev/null | cut -d= -f2 | tr -d ' ')
WEEK_END_DAY="${WEEK_END_DAY:-5}"

DOW=$(date -d "$DATE" +%u 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%u)
NEXT=$(date -d "$DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
WEEK_START=$(date -d "$DATE - $(( DOW - 1 )) days" +%Y-%m-%d 2>/dev/null || date -j -v-$(( DOW - 1 ))d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
YEAR_MONTH=$(date -d "$DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y-%m)
YEAR=$(date -d "$DATE" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y)
MONTH=$(date -d "$DATE" +%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%m)
DAY=$(date -d "$DATE" +%d 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%d)
WEEK_NUM=$(( (10#$DAY - 1) / 7 + 1 ))   # week within the month: 1–5
IS_WEEK_END=$([ "$DOW" = "$WEEK_END_DAY" ] && echo true || echo false)
IS_LAST_DAY=$([ "$(date -d "$DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y-%m)" != "$(date -d "$NEXT" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$NEXT" +%Y-%m)" ] && echo true || echo false)
IS_LAST_YEAR=$([ "$(date -d "$DATE" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y)" != "$(date -d "$NEXT" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$NEXT" +%Y)" ] && echo true || echo false)
```

Always run: **daily**, **weekly**, **monthly**, **yearly**: all four are written on every run with period-to-date commits and overwritten each time. `IS_WEEK_END`, `IS_LAST_DAY`, `IS_LAST_YEAR` are only used during **catchup** to know whether to generate period-end reports for past closed periods.

## Step 3: Load projects

Read `projects.config` (format: `ProjectName|/absolute/path|optional_git_url|optional_branches|optional_tags`, lines starting with `#` are comments).

- `optional_tags`: comma-separated tags specific to this project (e.g. `client/acme,team/backend`). Added to every report generated for this project.

- `optional_branches`: comma-separated list of branches to include (e.g. `main,develop`). If omitted, defaults to `main,master,develop,dev` (only branches that actually exist in the repo are used).

**Resolve branches for a project:**
```bash
# Get configured branches (or defaults)
CONFIGURED="${branches:-main,master,develop,dev}"

# Keep only branches that exist in the repo
BRANCH_ARGS=""
for b in $(echo "$CONFIGURED" | tr ',' ' '); do
  git -C "$path" rev-parse --verify "$b" &>/dev/null && BRANCH_ARGS="$BRANCH_ARGS $b"
done

# If none exist, fall back to HEAD (unfiltered)
[ -z "$BRANCH_ARGS" ] && BRANCH_ARGS="HEAD"
```

## Step 3c: Build tags for each report

For each project and each report type, build the `{{tags}}` value as a YAML inline array:

1. **Base tags**: always included:
   - Daily: `report/daily`, `project/PROJECT`
   - Weekly: `report/weekly`, `project/PROJECT`
   - Monthly: `report/monthly`, `project/PROJECT`
   - Yearly: `report/yearly`, `project/PROJECT`

2. **Project tags**: from the 5th column of `projects.config` (comma-separated). Include all of them.

3. **Run-level tags**: from the `tags` input parameter (comma-separated). Applied to all projects in this run.

Merge all three, deduplicate, then format as a YAML inline array. Tags containing `/` must be quoted:

```
# Example: base=[report/daily, project/MyApp]  project_tags=[client/acme]  run_tags=[sprint/42]
# Result:
tags: [report/daily, "project/MyApp", "client/acme", "sprint/42"]

# No extra tags:
tags: [report/daily, "project/MyApp"]
```

Rule: quote any tag that contains `/` or special characters. Plain alphanumeric tags can be unquoted.

## Step 3b: Bootstrap dashboard (first run only)

Check if the dashboard exists:
```bash
obsidian vault="VAULT" file path="Reports/Dashboard.md"
```

- If it **does not exist** → bookmark it after creation:
```bash
obsidian vault="VAULT" bookmark path="Reports/Dashboard.md" title="Working"
```

The dashboard is always overwritten at the end of each run (Step 6) with a fresh cross-project summary: see Step 6.

## Step 4: Catchup missing days

### Determine catchup range

- If `backfill` is **not provided** → catchup range = `WEEK_START` to `DATE - 1 day` (current week only)
- If `backfill=YYYY-MM-DD` → catchup range = that date to `DATE - 1 day`
- If `backfill=all` → get the earliest commit date across all projects, use that as start:
```bash
git -C <path> log --reverse --pretty=format:"%ad" --date=format:"%Y-%m-%d" | head -1
```
Take the earliest date across all projects as the catchup start.

### Process each day in the range

```bash
current=$CATCHUP_START
while [[ "$current" < "$DATE" ]]; do
  echo "$current"
  current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
done
```

For each day and each project, check if the daily report already exists:
```bash
obsidian vault="VAULT" file path="Reports/PROJECT/Y-YYYY/M-MM/W-NN/D-DD.md"
```

If the file **exists**, check whether it is stale by comparing the actual commit count with the value stored in the report frontmatter:
```bash
# Actual commits for that day
ACTUAL=$(git -C "$path" log $BRANCH_ARGS \
  --after="${PAST_DATE}T00:00:00" --before="${PAST_DATE}T23:59:59" \
  --pretty=format:"%h" --no-merges | wc -l | tr -d ' ')

# Commits recorded in the existing report (read the file then grep nb_commits)
RECORDED=$(obsidian vault="VAULT" read path="Reports/PROJECT/Y-YYYY/M-MM/W-NN/D-DD.md" \
  | grep -E "^nb_commits:" | awk '{print $2}')
```

- If `ACTUAL == RECORDED` → skip (report is up to date)
- If `ACTUAL != RECORDED` → regenerate (new commits were added after the report was written)
- If the file **does not exist** → generate the daily report **and**:
  - If that day is the **week-end day** (matches WEEK_END_DAY) → also generate the weekly report for that week (if not already generated)
  - If that day is the **last day of its month** → also generate the monthly report for that month (if not already generated)
  - If that day is the **last day of its year** (Dec 31) → also generate the yearly report for that year (if not already generated)

Also bootstrap the project index page if it doesn't exist yet (same logic as monthly step).

List caught-up days in the final summary.

## Step 5: For each project, run all required reports in sequence

### 3a. Sync repo

Four cases, resolved in this order:

```bash
# Case 1 — remote-only (url set, path empty or absent)
# Auto-managed bare clone in .cache/PROJECT.git — no working tree, blobs skipped
CACHE_PATH=".cache/${name}.git"
if [ ! -d "$CACHE_PATH" ]; then
  git clone --bare --filter=blob:none "$url" "$CACHE_PATH"
else
  git --git-dir="$CACHE_PATH" fetch --filter=blob:none
fi
# Use CACHE_PATH as the git dir for all subsequent log commands:
# git --git-dir="$CACHE_PATH" log $BRANCH_ARGS ...

# Case 2 — url set, path exists: pull
git -C "$path" pull

# Case 3 — url not set, path exists, has a remote: pull
HAS_REMOTE=$(git -C "$path" remote 2>/dev/null | head -1)
[ -n "$HAS_REMOTE" ] && git -C "$path" pull

# Case 4 — local-only repo (no url, no remote): skip sync, read log directly
```

For Case 1, adapt all `git -C "$path"` log commands to `git --git-dir="$CACHE_PATH"` for this project.

Resolve `$BRANCH_ARGS` for this project as described in Step 3 before extracting git log.

### 3b. Extract git log

For each period, after extracting the commit list, also extract:

```bash
# Contributors for the period (distinct author names, YAML inline array)
CONTRIBUTORS_RAW=$(git -C "$path" log $BRANCH_ARGS --after="..." --before="..." \
  --no-merges --pretty=format:"%an" | sort -u)
# Format as YAML inline array: ["Alice", "Bob"]
CONTRIBUTORS_YAML=$(echo "$CONTRIBUTORS_RAW" | awk 'BEGIN{printf "["} NR>1{printf ", "} {printf "\"%s\"", $0} END{print "]"}')

# Diff stats for the period
STAT_LINE=$(git -C "$path" log $BRANCH_ARGS --after="..." --before="..." \
  --no-merges --shortstat --pretty=format:"" | grep -E "file" | tail -1)
FILES_CHANGED=$(echo "$STAT_LINE" | grep -oE "[0-9]+ file" | grep -oE "^[0-9]+")
INSERTIONS=$(echo "$STAT_LINE" | grep -oE "[0-9]+ insertion" | grep -oE "^[0-9]+")
DELETIONS=$(echo "$STAT_LINE" | grep -oE "[0-9]+ deletion" | grep -oE "^[0-9]+")
FILES_CHANGED="${FILES_CHANGED:-0}"
INSERTIONS="${INSERTIONS:-0}"
DELETIONS="${DELETIONS:-0}"

# Timestamp of generation
GENERATED_AT=$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S")
```

These values fill `{{contributors}}`, `{{files_changed}}`, `{{insertions}}`, `{{deletions}}`, `{{generated_at}}` for the current report. Replace `...` with the actual after/before bounds for each period.

**Daily**: commits on `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${DATE}T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) by %an" --no-merges
```

**Weekly**: commits from `$WEEK_START` to `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${WEEK_START}T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) by %an" --no-merges
```

**Monthly**: commits from first day of month to `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${YEAR_MONTH}-01T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) by %an" --no-merges
```

**Monthly chart data** (for `{{chart_monthly_labels}}` / `{{chart_monthly_data}}`):
```bash
# Commit count per day of the current month
git -C "$path" log $BRANCH_ARGS --after="${YEAR_MONTH}-01T00:00:00" --before="${DATE}T23:59:59" \
  --no-merges --pretty=format:"%ad" --date=format:"%d" | sort | uniq -c
# Build two arrays: labels = ["01","02",...], data = [N,N,...]
# Fill 0 for days with no commits up to today
```

**Yearly**: commits from Jan 1 of the year to `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${YEAR}-01-01T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) by %an" --no-merges
```

**Thin commit fallback:** after extracting the log, check whether the commit messages are meaningful. A commit message is considered thin if it is empty, a single generic word (`fix`, `wip`, `update`, `test`, `commit`, `save`, `misc`, `temp`, `.`, `...`), or shorter than 10 characters. If **more than half** the commits in the period are thin, supplement the log with file-level context:

```bash
# For each thin commit hash, get the list of changed files
git -C "$path" show --stat --no-merges <hash>
# or for the whole period at once:
git -C "$path" log $BRANCH_ARGS --after="..." --before="..." \
  --no-merges --name-only --pretty=format:"--- %h %s"
```

Use the changed file names and paths to infer what was worked on (e.g. `src/auth/login.ts` → authentication, `docs/api.md` → documentation). Incorporate these inferences into `{{resume_taches}}` and `{{liste_commits}}`. Do not fabricate details: only state what the files suggest. Flag thin commits in the list with a note like `- wip (a3f1c2) [files: login.ts, session.ts]`.

This rule applies to **all report types**: if 0 commits for the period, **skip writing the report entirely**. Do not create the file. A note with no commits would appear as a detached node in the graph.

- Daily with 0 commits → no file
- Weekly with 0 commits across the whole week → no file
- Monthly with 0 commits across the whole month → no file
- Yearly with 0 commits across the whole year → no file

### 3c. Write reports to Obsidian

Note: `overwrite` is a flag without `--`. `vault=` must always be the first argument.

Load the user's templates from the `Templates/` folder:
```bash
cat Templates/daily-report-template.md
cat Templates/weekly-report-template.md
cat Templates/monthly-report-template.md
cat Templates/yearly-report-template.md
```

Fill in the `{{placeholder}}` variables from each template with the actual values, then write to Obsidian. Users can customize the report structure by editing those files.

**Placeholder reference:**

| Placeholder | Value |
|---|---|
| `{{project}}` | project name |
| `{{tags}}` | full YAML inline array of tags: base + project tags + run tags (see Step 3c) |
| `{{date}}` | YYYY-MM-DD |
| `{{week}}` | ISO week number (e.g. 12) |
| `{{month}}` | YYYY-MM |
| `{{year}}` | YYYY |
| `{{nb_commits}}` | commit count for the period |
| `{{files_changed}}` | number of files changed in the period (integer, 0 if none) |
| `{{insertions}}` | lines inserted in the period (integer, 0 if none) |
| `{{deletions}}` | lines deleted in the period (integer, 0 if none) |
| `{{contributors}}` | YAML inline array of distinct author names for the period: `["Alice", "Bob"]` |
| `{{branches}}` | YAML inline array of active branches for this project: e.g. `["main", "develop"]` |
| `{{generated_at}}` | ISO-8601 timestamp of report generation: `2026-03-22T18:30:00+01:00` |
| `{{status}}` | `success` |
| `{{liste_commits}}` | formatted commit list (never empty: reports with 0 commits are not written) |
| `{{resume_taches}}` | prose summary in `$LANGUAGE`: **single line, no newlines** (rendered inside a `> [!summary]` callout): tone and abstraction scale strictly with level: **daily** = terse, first-person, task movement ("shipped X", "investigating Y", "blocked on Z"): 2-3 sentences, subject is *I*; **weekly** = professional, team-level framing, individual tasks compressed into outcomes ("the team delivered X", "carried over Y due to Z"): 2-3 sentences, subject is *the team*; **monthly** = measured, data-grounded, outcome vs. plan framing, trends and risks surfacing ("delivery was on track / behind, tech debt in area X is accumulating"): 3-4 sentences, subject is *the workstream*; **yearly** = narrative and reflective, thematic not chronological, acknowledges difficulty alongside wins ("the year was defined by X, we built Y, we learned Z"): 3-5 sentences, subject is *the project* |
| `{{highlights}}` | key items in `$LANGUAGE`: one bullet per line, each starting with `> - ` (rendered inside a `> [!check]` callout): used in weekly, monthly, and yearly: **weekly** = 2-3 concrete deliverables or unblocked blockers; **monthly** = 3-5 delivery milestones, risk items, or tech debt flags: include red signals openly, not just wins; **yearly** = 5-7 thematic achievements or shifts: compress projects into named outcomes with one-sentence impact |
| `{{notes}}` | leave empty |
| `{{first_commit}}` | earliest commit date across all time (YYYY-MM-DD): project index only |
| `{{total_commits}}` | total commit count across all time: project index only |
| `{{active_years}}` | comma-separated years with at least one commit: project index only |
| `{{health}}` | `green`, `yellow`, or `red`: project index only — computed in Step 6c |
| `{{health_details}}` | one-line health summary: e.g. `"142 commits (30d) \| 3 contributors \| velocity +12%"`: project index only |
| `{{chart_monthly_labels}}` | JSON array of day strings for monthly chart: `["01","02",...,"22"]` |
| `{{chart_monthly_data}}` | JSON array of commit counts per day: `[3,0,5,...]` |
| `{{chart_lifetime_labels}}` | JSON array of YYYY-MM strings for project-index lifetime chart |
| `{{chart_lifetime_data}}` | JSON array of commit counts per month for project-index lifetime chart |
| `{{daily_links}}` | wikilinks to daily reports (weekly template only) |
| `{{weekly_links}}` | wikilinks to weekly reports (monthly template only) |
| `{{monthly_links}}` | wikilinks to monthly reports (yearly template only) |
| `{{parent_weekly}}` | used as `parent` in the **daily** template: points to the weekly summary: `PROJECT/Y-YYYY/M-MM/W-NN/W-NN` |
| `{{parent_monthly}}` | used as `parent` in the **weekly** template: points to the monthly summary: `PROJECT/Y-YYYY/M-MM/M-MM` |
| `{{parent_yearly}}` | used as `parent` in the **monthly** template: points to the yearly summary: `PROJECT/Y-YYYY/Y-YYYY` |
| `{{parent_project}}` | used as `parent` in the **yearly** template: points to the project index: `PROJECT/PROJECT` |

**Placeholder values to fill in (replace PROJECT, Y-YYYY, M-MM, W-NN with actual values):**

| Placeholder | Value |
|---|---|
| `{{parent_weekly}}` | `PROJECT/Y-YYYY/M-MM/W-NN/W-NN` |
| `{{parent_monthly}}` | `PROJECT/Y-YYYY/M-MM/M-MM` |
| `{{parent_yearly}}` | `PROJECT/Y-YYYY/Y-YYYY` |
| `{{parent_project}}` | `PROJECT/PROJECT` |

**Daily** (always):

Paths:
- `Reports/PROJECT/Y-YYYY/M-MM/W-NN/D-DD.md`  ← archived in weekly folder
- `Reports/Current/PROJECT.md`                               ← always the latest daily (overwritten)

Commands:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/Y-YYYY/M-MM/W-NN/D-DD.md" content="..." overwrite
obsidian vault="VAULT" create path="Reports/Current/PROJECT.md" content="[[PROJECT/Y-YYYY/M-MM/W-NN/D-DD]]" overwrite
```

**Weekly** (always: overwritten every run with week-to-date commits):

Path: `Reports/PROJECT/Y-YYYY/M-MM/W-NN/W-NN.md`

For `{{daily_links}}`, generate one wikilink per day that had commits this week:
```
- [[PROJECT/Y-YYYY/M-MM/W-NN/D-DD|DATE]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/Y-YYYY/M-MM/W-NN/W-NN.md" content="..." overwrite
```

**Monthly** (always: overwritten every run with month-to-date commits):

First write the monthly report:

Path: `Reports/PROJECT/Y-YYYY/M-MM/M-MM.md`

For `{{weekly_links}}`, generate one wikilink per week that had commits this month:
```
- [[PROJECT/Y-YYYY/M-MM/W-NN/W-NN|Week W-NN]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/Y-YYYY/M-MM/M-MM.md" content="..." overwrite
```

**Yearly** (always: overwritten every run with year-to-date commits):

Path: `Reports/PROJECT/Y-YYYY/Y-YYYY.md`

For `{{monthly_links}}`, generate one wikilink per month that had commits this year:
```
- [[PROJECT/Y-YYYY/M-MM/M-MM|Month M-MM]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/Y-YYYY/Y-YYYY.md" content="..." overwrite
```

**Project index** (always: unconditional, run for every project regardless of commit activity):

After all report writes, always update `Reports/PROJECT/PROJECT.md`. First extract project-level stats from git:

```bash
# First commit date
FIRST_COMMIT=$(git -C "$path" log $BRANCH_ARGS --reverse --pretty=format:"%ad" --date=format:"%Y-%m-%d" | head -1)

# Total commit count across all time
TOTAL_COMMITS=$(git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%h" | wc -l | tr -d ' ')

# Active years (distinct years with at least one commit)
ACTIVE_YEARS=$(git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%ad" --date=format:"%Y" | sort -u | tr '\n' ',' | sed 's/,$//')

# Contributors (distinct author names, all time)
CONTRIBUTORS=$(git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%an" | sort -u | tr '\n' ',' | sed 's/,$//')
# Format as YAML inline array for frontmatter
CONTRIBUTORS_YAML=$(git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%an" | sort -u | awk 'BEGIN{printf "["} NR>1{printf ", "} {printf "\"%s\"", $0} END{print "]"}')

# Lifetime chart data: commits per month (for chart_lifetime_labels / chart_lifetime_data)
# Extract YYYY-MM for each commit, count per month, build arrays
git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%ad" --date=format:"%Y-%m" | sort | uniq -c
# Build: chart_lifetime_labels = ["2024-01","2024-02",...] (all months with commits)
# Build: chart_lifetime_data = [N, N, ...] (commit count per month, matching labels)
```

Then scan the vault for existing yearly report files and build one link per year, newest first:

```bash
obsidian vault="VAULT" files folder="Reports/PROJECT" | grep "Y-[0-9]\{4\}/Y-[0-9]\{4\}\.md"
```

Load `Templates/project-index-template.md` and fill in all placeholders:

| Placeholder | Value |
|---|---|
| `{{project}}` | project name |
| `{{tags}}` | `["project/PROJECT"]`: no report-type tag, just the project tag |
| `{{first_commit}}` | earliest commit date (YYYY-MM-DD) |
| `{{total_commits}}` | total commit count across all time |
| `{{active_years}}` | comma-separated list of years with commits (e.g. `2024, 2025, 2026`) |
| `{{contributors}}` | YAML inline array of distinct author names (all time): `["Alice", "Bob"]` |
| `{{health}}` | `green`, `yellow`, or `red` — computed in Step 6c |
| `{{health_details}}` | one-line health summary — computed in Step 6c |
| `{{generated_at}}` | ISO-8601 timestamp of generation |
| `{{chart_lifetime_labels}}` | JSON array of YYYY-MM strings for months with commits |
| `{{chart_lifetime_data}}` | JSON array of commit counts per month (matching labels) |
| `{{resume_taches}}` | essay-style narrative in `$LANGUAGE` describing what this project is and what it has built over its lifetime: tone is reflective and human, written as if onboarding a future team member ("this project started as X, grew into Y, its core purpose is Z"): **single line, no newlines**, 3-5 sentences, subject is *the project* |
| `{{highlights}}` | 5-8 named milestones or turning points across the project's entire lifetime: one bullet per line, each starting with `> - `: compress each to a one-sentence outcome with impact ("shipped auth rewrite: reduced login errors by 80%", "migrated to monorepo: unified 3 repos into one") |
| `{{yearly_links}}` | one `- [[PROJECT/Y-YYYY/Y-YYYY\|Y-YYYY]]` per year found, newest first |

```bash
obsidian vault="VAULT" create path="Reports/PROJECT/PROJECT.md" content="<filled template>" overwrite
```

## Step 6: Update Dashboard

After all projects have been processed, always overwrite `Reports/Dashboard.md` with a fresh cross-project summary.

### Step 6b: Compute chart data for the Dashboard

Before filling the dashboard template, compute the following from git log across all projects:

**Bar chart — commits per day over the last 30 days (per project):**
```bash
START_30D=$(date -d "$DATE - 30 days" +%Y-%m-%d 2>/dev/null || date -j -v-30d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
# For each project, count commits per day:
git -C "$path" log $BRANCH_ARGS --after="${START_30D}T00:00:00" --before="${DATE}T23:59:59" \
  --no-merges --pretty=format:"%ad" --date=format:"%Y-%m-%d" | sort | uniq -c
# Build: chart_labels_30d = ["YYYY-MM-DD", ...] (every day in range, 30 entries)
# Build: chart_series_30d = one "- title: PROJECT\n  data: [N,N,...]" entry per project
```

**Line chart — total commits per week over last 8 weeks:**
```bash
# For each of the last 8 ISO weeks, sum commits across all projects
# Build: chart_labels_8w = ["W-15", "W-16", ...] (8 entries)
# Build: chart_data_8w = [total_commits_per_week, ...]
```

**Pie chart — total commits per project over 30 days:**
```bash
# Sum all commits per project in the 30-day window
# Build: chart_pie_labels = ["ProjectAlpha", "ProjectBeta", ...]
# Build: chart_pie_data = [N, N, ...]
```

Format all arrays as compact JSON arrays: `[3, 0, 5, 1]`. For bar chart series, format each project as:
```
  - title: ProjectAlpha
    data: [3, 0, 5, ...]
```

### Step 6c: Compute project health indicators

For each project, compute a health score. Store results to fill `{{health_overview}}` in the dashboard and `{{health}}` / `{{health_details}}` in the project-index:

```bash
# Days since last commit
LAST_COMMIT_DATE=$(git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%ad" --date=format:"%Y-%m-%d" | head -1)
DAYS_SINCE=$(( ( $(date -d "$DATE" +%s) - $(date -d "$LAST_COMMIT_DATE" +%s) ) / 86400 ))

# Commit count this week vs 4-week average
COMMITS_THIS_WEEK=$(git -C "$path" log $BRANCH_ARGS --after="${WEEK_START}T00:00:00" --before="${DATE}T23:59:59" --no-merges --pretty=format:"%h" | wc -l | tr -d ' ')
COMMITS_30D=$(git -C "$path" log $BRANCH_ARGS --after="${START_30D}T00:00:00" --before="${DATE}T23:59:59" --no-merges --pretty=format:"%h" | wc -l | tr -d ' ')
AVG_WEEKLY=$(( COMMITS_30D / 4 ))

# Distinct contributors last 30 days
CONTRIB_COUNT=$(git -C "$path" log $BRANCH_ARGS --after="${START_30D}T00:00:00" --before="${DATE}T23:59:59" --no-merges --pretty=format:"%an" | sort -u | wc -l | tr -d ' ')
```

**Health scoring rules:**
- `red` if: `DAYS_SINCE > 30` OR (`AVG_WEEKLY > 5` AND `COMMITS_THIS_WEEK < AVG_WEEKLY / 2`)
- `yellow` if: `DAYS_SINCE > 7` OR `CONTRIB_COUNT == 1` OR thin commit rate > 40% (reuse existing detection)
- `green` otherwise

**Health details string** (for `{{health_details}}`):
```
"{{COMMITS_30D}} commits (30d) | {{CONTRIB_COUNT}} contributor(s) | last commit {{DAYS_SINCE}}d ago"
```

**`{{health_overview}}` for the dashboard** — one callout per project, using Obsidian callout types:
- `green` → `> [!success] ProjectName — On track`
- `yellow` → `> [!warning] ProjectName — Attention`
- `red` → `> [!danger] ProjectName — Stale`

Each callout body: `> {{health_details}}`

### Step 6d: Fill and write Dashboard

Load `Templates/dashboard-template.md` and fill in:

| Placeholder | Value |
|---|---|
| `{{date}}` | today's date (YYYY-MM-DD) |
| `{{workspace_summary}}` | 2-3 sentences synthesizing activity across **all** projects for the current week: what is the overall focus, what moved forward, any notable pattern: **single line, no newlines** |
| `{{workspace_highlights}}` | one bullet per active project with a one-line status, each starting with `> - **PROJECT**: `: e.g. `> - **MyApp**: shipped auth refactor, 8 commits` |
| `{{health_overview}}` | callouts computed in Step 6c, one per project |
| `{{projects_overview}}` | one block per project, based on reading each project index (`Reports/PROJECT/PROJECT.md`): project name as a wikilink header, then 2-3 sentences covering what the project is, its total commit span, and the main themes from the project index essay. Tone: timeless, factual. One blank line between projects. |
| `{{chart_labels_30d}}` | JSON array of date strings (30 entries) |
| `{{chart_series_30d}}` | YAML block with one series per project |
| `{{chart_labels_8w}}` | JSON array of week labels (8 entries) |
| `{{chart_data_8w}}` | JSON array of total commits per week |
| `{{chart_pie_labels}}` | JSON array of project names |
| `{{chart_pie_data}}` | JSON array of commit counts |

```bash
obsidian vault="VAULT" create path="Reports/Dashboard.md" content="<filled template>" overwrite
```

## Step 7: Print summary

```
╔══════════════════════════════════════════════════╗
║  report-orchestrator: done                      ║

╠══════════════════════════════════════════════════╣
║  Date   : YYYY-MM-DD  Week: WNN
║  Reports: daily [+ weekly] [+ monthly] [+ yearly]
║  Catchup : 2026-03-17 ✓  2026-03-18 ✓  (or "none")
╠══════════════════════════════════════════════════╣
║  PROJECT_A   daily ✓  weekly ✓  monthly ✓  yearly ✓
║  PROJECT_B   daily ✓
╚══════════════════════════════════════════════════╝
```

## Progress logging

Print a short status line before each major action so the user can follow along. Keep it to one line, no markdown, no verbose detail.

Examples:
```
[step 1] date=2026-03-18  language=English
[step 2] daily ✓  weekly ✗  monthly ✗  yearly ✗
[step 3] loaded 3 projects
[catchup] 2026-03-11 → 2026-03-17  (7 days to check)
[catchup] 2026-03-11 ProjectAlpha: skipped (exists)
[catchup] 2026-03-12 ProjectAlpha: generating...
[catchup] 2026-03-12 ProjectAlpha: done (3 commits)
[ProjectAlpha] branches: main develop
[ProjectAlpha] daily: 4 commits → writing...
[ProjectAlpha] daily ✓
[ProjectAlpha] weekly: 12 commits → writing...
[ProjectAlpha] weekly ✓
```

Print these lines as you go: do not buffer and print all at the end.

## Rules
- Run everything in THIS session: no background processes, no spawning new claude sessions
- NEVER write files directly (`echo >`, `tee`, `cat >`)
- ONLY use `obsidian vault="..." command key=value` for all vault writes
- `vault=` must be the first argument on every obsidian command
- `overwrite` is a flag without `--`
- Terminal must NOT run as administrator
- If a project has no commits for a period, **do not write the report**: skip it silently to avoid detached nodes in the graph

---

## Check mode

Triggered by `/report-orchestrator check`. Skip all report generation. Run the vault conformity audit and print results.

```bash
bash scripts/check-vault.sh
```

Print a clear summary of what was found: errors (broken links, phantom folders, wrong tags, zero-commit reports) and warnings (unexpected files). Exit when done: do not fix anything.

---

## Fix mode

Triggered by `/report-orchestrator fix`. Run the audit first, then process each error category in order:

### 1. Zero-commit reports
Delete the file: it should not exist:
```bash
obsidian vault="VAULT" delete path="PATH"
```

### 2. Wrong or missing tags
Read the file, extract the current frontmatter `tags:` line, rewrite it with the correct tags for the report type and project. Use `obsidian vault="VAULT" create path="PATH" content="<full file with corrected tags>" overwrite`.

Correct tags per type:
- Daily: `[report/daily, "project/PROJECT"]` + any extra tags already present
- Weekly: `[report/weekly, "project/PROJECT"]` + extras
- Monthly: `[report/monthly, "project/PROJECT"]` + extras
- Yearly: `[report/yearly, "project/PROJECT"]` + extras
- Project index: `["project/PROJECT"]`

### 3. Wrong or broken parent link
Read the file, rewrite the `parent:` frontmatter field with the correct wikilink computed from the file's position in the folder tree:
- Daily at `P/Y/M/W/D-DD.md` → `parent: "[[P/Y/M/W/W]]"`
- Weekly at `P/Y/M/W/W.md` → `parent: "[[P/Y/M/M]]"`
- Monthly at `P/Y/M/M.md` → `parent: "[[P/Y/Y]]"`
- Yearly at `P/Y/Y.md` → `parent: "[[P/P]]"`
- Project index → `parent: "[[Dashboard]]"`

### 4. Broken Current/ pointer
Find the most recent daily report that actually exists for the project:
```bash
obsidian vault="VAULT" files folder="Reports/PROJECT" | grep "D-[0-9][0-9]\.md" | sort | tail -1
```
Rewrite `Reports/Current/PROJECT.md` to point to it.

### 5. Phantom folder (aggregate .md missing)
The folder exists with daily/weekly files inside but the aggregate report is missing. Regenerate it using the same logic as the normal report flow: read the git log for the relevant period, generate prose, write the file via obsidian CLI. Apply the exact same templates and placeholders as the normal run.

After all fixes are applied, re-run `bash scripts/check-vault.sh` and print the final result.

---

## Discover mode

Triggered by `/report-orchestrator discover`.

Shows the full vault picture in one view: tracked projects with their vault status, and any untracked repos found on disk. Lets the user pick which untracked repos to add and ask from when to start tracking each one.

### 1. Resolve scan paths

```bash
DISCOVER_PATHS=$(grep -E "^DISCOVER_PATHS=" .env 2>/dev/null | cut -d= -f2 | tr -d ' ')
DISCOVER_PATHS="${DISCOVER_PATHS:-$HOME/projects:$HOME/repos:$HOME/code:$HOME/workspace:$HOME/dev}"
```

### 2. Load tracked projects and their vault status

Read `projects.config` (skip comment lines). For each tracked project:

```bash
# Last report date: read the Current/ pointer, extract date from the wikilink path (D-DD in W-NN in M-MM in Y-YYYY)
CURRENT=$(obsidian vault="VAULT" read path="Reports/Current/PROJECT.md" 2>/dev/null)
# The file contains a wikilink like [[PROJECT/Y-2026/M-03/W-12/D-22]] — extract the date from it

# Health: read from project-index frontmatter
HEALTH=$(obsidian vault="VAULT" read path="Reports/PROJECT/PROJECT.md" 2>/dev/null | grep -E "^health:" | awk '{print $2}')
```

Derive `last_report_date` by parsing the wikilink in `Current/PROJECT.md`:
- Pattern `Y-YYYY/M-MM/W-NN/D-DD` → reconstruct as `YYYY-MM-DD`
- If `Current/PROJECT.md` does not exist → `never`

`health` values: `green`, `yellow`, `red`, or `—` if no project-index yet.

### 3. Find untracked git repositories

For each path in `DISCOVER_PATHS` (colon-separated), scan recursively up to depth 4:

```bash
find "$scan_dir" -maxdepth 4 -name ".git" -type d 2>/dev/null | sed 's|/.git$||'
```

Exclude:
- The `claude-obsidian-reporting` directory itself
- Any path inside `.cache/` (bare clones managed by this tool)
- Paths already in `projects.config` (compare by resolved absolute path)
- Submodules (`.git` file, not directory)

For each untracked repo, gather:
```bash
git -C "$repo" log --oneline --no-merges 2>/dev/null | wc -l               # commit count
git -C "$repo" log -1 --format="%ad" --date=format:"%Y-%m-%d" 2>/dev/null  # last commit date
git -C "$repo" log --reverse --format="%ad" --date=format:"%Y-%m-%d" 2>/dev/null | head -1  # first commit date
git -C "$repo" remote get-url origin 2>/dev/null                            # remote URL
git -C "$repo" symbolic-ref --short HEAD 2>/dev/null                        # default branch
```

Derive the suggested project name from the directory basename.

### 4. Print the full vault overview

Always print both sections, even if one is empty.

```
╔══════════════════════════════════════════════════════════════════════╗
║  discover — vault overview                                           ║
╠══════════════════════════════════════════════════════════════════════╣
║  Tracked projects (5)                                                ║
║                                                                      ║
║    SAFARI               last report: 2026-03-22   health: green      ║
║    claude-obsidian      last report: 2026-03-22   health: green      ║
║    event-rental         last report: 2026-03-22   health: yellow     ║
║    event-pool           last report: never        health: —          ║
║    yanisbardes.github   last report: 2026-03-22   health: green      ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  Untracked repos found (3)                                           ║
║                                                                      ║
║   1. my-app        /home/user/projects/my-app      [main]  2026-03-18  142 commits  (since 2024-01-15) ║
║   2. client-x      /home/user/projects/client-x    [main]  2026-02-28   67 commits  (since 2025-06-01) ║
║   3. side-project  /home/user/repos/side-project   [main]  2025-11-01   23 commits  (since 2025-08-12) ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

Add which repos? (numbers like "1 3", "all", or Enter to skip):
```

If no untracked repos are found, print the tracked section only and end with:
```
No untracked git repositories found in the scan paths.
```

### 5. Add selected repos — ask backfill date per repo

For each selected repo (in selection order), ask individually:

```
Track my-app (142 commits since 2024-01-15):
  Backfill from when?  [all | YYYY-MM-DD | Enter = today only]
  >
```

- `all` → backfill from first commit date
- `YYYY-MM-DD` → backfill from that date
- Enter (empty) → no backfill, today's report only

Store the backfill answer per repo. Then write each repo to `projects.config`:
- name: suggested name
- path: absolute path
- url: remote origin URL if detected (empty otherwise)
- branches: default branch

Use the same duplicate-check and write logic as [Add-project mode](#add-project-mode).

Print a confirmation line per repo added:
```
Added: my-app | /home/user/projects/my-app | https://github.com/user/my-app | main |  (backfill: all)
Added: client-x | /home/user/projects/client-x |  | main |  (backfill: 2025-09-01)
Added: side-project | /home/user/repos/side-project |  | main |  (backfill: today only)
```

### 6. Run reports immediately

After all repos are written to `projects.config`, for each newly added project:

- If backfill was `all` or a date → run the full report flow with `backfill=<value>` for that project only
- If no backfill → run today's report only for that project

Print progress using the same `[step N]` format as the normal flow. When all are done, print the standard summary box.

---

## Status mode

Triggered by `/report-orchestrator status`.

Reads the vault — no git operations, no writes. Shows the current reporting state of every tracked project: last report date, health, coverage, and contributors. Useful for a quick morning check or before presenting reports to stakeholders.

### 1. Load tracked projects

Read `projects.config` (skip comment lines). Build the list of project names.

Read `VAULT_NAME` from `.env`:
```bash
VAULT_NAME=$(grep -E "^VAULT_NAME=" .env | cut -d= -f2 | tr -d ' ')
```

### 2. For each project, read vault data

**Last report date** — read `Reports/Current/PROJECT.md` and parse the wikilink:
```bash
obsidian vault="VAULT" read path="Reports/Current/PROJECT.md"
# Content: [[PROJECT/Y-2026/M-03/W-12/D-22]]
# Extract Y, M, D from path segments to reconstruct YYYY-MM-DD
```
If file does not exist → `last_report = never`.

**Project-index frontmatter** — read `Reports/PROJECT/PROJECT.md`:
```bash
obsidian vault="VAULT" read path="Reports/PROJECT/PROJECT.md"
```
Extract from frontmatter:
- `health` → `green` / `yellow` / `red` / `—` if missing
- `total_commits` → integer or `—`
- `contributors` → list (count the entries)
- `first_commit` → YYYY-MM-DD or `—`
- `generated_at` → last time the index was regenerated

If project-index does not exist → all fields are `—`, health = `—`.

**Report counts** — count existing report files per type by listing the vault folder:
```bash
obsidian vault="VAULT" files folder="Reports/PROJECT"
# Count files matching: D-*.md (daily), W-*.md (weekly), M-*.md (monthly), Y-*.md (yearly)
```

**Days since last report** — compute from `last_report` date to today. If `never` → `—`.

### 3. Print the status table

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  status — reporting overview                vault: MyNotes   projects: 5     ║
╠═════════════════════════╦═════════╦═══════════╦════════════╦═══════╦═════════╣
║  Project                ║ Health  ║ Last rpt  ║  Since     ║ Cmt.  ║ Contrib ║
╠═════════════════════════╬═════════╬═══════════╬════════════╬═══════╬═════════╣
║  SAFARI                 ║ ● green ║ 2026-03-22║ 2024-01-10 ║   88  ║    3    ║
║  claude-obsidian        ║ ● green ║ 2026-03-22║ 2026-03-14 ║   61  ║    1    ║
║  event-rental           ║ ●yellow ║ 2026-03-22║ 2025-02-01 ║  145  ║    2    ║
║  event-pool             ║  —      ║ never     ║     —      ║    —  ║    —    ║
║  yanisbardes.github.io  ║ ● green ║ 2026-03-22║ 2024-09-03 ║   24  ║    1    ║
╠═════════════════════════╩═════════╩═══════════╩════════════╩═══════╩═════════╣
║  5 projects  ·  3 green  ·  1 yellow  ·  0 red  ·  1 never reported          ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

Column descriptions:
- **Health** — from project-index frontmatter. Prefix with `●` colored indicator: `green` → `● green`, `yellow` → `● yellow`, `red` → `● red`, missing → `—`
- **Last rpt** — date of the last daily report written to vault (from `Current/PROJECT.md`)
- **Since** — first commit date tracked (`first_commit` from project-index)
- **Cmt.** — `total_commits` from project-index (all-time)
- **Contrib** — number of distinct contributors (count entries in `contributors` array from project-index)

Footer line counts: total projects, count per health value, and count with `never` as last report.

### 4. Detail section — stale and never-reported projects

After the table, if any project has health `red` or `yellow` or `last_report = never`, print a detail block:

```
⚠  Projects needing attention:

  event-pool          never reported — run /report-orchestrator to generate first reports
  event-rental        health: yellow — last commit 9 days ago, 1 contributor
```

Pull the `health_details` string from the project-index frontmatter for the detail line. If no project-index exists, show `never reported — run /report-orchestrator to generate first reports`.

### 5. Report coverage summary

Print a brief coverage line showing how many of each report type exist across all projects:

```
  Report coverage: 47 daily  ·  12 weekly  ·  3 monthly  ·  1 yearly
```

This is purely a count of matching files in the vault across all project folders.

---

## Add-project mode

Triggered by `/report-orchestrator add-project name=X path=/absolute/path`.

Optional parameters:
- `url`: git remote URL (for auto-clone if path does not exist yet)
- `branches`: comma-separated branch names to track (e.g. `main,develop`)
- `tags`: comma-separated permanent tags for all reports of this project (e.g. `client/acme,team/backend`)

Steps:

1. **Check for duplicates**: read `projects.config` and verify no line already starts with `name|`. If it exists, print an error and stop.

2. **Validate**: four valid combinations:

| path | url | Behaviour |
|---|---|---|
| set, exists | optional | Local repo. Pulls if remote exists, skips otherwise. |
| set, missing | set | Will be cloned to `path` on first run. |
| empty/absent | set | Remote-only. Bare clone auto-managed in `.cache/NAME.git`. |
| empty/absent | empty | Error — nothing to track. |

For remote-only projects (no path), record an empty path in `projects.config`:
```
NAME||https://github.com/org/repo|optional_branches|optional_tags
```

3. **Append to projects.config**: add the new line in the correct format:
```
NAME|/absolute/path|optional_url|optional_branches|optional_tags
```
Omit trailing `|` for empty optional fields. Place the new entry after the last non-comment line.

4. Print a confirmation:
```
[add-project] Added: NAME | /absolute/path
Projects in projects.config: N
Run /report-orchestrator to generate the first reports.
```

---

## Remove-project mode

Triggered by `/report-orchestrator remove-project name=X`.

Steps:

1. **Find the project**: read `projects.config` and locate the line starting with `name|`. If not found, print an error and stop.

2. **Show what will be removed**: print the matching line and ask for confirmation before deleting.

3. **Remove the line**: rewrite `projects.config` without that line.

4. **Offer vault cleanup**: ask the user if they want to delete the project's vault folder (`Reports/NAME/`) and its `Current/NAME.md` shortcut. If yes, run:
```bash
obsidian vault="VAULT" delete path="Reports/NAME"
obsidian vault="VAULT" delete path="Reports/Current/NAME.md"
```
If no, leave the vault files as-is (they become orphaned nodes in the graph).

5. Print a confirmation:
```
[remove-project] Removed: NAME
Vault files: deleted / kept (per user choice)
Projects remaining: N
```

</instructions>
