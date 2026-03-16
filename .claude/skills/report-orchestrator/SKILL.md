---
name: report-orchestrator
description: End-of-day skill for Claude Code — generates daily, weekly, and monthly Git activity reports into your Obsidian vault. Auto-detects Fridays (weekly) and last day of month (monthly). Supports multiple languages.
allowed-tools: Bash, Read
---

# report-orchestrator
<description>End-of-day report skill: generates daily report for all projects, plus weekly on Fridays and monthly on the last day of the month — all in one session.</description>
<instructions>

You are the end-of-day report orchestrator. You run entirely within this Claude session — no subprocesses, no background tasks.

## Input (optional)
- `date` — YYYY-MM-DD (defaults to today if not provided)
- `language` — language for all generated text (defaults to `English`)

## Vault structure

```
Reports/
├── Current/
│   └── PROJECT.md                              ← today's daily (overwritten on every run)
└── PROJECT/
    └── YYYY-MM/                                ← monthly folder
        ├── PROJECT-YYYY-MM.md                  ← monthly report (last day of month)
        └── WNN/                                ← weekly folder
            ├── PROJECT-WNN-YYYY.md             ← weekly report (Fridays only)
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

## Step 1 — Resolve language and date

```bash
LANGUAGE="${language:-English}"
```

Write all report content (section headings, summaries, highlights) in `$LANGUAGE`. Keep frontmatter keys and values in English regardless of language (they are metadata, not prose).

## Step 2 — Resolve date and detect which reports to run

```bash
DATE="${date:-$(date +%Y-%m-%d)}"

