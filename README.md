# claude-obsidian-reporter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet?logo=anthropic&logoColor=white)](https://claude.ai/claude-code)
[![Obsidian](https://img.shields.io/badge/Obsidian-plugin-7C3AED?logo=obsidian&logoColor=white)](https://obsidian.md)
[![GitHub Stars](https://img.shields.io/github/stars/sinaayyy/claude-obsidian-reporter?style=social)](https://github.com/sinaayyy/claude-obsidian-reporter)

Developers ship every day. Reporting on it takes hours — and it still doesn't reach the right people in the right form.

**claude-obsidian-reporter** turns your Git commits into a full reporting stack: daily logs for developers, weekly summaries for leads, monthly delivery reports for managers, and a live dashboard with health indicators, activity charts, and contributor tracking — all generated automatically, directly into Obsidian.

One command at the end of your day. Zero manual writing. No separate BI tool.

> **For developers:** your commits are your report. Claude reads them and writes the prose.
> **For team leads:** weekly outcomes, contributor activity, and cross-project visibility in one vault.
> **For managers:** monthly delivery health, project status, and risk flags — updated daily, no chasing.

<img src="docs/dashboard_preview_img.jpg" height="200" alt="Reports Dashboard" /> <img src="docs/graph_example.png" height="200" alt="Graph View" />

## What you get

### Reports — 5 levels, all generated on every run

| Level | Scope | Tone | Subject |
|---|---|---|---|
| Daily | Today | Terse, first-person: what moved, what's blocked | *I* |
| Weekly | Week to date | Team-level: tasks compressed into outcomes | *the team* |
| Monthly | Month to date | Data-grounded: delivery vs. plan, risks surfacing | *the workstream* |
| Yearly | Year to date | Narrative: thematic, acknowledges difficulty | *the project* |
| Project index | All time | Essay: what this project is and what it built | *the project* |

All levels are written on every run and kept up to date. Missed a day? The skill auto-detects and fills gaps from the current week. Starting on an existing project? `backfill=all` populates everything from the first commit.

### Dashboard live across all projects

The Dashboard aggregates all your projects in one view:

- **Project health** — color-coded status per project: on track (green), attention (yellow), stale (red), based on commit frequency, days since last commit, contributor concentration, and commit message quality
- **Activity charts** — commits per day (30 days, stacked by project), weekly velocity trend (8 weeks), and commit distribution by project — via the Charts plugin
- **Contributor tracking** — who committed what, on which project, which week — queryable via Dataview
- **Live tables** — recent daily, weekly, monthly, and yearly reports, always up to date
- **Project overviews** — one summary per project based on its all-time index

### Project index — per-project home page

Each project gets a dedicated page with:
- Lifetime activity chart (monthly commits from first to last)
- All-time stats (first commit, total commits, contributors, active years)
- Key milestones and thematic narrative
- **Interactive fields** for managers: status (active/paused/archived), priority, and risk notes — stored in frontmatter, queryable by Dataview

## How it works

- **Only reads commit messages.** No source files, no diffs. If most messages are uninformative (`wip`, `fix`, `...`), falls back to reading changed file names only. Never file contents.
- **Synthesizes at every level.** Claude calibrates its writing to the level: terse task log for daily, team outcome summary for weekly, delivery health for monthly, thematic narrative for yearly. Each one the right register for its audience.
- **Enriches every report with metadata.** Each report captures contributors, files changed, lines added/removed, and generation timestamp — stored in frontmatter and usable in Dataview queries.
- **Computes health and charts automatically.** After writing reports, the skill scores each project's health (frequency, recency, bus factor) and builds chart data arrays (commits/day, weekly velocity, distribution) directly from git log. No external tools needed.
- **Writes directly into Obsidian** via the CLI plugin. No intermediate files, no copy-paste.
- **Runs entirely inside your Claude Code session.** No background processes, no subshells spawned.
- **Vault structure mirrors the time hierarchy.** `Y-YYYY/M-MM/W-NN/D-DD.md` with `parent` links between levels, so Obsidian's graph view builds the tree automatically.

## Quick Start

First report in under 5 minutes.

**Step 1 — Install Obsidian plugins** (Settings → Community plugins → Browse)

| Plugin | Install link |
|---|---|
| Obsidian CLI | search "Obsidian CLI" |
| Dataview | search "Dataview" |
| Obsidian Charts | search "Obsidian Charts" |
| Meta Bind | search "Meta Bind" |

> Open your vault in Obsidian at least once before continuing — the CLI needs it.

**Step 2 — Clone and configure**

```bash
git clone https://github.com/sinaayyy/claude-obsidian-reporter.git
cd claude-obsidian-reporter
bash setup-local.sh          # Windows: double-click install-windows.bat
```

Open `.env` and set two values:

```bash
VAULT_NAME=MyNotes              # folder name shown in Obsidian's title bar
VAULT_PATH=/home/user/MyNotes   # absolute path to your vault folder
```

**Step 3 — Add your projects** (let the tool find them for you)

Open Claude Code in the `claude-obsidian-reporter` directory, then run:

```
/report-orchestrator discover
```

It scans your machine for Git repos and shows them in a numbered list. Pick which ones to add, then for each one you're asked: **"Backfill from when?"** — answer `all` to populate from the first commit, a date like `2025-01-01`, or just press Enter for today only.

> Or set `DISCOVER_PATHS=/your/projects/folder` in `.env` to control where it looks.

**Step 4 — Generate your first reports**

```
/report-orchestrator
```

Open Obsidian — your Dashboard, project pages, and reports are ready.

---

## Prerequisites

- [Obsidian](https://obsidian.md) — your vault must be opened in Obsidian at least once so the CLI can find it by name
- [Claude Code](https://claude.ai/claude-code) installed and authenticated
- Git 2.x+

**Windows users:** Git Bash resolves `obsidian` to `Obsidian.exe` instead of `Obsidian.com`. Create a wrapper once:
```bash
mkdir -p ~/bin
echo '#!/bin/bash' > ~/bin/obsidian
echo '"/c/Users/$USERNAME/AppData/Local/Programs/Obsidian/Obsidian.com" "$@"' >> ~/bin/obsidian
chmod +x ~/bin/obsidian
```

### Required Obsidian plugins

| Plugin | Purpose |
|---|---|
| **Obsidian CLI** | Vault writes — the skill cannot function without it |
| **Dataview** | Live tables in the Dashboard |
| **Obsidian Charts** | Activity charts in Dashboard, monthly reports, and project pages |
| **Meta Bind** | Interactive status/priority/risk dropdowns on project pages |

### Optional plugins

| Plugin | What it adds |
|---|---|
| **[Homepage](https://obsidian.md/plugins?id=homepage)** | Auto-opens the Dashboard every time Obsidian launches |
| **[Breadcrumbs](https://obsidian.md/plugins?id=breadcrumbs)** | Clickable breadcrumb trail: `Dashboard > Project > Year > Month > Week > Day` |
| **[Tracker](https://obsidian.md/plugins?id=obsidian-tracker)** | Per-project sparklines from frontmatter data |
| **[Calendar](https://obsidian.md/plugins?id=calendar)** | Sidebar calendar with dots on days that have reports |
| **[Periodic Notes](https://obsidian.md/plugins?id=periodic-notes)** | Prev/next navigation between weeks, months, and years |

See [`docs/recommended-plugins.md`](docs/recommended-plugins.md) for step-by-step installation and configuration.

## Install

```bash
git clone https://github.com/sinaayyy/claude-obsidian-reporter.git
cd claude-obsidian-reporter
bash setup-local.sh          # Windows: double-click install-windows.bat
```

Open `.env` and set your vault:

```bash
VAULT_NAME=MyNotes              # folder name shown in Obsidian's title bar
VAULT_PATH=/home/user/MyNotes   # absolute path to your vault
LANGUAGE=English                # optional: French, Spanish, Japanese...
```

Then run `/report-orchestrator discover` to auto-detect your repos (recommended), or add them manually to `projects.config`:

```
# ProjectName | /absolute/path/to/repo | optional_git_url | optional_branches | optional_tags
MyApp|/home/user/projects/my-app|
ClientX|/home/user/projects/client-x||main|client/acme,team/backend
```

The `optional_tags` column lets you attach permanent tags to a project; they'll be included in every report generated for it (see [Custom tags](#custom-tags)).

## Usage

> Open Claude Code in the `claude-obsidian-reporter` directory (where `projects.config` lives), then run any of these commands. No need to have Obsidian open.

```
/report-orchestrator                                      ← today's reports (all projects)
/report-orchestrator status                               ← reporting status of all projects (vault read-only)
/report-orchestrator discover                             ← find local git repos not yet tracked
/report-orchestrator backfill=all                         ← populate from first commit (existing projects)
/report-orchestrator date=2026-03-14                      ← specific date
/report-orchestrator language=French                      ← reports in French
/report-orchestrator tags=sprint/42,client/acme           ← add tags to all reports today
/report-orchestrator check                                ← audit vault structure only
/report-orchestrator fix                                  ← audit + auto-fix all issues
/report-orchestrator add-project name=X path=/repo       ← add a project to projects.config
/report-orchestrator remove-project name=X               ← remove a project (with optional vault cleanup)
```

### Reporting status

```
/report-orchestrator status
```

Reads the vault — no git operations, no writes — and prints a table of every tracked project:

```
╔══════════════════════════════════════════════════════════════════════╗
║  status — reporting overview    vault: MyNotes   projects: 5        ║
╠══════════════╦═════════╦════════════╦════════════╦═══════╦══════════╣
║  Project     ║ Health  ║ Last rpt   ║ Since      ║ Cmt.  ║ Contrib  ║
╠══════════════╬═════════╬════════════╬════════════╬═══════╬══════════╣
║  SAFARI      ║ ● green ║ 2026-03-22 ║ 2024-01-10 ║   88  ║    3     ║
║  event-pool  ║  —      ║ never      ║     —      ║    —  ║    —     ║
╠══════════════╩═════════╩════════════╩════════════╩═══════╩══════════╣
║  5 projects  ·  3 green  ·  1 yellow  ·  0 red  ·  1 never reported ║
╚══════════════════════════════════════════════════════════════════════╝

⚠  Projects needing attention:
  event-pool    never reported — run /report-orchestrator to generate first reports

  Report coverage: 47 daily  ·  12 weekly  ·  3 monthly  ·  1 yearly
```

All data comes from the vault frontmatter — health, total commits, first commit date, and contributors are read from each project-index page.

### Managing projects

Add a project to the reporting:

```
# Local repo (already on disk)
/report-orchestrator add-project name=MyApp path=/home/user/projects/my-app

# Remote repo, already cloned
/report-orchestrator add-project name=ClientX path=/repos/client branches=main tags=client/acme

# Remote repo, not yet cloned (will clone on first run)
/report-orchestrator add-project name=ApiService path=/repos/api url=https://github.com/org/api

# Remote-only (no local clone needed)
/report-orchestrator add-project name=OssLib url=https://github.com/org/lib
```

The skill checks for duplicates and validates the configuration before writing. Four modes are supported:

| Scenario | What happens |
|---|---|
| Local repo, no remote | Reads git log directly. No sync. |
| Local repo with remote | `git pull` on each run. |
| Remote, path provided | Clones to `path` on first run, then pulls. |
| Remote-only (no path) | Bare clone auto-managed in `.cache/NAME.git`. Only history is downloaded, no file contents. |

Remove a project:

```
/report-orchestrator remove-project name=MyApp
```

The skill asks for confirmation, then offers to delete the project's vault files (`Reports/MyApp/` and `Reports/Current/MyApp.md`). If you decline, the files stay in the vault as orphaned nodes.

### Discovering local repos

```
/report-orchestrator discover
```

Shows your full vault at a glance: tracked projects with their last report date and health status, plus any untracked git repos found on disk.

```
╔══════════════════════════════════════════════════════════════╗
║  discover — vault overview                                   ║
╠══════════════════════════════════════════════════════════════╣
║  Tracked projects (5)                                        ║
║                                                              ║
║    SAFARI               last report: 2026-03-22  health: green   ║
║    event-rental         last report: 2026-03-22  health: yellow  ║
║    event-pool           last report: never       health: —       ║
║                                                              ║
╠══════════════════════════════════════════════════════════════╣
║  Untracked repos found (2)                                   ║
║                                                              ║
║   1. my-app    /home/user/projects/my-app  [main] 2026-03-18  142 commits  (since 2024-01-15) ║
║   2. client-x  /home/user/projects/client  [main] 2026-02-28   67 commits  (since 2025-06-01) ║
╚══════════════════════════════════════════════════════════════╝

Add which repos? (numbers like "1 3", "all", or Enter to skip):
```

For each selected repo, you're asked individually when to start tracking:

```
Track my-app (142 commits since 2024-01-15):
  Backfill from when?  [all | YYYY-MM-DD | Enter = today only]
  >
```

- `all` → populate from the first commit
- `YYYY-MM-DD` → populate from that date
- Enter → today's report only

Reports are generated immediately after adding, with no extra command needed.

Set `DISCOVER_PATHS` in `.env` to control where it looks (colon-separated, max depth 4):

```bash
DISCOVER_PATHS=/home/user/projects:/home/user/work
```

Default: `~/projects:~/repos:~/code:~/workspace:~/dev`.

### Already have an existing project?

If your project has weeks or months of Git history, you don't start from scratch. When you add a project via `discover`, you're asked from when to backfill — answer `all` or a date and the vault is populated in one shot.

You can also trigger backfill manually at any time:

```
/report-orchestrator backfill=all          ← from the very first commit
/report-orchestrator backfill=2025-11-01   ← from a chosen date
```

## Custom tags

Every report always includes two base tags: `report/<type>` and `project/<name>`. You can add your own on top via two mechanisms:

**Per-project** (permanent, in `projects.config`):
```
# 5th column = tags applied to every report for this project
ClientX|/home/user/projects/client-x||main|client/acme,team/backend
```

**Per-run** (one-off, passed directly):
```
/report-orchestrator tags=sprint/42,urgent
```

Both sources are merged with the base tags and deduplicated. The resulting YAML frontmatter looks like:
```yaml
tags: [report/daily, "project/ClientX", "client/acme", "team/backend", "sprint/42"]
```

Tags then drive filtering in Obsidian's search, Dataview queries, and graph view coloring. To add a custom color for your tags in the graph, open `.obsidian/graph.json` and add an entry to `colorGroups`:
```json
{ "query": "tag:#client/acme", "color": { "a": 1, "rgb": 16711935 } }
```

## Graph view

Reports are linked via a `parent` field in their frontmatter, creating a visual tree in Obsidian's graph view:

```
Working (Dashboard)
└── ProjectName              ← project index
    └── Y-2026               ← yearly report
        └── M-03             ← monthly report
            └── W-1          ← weekly report
                └── D-19     ← daily report
```

Nodes are color-coded by type (daily / weekly / monthly / yearly / project). To apply the pre-configured colors and forces, copy `graph.json` (at the root of this repo) to your vault's `.obsidian/` folder.

> **Note:** Color groups are evaluated top-down in Obsidian (first match wins). `graph.json` puts report-type colors first so they take precedence. The `project` rule is last and only applies to the project index node.

## Vault structure

```
Reports/
├── Current/
│   └── ProjectName.md         ← link to today's daily (always up to date)
└── ProjectName/
    ├── ProjectName.md         ← project index (all time)
    └── Y-2026/
        ├── Y-2026.md          ← yearly report
        └── M-03/
            ├── M-03.md        ← monthly report
            └── W-1/
                ├── W-1.md     ← weekly report
                └── D-19.md    ← daily report
```

## Customizing report templates

Edit the files in `Templates/` to change the format of your reports. Each template uses `{{placeholders}}` for project name, dates, commit list, AI summary, and graph hierarchy links. See the template files themselves for the full list.

After editing, re-run the skill for any date to regenerate:

```
/report-orchestrator date=2026-03-18
```

See [`examples/output/`](examples/output/) for what filled reports look like.

## Vault audit

If your graph looks off (phantom nodes, isolated clusters, broken links), run:

```bash
bash scripts/check-vault.sh
```

It validates the entire vault structure against the expected hierarchy for each project:
- **Phantom folders**: a `W-N/` or `M-MM/` folder with no aggregate report inside
- **Cross-hierarchy links**: a daily pointing to the wrong week, a week to the wrong month, etc.
- **Broken parents**: `parent` wikilink pointing to a file that doesn't exist
- **Broken `Current/` pointers**: today's shortcut pointing to a deleted or renamed daily
- **Zero-commit reports**: reports that should never have been written
- **Wrong or missing tags**: `report/daily`, `report/weekly`, etc. missing from frontmatter, which breaks graph node coloring

Exits with code `1` if any errors are found, `0` if clean.

## Cost

Very low. The skill reads Git logs and writes Markdown files. Claude only generates short prose summaries from your commit history, making each run lightweight on tokens.

## Troubleshooting

**`obsidian: command not found`**
→ Enable the Obsidian CLI community plugin in Obsidian (Settings → Community plugins). On Windows, also create the `~/bin/obsidian` wrapper shown in [Prerequisites](#prerequisites).

**`VAULT_NAME is not set`**
→ Open `.env` and set `VAULT_NAME` to the vault folder name shown in Obsidian's title bar.

**`Vault not found`**
→ The Obsidian CLI only recognizes vaults opened in Obsidian at least once. Open Obsidian → "Open folder as vault" → select your vault folder.

**`ERROR: '$PROJECT_PATH' is not a git repository`**
→ The path doesn't exist or was never cloned. Add a `url=` to auto-clone on first run, or clone manually first.

**`Clone failed for https://...`**
→ Set `GITHUB_TOKEN=your_token` in `.env` for private HTTPS repos.

## License

[MIT](LICENSE)
