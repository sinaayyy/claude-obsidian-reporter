---
name: report-orchestrator
description: End-of-day skill for Claude Code — generates daily, weekly, monthly, and yearly Git activity reports into your Obsidian vault. Auto-detects end of week (weekly), last day of month (monthly), and Dec 31 (yearly). Supports multiple languages.
allowed-tools: Bash, Read
---

# report-orchestrator
<description>End-of-day report skill: generates daily report for all projects, plus weekly on the configured end-of-week day, monthly on the last day of the month, and yearly on December 31 — all in one session.</description>
<instructions>

You are the end-of-day report orchestrator. You run entirely within this Claude session — no subprocesses, no background tasks.

## Input (optional)
- `date` — YYYY-MM-DD (defaults to today if not provided)
- `language` — language for all generated text (defaults to `English`)
- `backfill` — YYYY-MM-DD or `all` — if provided, generate all missing reports from that date up to `$DATE` before running the normal flow
- `tags` — comma-separated extra tags to add to all reports in this run (e.g. `tags=client/acme,sprint/42`)

## Vault structure

```
Reports/
├── Current/
│   └── PROJECT.md                              ← today's daily (overwritten on every run)
└── PROJECT/
    ├── PROJECT-YYYY.md                         ← yearly report (Dec 31)
    └── YYYY-MM/                                ← monthly folder
        ├── PROJECT-YYYY-MM.md                  ← monthly report (last day of month)
        └── WNN/                                ← weekly folder
            ├── PROJECT-WNN-YYYY.md             ← weekly report (on WEEK_END_DAY)
            └── Daily/
                ├── PROJECT-YYYY-MM-DD.md       ← Monday daily
                ├── PROJECT-YYYY-MM-DD.md       ← Tuesday daily
                └── ...                         ← accumulates through the week
```

Examples:
- `Reports/Current/ProjectAlpha.md`
- `Reports/ProjectAlpha/2026-03/W12/Daily/ProjectAlpha-2026-03-18.md`
- `Reports/ProjectAlpha/2026-03/W12/Daily/ProjectAlpha-2026-03-20.md`
- `Reports/ProjectAlpha/2026-03/W12/ProjectAlpha-W12-2026.md`
- `Reports/ProjectAlpha/2026-03/ProjectAlpha-2026-03.md`
- `Reports/ProjectAlpha/ProjectAlpha-2026.md`

## Step 1 — Resolve language and date

```bash
LANGUAGE="${language:-English}"
```

Write all report content (section headings, summaries, highlights) in `$LANGUAGE`. Keep frontmatter keys and values in English regardless of language (they are metadata, not prose).

## Step 2 — Resolve date and detect which reports to run

```bash
DATE="${date:-$(date +%Y-%m-%d)}"

# Read WEEK_END_DAY from .env (default: 5 = Friday)
WEEK_END_DAY=$(grep -E "^WEEK_END_DAY=" .env 2>/dev/null | cut -d= -f2 | tr -d ' ')
WEEK_END_DAY="${WEEK_END_DAY:-5}"

DOW=$(date -d "$DATE" +%u 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%u)
NEXT=$(date -d "$DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
WEEK_NUM=$(date -d "$DATE" +%V 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%V)
WEEK_START=$(date -d "$DATE - $(( DOW - 1 )) days" +%Y-%m-%d 2>/dev/null || date -j -v-$(( DOW - 1 ))d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
YEAR_MONTH=$(date -d "$DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y-%m)
YEAR=$(date -d "$DATE" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y)
IS_WEEK_END=$([ "$DOW" = "$WEEK_END_DAY" ] && echo true || echo false)
IS_LAST_DAY=$([ "$(date -d "$DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y-%m)" != "$(date -d "$NEXT" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$NEXT" +%Y-%m)" ] && echo true || echo false)
IS_LAST_YEAR=$([ "$(date -d "$DATE" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y)" != "$(date -d "$NEXT" +%Y 2>/dev/null || date -j -f "%Y-%m-%d" "$NEXT" +%Y)" ] && echo true || echo false)
```

Always run: **daily**
If `IS_WEEK_END`: also run **weekly**
If `IS_LAST_DAY`: also run **monthly**
If `IS_LAST_YEAR` (Dec 31): also run **yearly**

## Step 3 — Load projects

Read `projects.config` (format: `ProjectName|/absolute/path|optional_git_url|optional_branches|optional_tags`, lines starting with `#` are comments).

- `optional_tags` — comma-separated tags specific to this project (e.g. `client/acme,team/backend`). Added to every report generated for this project.

- `optional_branches` — comma-separated list of branches to include (e.g. `main,develop`). If omitted, defaults to `main,master,develop,dev` (only branches that actually exist in the repo are used).

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

