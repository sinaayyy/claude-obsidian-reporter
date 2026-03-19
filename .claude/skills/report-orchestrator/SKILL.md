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

If `check` or `fix` is present, **skip the normal report flow entirely** and jump to the corresponding mode.

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
```bash
git clone <url> <path>   # if git_url present and not yet cloned
git -C <path> pull       # otherwise
```

Resolve `$BRANCH_ARGS` for this project as described in Step 3 before extracting git log.

### 3b. Extract git log

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
| `{{nb_commits}}` | commit count |
| `{{status}}` | `success` |
| `{{liste_commits}}` | formatted commit list (never empty: reports with 0 commits are not written) |
| `{{resume_taches}}` | prose summary in `$LANGUAGE`: **single line, no newlines** (rendered inside a `> [!summary]` callout): tone and abstraction scale strictly with level: **daily** = terse, first-person, task movement ("shipped X", "investigating Y", "blocked on Z"): 2-3 sentences, subject is *I*; **weekly** = professional, team-level framing, individual tasks compressed into outcomes ("the team delivered X", "carried over Y due to Z"): 2-3 sentences, subject is *the team*; **monthly** = measured, data-grounded, outcome vs. plan framing, trends and risks surfacing ("delivery was on track / behind, tech debt in area X is accumulating"): 3-4 sentences, subject is *the workstream*; **yearly** = narrative and reflective, thematic not chronological, acknowledges difficulty alongside wins ("the year was defined by X, we built Y, we learned Z"): 3-5 sentences, subject is *the project* |
| `{{highlights}}` | key items in `$LANGUAGE`: one bullet per line, each starting with `> - ` (rendered inside a `> [!check]` callout): used in weekly, monthly, and yearly: **weekly** = 2-3 concrete deliverables or unblocked blockers; **monthly** = 3-5 delivery milestones, risk items, or tech debt flags: include red signals openly, not just wins; **yearly** = 5-7 thematic achievements or shifts: compress projects into named outcomes with one-sentence impact |
| `{{notes}}` | leave empty |
| `{{first_commit}}` | earliest commit date across all time (YYYY-MM-DD): project index only |
| `{{total_commits}}` | total commit count across all time: project index only |
| `{{active_years}}` | comma-separated years with at least one commit: project index only |
| `{{contributors}}` | comma-separated distinct author names: project index only |
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

# Contributors (distinct author names)
CONTRIBUTORS=$(git -C "$path" log $BRANCH_ARGS --no-merges --pretty=format:"%an" | sort -u | tr '\n' ',' | sed 's/,$//')
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
| `{{contributors}}` | comma-separated list of distinct author names |
| `{{resume_taches}}` | essay-style narrative in `$LANGUAGE` describing what this project is and what it has built over its lifetime: tone is reflective and human, written as if onboarding a future team member ("this project started as X, grew into Y, its core purpose is Z"): **single line, no newlines**, 3-5 sentences, subject is *the project* |
| `{{highlights}}` | 5-8 named milestones or turning points across the project's entire lifetime: one bullet per line, each starting with `> - `: compress each to a one-sentence outcome with impact ("shipped auth rewrite: reduced login errors by 80%", "migrated to monorepo: unified 3 repos into one") |
| `{{yearly_links}}` | one `- [[PROJECT/Y-YYYY/Y-YYYY\|Y-YYYY]]` per year found, newest first |

```bash
obsidian vault="VAULT" create path="Reports/PROJECT/PROJECT.md" content="<filled template>" overwrite
```

## Step 6: Update Dashboard

After all projects have been processed, always overwrite `Reports/Dashboard.md` with a fresh cross-project summary.

Load `Templates/dashboard-template.md` and fill in:

| Placeholder | Value |
|---|---|
| `{{date}}` | today's date (YYYY-MM-DD) |
| `{{workspace_summary}}` | 2-3 sentences synthesizing activity across **all** projects for the current week: what is the overall focus, what moved forward, any notable pattern: **single line, no newlines** |
| `{{workspace_highlights}}` | one bullet per active project with a one-line status, each starting with `> - **PROJECT**: `: e.g. `> - **MyApp**: shipped auth refactor, 8 commits` |

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

</instructions>