DOW=$(date -d "$DATE" +%u 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%u)
NEXT=$(date -d "$DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
WEEK_NUM=$(date -d "$DATE" +%V 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%V)
WEEK_START=$(date -d "$DATE - $(( DOW - 1 )) days" +%Y-%m-%d 2>/dev/null || date -j -v-$(( DOW - 1 ))d -f "%Y-%m-%d" "$DATE" +%Y-%m-%d)
YEAR_MONTH=$(date -d "$DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y-%m)
IS_FRIDAY=$([ "$DOW" = "5" ] && echo true || echo false)
IS_LAST_DAY=$([ "$(date -d "$DATE" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$DATE" +%Y-%m)" != "$(date -d "$NEXT" +%Y-%m 2>/dev/null || date -j -f "%Y-%m-%d" "$NEXT" +%Y-%m)" ] && echo true || echo false)
```

Always run: **daily**
If `IS_FRIDAY`: also run **weekly**
If `IS_LAST_DAY`: also run **monthly**

## Step 3 — Load projects

Read `projects.config` (format: `ProjectName|/absolute/path|optional_git_url`, lines starting with `#` are comments).

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

## Step 4 — Auto-catchup missing days this week

Before processing today, check for missing daily reports earlier this week (from `WEEK_START` to `DATE - 1 day`). For each past day in that range:

```bash
# Build list of past days this week
current=$WEEK_START
while [[ "$current" < "$DATE" ]]; do
  echo "$current"
  current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
done
```

For each past day and each project, check if the daily report already exists:
```bash
obsidian vault="VAULT" file path="Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-PAST_DATE.md"
```

- If the file **exists** → skip (already reported)
- If the file **does not exist** → generate the daily report for that day (same process as Step 4, daily only, no weekly/monthly)

List caught-up days in the final summary.

## Step 5 — For each project, run all required reports in sequence

### 3a. Sync repo
```bash
git clone <url> <path>   # if git_url present and not yet cloned
git -C <path> pull       # otherwise
```

### 3b. Extract git log

**Daily** — commits on `$DATE`:
```bash
git -C "$path" log --after="${DATE}T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

**Weekly** — commits from `$WEEK_START` to `$DATE`:
```bash
git -C "$path" log --after="${WEEK_START}T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

**Monthly** — commits from first day of month to `$DATE`:
```bash
git -C "$path" log --after="${YEAR_MONTH}-01T00:00:00" --before="${DATE}T23:59:59" \
  --pretty=format:"- %s (%h) — %an" --no-merges
```

If 0 commits: `liste_commits = "_No commits._"`, `status = success`.

### 3c. Write reports to Obsidian

Note: `overwrite` is a flag without `--`. `vault=` must always be the first argument.

Load the user's templates from the `Templates/` folder:
```bash
cat Templates/daily-report-template.md
cat Templates/weekly-report-template.md
cat Templates/monthly-report-template.md
```

Fill in the `{{placeholder}}` variables from each template with the actual values, then write to Obsidian. Users can customize the report structure by editing those files.

**Placeholder reference:**

| Placeholder | Value |
|---|---|
| `{{project}}` | project name |
| `{{date}}` | YYYY-MM-DD |
| `{{week}}` | ISO week number (e.g. 12) |
| `{{month}}` | YYYY-MM |
| `{{year}}` | YYYY |
| `{{nb_commits}}` | commit count |
| `{{status}}` | `success` |
| `{{liste_commits}}` | formatted commit list or `_No commits._` |
| `{{resume_taches}}` | 2-4 sentence prose summary in `$LANGUAGE` — **single line, no newlines** (rendered inside a `> [!summary]` callout) |
| `{{highlights}}` | key themes/wins (monthly only) in `$LANGUAGE` — one bullet per line, each starting with `> - ` (rendered inside a `> [!check]` callout) |
| `{{notes}}` | leave empty |
| `{{daily_links}}` | wikilinks to daily reports (weekly/monthly only) |
| `{{weekly_links}}` | wikilinks to weekly reports (monthly only) |

**Daily** (always):

Paths:
- `Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE.md`  ← archived in weekly folder
- `Reports/Current/PROJECT.md`                          ← always the latest daily (overwritten)

Commands:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE.md" content="..." overwrite
obsidian vault="VAULT" create path="Reports/Current/PROJECT.md" content="[[Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE]]" overwrite
```

**Weekly** (Fridays only):

Path: `Reports/PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY.md`

For `{{daily_links}}`, generate one wikilink per day that had commits this week:
```
- [[Reports/PROJECT/YYYY-MM/WNN/Daily/PROJECT-DATE|DATE]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY.md" content="..." overwrite
```

**Monthly** (last day of month only):

Path: `Reports/PROJECT/YYYY-MM/PROJECT-YYYY-MM.md`

For `{{weekly_links}}`, generate one wikilink per week that had commits this month:
```
- [[Reports/PROJECT/YYYY-MM/WNN/PROJECT-WNN-YYYY|Week WNN]]
```

Command:
```bash
obsidian vault="VAULT" create path="Reports/PROJECT/YYYY-MM/PROJECT-YYYY-MM.md" content="..." overwrite
```

## Step 6 — Print summary

```
╔══════════════════════════════════════════════════╗
║  report-orchestrator — done                      ║
╠══════════════════════════════════════════════════╣
║  Date   : YYYY-MM-DD  Week: WNN
║  Reports: daily [+ weekly] [+ monthly]
║  Catchup : 2026-03-17 ✓  2026-03-18 ✓  (or "none")
╠══════════════════════════════════════════════════╣
║  PROJECT_A   daily ✓  weekly ✓
║  PROJECT_B   daily ✓
╚══════════════════════════════════════════════════╝
```

## Rules
- Run everything in THIS session — no background processes, no spawning new claude sessions
- NEVER write files directly (`echo >`, `tee`, `cat >`)
- ONLY use `obsidian vault="..." command key=value` for all vault writes
- `vault=` must be the first argument on every obsidian command
- `overwrite` is a flag without `--`
- Terminal must NOT run as administrator
- If a project has no commits for a period, still write the note with `_No commits._`

</instructions>