## Step 3c — Build tags for each report

For each project and each report type, build the `{{tags}}` value as a YAML inline array:

1. **Base tags** — always included:
   - Daily: `report/daily`, `project/PROJECT`
   - Weekly: `report/weekly`, `project/PROJECT`
   - Monthly: `report/monthly`, `project/PROJECT`
   - Yearly: `report/yearly`, `project/PROJECT`

2. **Project tags** — from the 5th column of `projects.config` (comma-separated). Include all of them.

3. **Run-level tags** — from the `tags` input parameter (comma-separated). Applied to all projects in this run.

Merge all three, deduplicate, then format as a YAML inline array. Tags containing `/` must be quoted:

```
# Example: base=[report/daily, project/MyApp]  project_tags=[client/acme]  run_tags=[sprint/42]
# Result:
tags: [report/daily, "project/MyApp", "client/acme", "sprint/42"]

# No extra tags:
tags: [report/daily, "project/MyApp"]
```

Rule: quote any tag that contains `/` or special characters. Plain alphanumeric tags can be unquoted.

## Step 3b — Bootstrap dashboard (first run only)

Check if the dashboard exists:
```bash
obsidian vault="VAULT" file path="Reports/Dashboard.md"
```

- If it **exists** → skip
- If it **does not exist** → read `Templates/dashboard-template.md` and write it:
```bash
obsidian vault="VAULT" create path="Reports/Dashboard.md" content="<contents of dashboard-template.md>"
```

The dashboard uses Dataview queries that auto-refresh from report frontmatter — it never needs to be rewritten after creation.

Then bookmark it:
```bash
obsidian vault="VAULT" bookmark path="Reports/Dashboard.md" title="Reports Dashboard"
```

## Step 4 — Catchup missing days

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
obsidian vault="VAULT" file path="Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-PAST_DATE.md"
```

If the file **exists**, check whether it is stale by comparing the actual commit count with the value stored in the report frontmatter:
```bash
# Actual commits for that day
ACTUAL=$(git -C "$path" log $BRANCH_ARGS \
  --after="${PAST_DATE}T00:00:00" --before="${PAST_DATE}T23:59:59" \
  --pretty=format:"%h" --no-merges | wc -l | tr -d ' ')

# Commits recorded in the existing report (read the file then grep nb_commits)
RECORDED=$(obsidian vault="VAULT" read path="Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-PAST_DATE.md" \
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

## Step 5 — For each project, run all required reports in sequence

### 3a. Sync repo
```bash
git clone <url> <path>   # if git_url present and not yet cloned
git -C <path> pull       # otherwise
```

Resolve `$BRANCH_ARGS` for this project as described in Step 3 before extracting git log.

### 3b. Extract git log

**Daily** — commits on `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${DATE}T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

**Weekly** — commits from `$WEEK_START` to `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${WEEK_START}T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

**Monthly** — commits from first day of month to `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${YEAR_MONTH}-01T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

**Yearly** — commits from Jan 1 of the year to `$DATE`:
```bash
git -C "$path" log $BRANCH_ARGS --after="${YEAR}-01-01T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

This rule applies to **all report types** — if 0 commits for the period, **skip writing the report entirely**. Do not create the file. A note with no commits would appear as a detached node in the graph.

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
| `{{tags}}` | full YAML inline array of tags — base + project tags + run tags (see Step 3c) |
| `{{date}}` | YYYY-MM-DD |
| `{{week}}` | ISO week number (e.g. 12) |
| `{{month}}` | YYYY-MM |
| `{{year}}` | YYYY |
| `{{nb_commits}}` | commit count |
| `{{status}}` | `success` |
| `{{liste_commits}}` | formatted commit list (never empty — reports with 0 commits are not written) |
| `{{resume_taches}}` | 2-4 sentence prose summary in `$LANGUAGE` — **single line, no newlines** (rendered inside a `> [!summary]` callout) |
| `{{highlights}}` | key themes/wins (monthly and yearly) in `$LANGUAGE` — one bullet per line, each starting with `> - ` (rendered inside a `> [!check]` callout) |
| `{{notes}}` | leave empty |
| `{{daily_links}}` | wikilinks to daily reports (weekly template only) |
| `{{weekly_links}}` | wikilinks to weekly reports (monthly template only) |
| `{{monthly_links}}` | wikilinks to monthly reports (yearly template only) |
| `{{parent_weekly}}` | used as `parent` in the **daily** template — points to the weekly report — `PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY` |
| `{{parent_monthly}}` | used as `parent` in the **weekly** template — points to the monthly report — `PROJECT/YYYY-MM/PROJECT-YYYY-MM` |
| `{{parent_project}}` | used as `parent` in the **monthly** and **yearly** templates — points to the project index — `PROJECT/PROJECT` |

**Placeholder values to fill in (replace PROJECT, YYYY-MM, WNN, YYYY with actual values):**

| Placeholder | Value |
|---|---|
| `{{parent_weekly}}` | `PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY` |
| `{{parent_monthly}}` | `PROJECT/YYYY-MM/PROJECT-YYYY-MM` |
| `{{parent_project}}` | `PROJECT/PROJECT` |

**Daily** (always):

Paths:
- `Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE.md`  ← archived in weekly folder
- `Reports/Current/PROJECT.md`                          ← always the latest daily (overwritten)

Commands:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE.md" content="..." overwrite
obsidian vault="VAULT" create path="Reports/Current/PROJECT.md" content="[[PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE]]" overwrite
```

**Weekly** (WEEK_END_DAY only):

Path: `Reports/PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY.md`

For `{{daily_links}}`, generate one wikilink per day that had commits this week:
```
- [[PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE|DATE]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY.md" content="..." overwrite
```

**Monthly** (last day of month only):

First write the monthly report:

Path: `Reports/PROJECT/YYYY-MM/PROJECT-YYYY-MM.md`

For `{{weekly_links}}`, generate one wikilink per week that had commits this month:
```
- [[PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY|Week WNN]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/YYYY-MM/PROJECT-YYYY-MM.md" content="..." overwrite
```

**Yearly** (Dec 31 only):

Path: `Reports/PROJECT/PROJECT-YYYY.md`

For `{{monthly_links}}`, generate one wikilink per month that had commits this year:
```
- [[PROJECT/YYYY-MM/PROJECT-YYYY-MM|Month YYYY-MM]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/PROJECT-YYYY.md" content="..." overwrite
```

Then update (or create) the project index at `Reports/PROJECT/PROJECT.md`. Always overwrite it so it stays in sync — collect **all years**, **all months**, and **all weeks** ever generated for this project by reading existing report files:

```bash
# List all yearly reports for this project
obsidian vault="VAULT" files folder="Reports/PROJECT" | grep "PROJECT-[0-9]\{4\}\.md"

# List all monthly reports for this project
obsidian vault="VAULT" files folder="Reports/PROJECT" | grep "PROJECT-[0-9]\{4\}-[0-9]\{2\}\.md"

# List all weekly reports for this project
obsidian vault="VAULT" files folder="Reports/PROJECT" | grep "PROJECT-W[0-9]\{2\}-[0-9]\{4\}\.md"
```

Build the project index content with:
- One `[[PROJECT/PROJECT-YYYY|Year YYYY]]` link per year found, sorted newest first
- One `[[PROJECT/YYYY-MM/PROJECT-YYYY-MM|Month YYYY-MM]]` link per month found, sorted newest first
- One `[[PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY|WNN]]` link per week found, sorted newest first

```bash
obsidian vault="VAULT" create path="Reports/PROJECT/PROJECT.md" content="---
type: claude-project-index
project: PROJECT
tags: [\"project/PROJECT\"]
parent: \"[[Dashboard]]\"
---

# PROJECT

## Yearly Reports

- [[PROJECT/PROJECT-YYYY|YYYY]]
- ...

## Monthly Reports

- [[PROJECT/YYYY-MM/PROJECT-YYYY-MM|YYYY-MM]]
- ...

## Weekly Reports

- [[PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY|WNN]]
- ..." overwrite
```

## Step 6 — Print summary

```
╔══════════════════════════════════════════════════╗
║  report-orchestrator — done                      ║
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
[catchup] 2026-03-11 ProjectAlpha — skipped (exists)
[catchup] 2026-03-12 ProjectAlpha — generating...
[catchup] 2026-03-12 ProjectAlpha — done (3 commits)
[ProjectAlpha] branches: main develop
[ProjectAlpha] daily — 4 commits → writing...
[ProjectAlpha] daily ✓
[ProjectAlpha] weekly — 12 commits → writing...
[ProjectAlpha] weekly ✓
```

Print these lines as you go — do not buffer and print all at the end.

## Rules
- Run everything in THIS session — no background processes, no spawning new claude sessions
- NEVER write files directly (`echo >`, `tee`, `cat >`)
- ONLY use `obsidian vault="..." command key=value` for all vault writes
- `vault=` must be the first argument on every obsidian command
- `overwrite` is a flag without `--`
- Terminal must NOT run as administrator
- If a project has no commits for a period, **do not write the report** — skip it silently to avoid detached nodes in the graph

</instructions>
