# claude-obsidian-reporter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: bash](https://img.shields.io/badge/shell-bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)](#platform-notes)
[![Claude Code](https://img.shields.io/badge/powered%20by-Claude%20Code-blueviolet.svg)](https://claude.ai/claude-code)

> End-of-day slash command for Claude Code: tracks your Git activity and writes structured daily, weekly, and monthly reports directly into your Obsidian vault.

## What it does

Run `/report-orchestrator` at the end of your day. Claude reads your Git history, summarizes the commits, and writes Markdown reports into your Obsidian vault through the Obsidian CLI:

| When you run it | Reports generated |
|---|---|
| Any day | Daily report |
| Friday | Daily + Weekly report |
| Last day of month | Daily + Monthly report |
| Friday AND last day of month | Daily + Weekly + Monthly |

To backfill a specific date: `/report-orchestrator date=2026-03-14`

## Vault structure

Reports are organized in a nested hierarchy — browse by month, open a week, see the daily breakdowns:

```
Reports/
├── Current/
│   └── ProjectName.md              ← always today's daily (overwritten each run)
└── ProjectName/
    └── YYYY-MM/                    ← monthly folder
        ├── ProjectName-YYYY-MM.md  ← monthly report
        └── WNN/                    ← weekly folder
            ├── ProjectName-WNN-YYYY.md   ← weekly report
            └── Daily/
                ├── ProjectName-YYYY-MM-DD.md   ← Monday
                ├── ProjectName-YYYY-MM-DD.md   ← Tuesday
                └── ...                         ← accumulates through the week
```

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| [Obsidian](https://obsidian.md) | v1.12+ | With **Obsidian CLI** community plugin enabled |
| [Claude Code CLI](https://claude.ai/claude-code) | any | Authenticated (`claude --version`) |
| Git | 2.x+ | Available in `$PATH` |
| Bash | 4+ (GNU) or 3+ (BSD) | Linux / macOS / Git Bash on Windows |

### Windows: Git Bash wrapper (required)

The Obsidian CLI on Windows has a known issue with Git Bash — commands with parameters fail because Git Bash resolves `obsidian` to `Obsidian.exe` instead of `Obsidian.com`. Create a one-line wrapper to fix it:

```bash
mkdir -p ~/bin
echo '#!/bin/bash' > ~/bin/obsidian
echo '"/c/Users/$USERNAME/AppData/Local/Programs/Obsidian/Obsidian.com" "$@"' >> ~/bin/obsidian
chmod +x ~/bin/obsidian
```

Then verify: `which obsidian` should point to `~/bin/obsidian`.

## Quick Start

```bash
# 1. Clone the repo into your Claude Code project directory
git clone https://github.com/sinaayyy/claude-obsidian-reporter.git
cd claude-obsidian-reporter

# 2. Run setup
bash setup-local.sh          # Linux / macOS / Git Bash
# OR double-click install-windows.bat on Windows

# 3. Fill in .env (VAULT_NAME and VAULT_PATH)
# 4. Add your projects to projects.config
# 5. Open Obsidian with your vault loaded
# 6. In Claude Code: /report-orchestrator
```

## Configuration

### .env

```bash
# Absolute path to your Obsidian vault folder
# Linux/macOS: VAULT_PATH=/home/user/MyNotes
# Windows/Git Bash: VAULT_PATH=/c/Users/YourName/Documents/MyNotes
VAULT_PATH=

# Short name of your vault — the folder name shown in Obsidian's title bar
# Example: if vault path ends in /MyNotes, set VAULT_NAME=MyNotes
VAULT_NAME=

# Language for generated reports (default: English)
# Any natural language works: French, Spanish, German, Japanese...
LANGUAGE=English

# Required only for private repos via HTTPS
# Generate at: https://github.com/settings/tokens (scope: repo)
GITHUB_TOKEN=
```

### projects.config

```
# Format: ProjectName|/absolute/local/path|git_url
#
# git_url is optional:
#   - empty       → local repo only (already cloned)
#   - https://    → public, or private with GITHUB_TOKEN in .env
#   - git@github  → private via SSH (key must be loaded)
```

| Column | Required | Example |
|---|---|---|
| `ProjectName` | yes | `MyApp` |
| `/absolute/path` | yes | `/home/user/projects/my-app` |
| `git_url` | no | `git@github.com:user/repo.git` |

See [`examples/projects.config.example`](examples/projects.config.example) for all patterns.

### Regenerating reports after a template change

After editing a template, regenerate your existing reports:

```bash
# Single day (skill — always overwrites)
/report-orchestrator date=2026-03-18

# Full date range (shell)
bash scripts/catchup-missed-days.sh --from 2026-03-01 --to 2026-03-31 --force
```

Without `--force`, the shell script skips dates that already have a report file.

### Customizing report templates

Edit the files in `Templates/` to change the structure of your reports:

| File | Used for |
|---|---|
| `Templates/daily-report-template.md` | Every daily report |
| `Templates/weekly-report-template.md` | Friday weekly reports |
| `Templates/monthly-report-template.md` | End-of-month reports |

The skill reads these files at runtime and fills in the `{{placeholders}}`:

| Placeholder | Content |
|---|---|
| `{{project}}` | Project name |
| `{{date}}` / `{{week}}` / `{{month}}` / `{{year}}` | Date fields |
| `{{nb_commits}}` | Number of commits |
| `{{liste_commits}}` | Formatted commit list |
| `{{resume_taches}}` | AI-generated summary (respects `LANGUAGE`) |
| `{{highlights}}` | Key wins/themes (monthly only) |
| `{{daily_links}}` | Wikilinks to daily reports (weekly template) |
| `{{weekly_links}}` | Wikilinks to weekly reports (monthly template) |

See [`examples/output/`](examples/output/) for what filled reports look like.

## Usage

### Primary: Claude Code skill

```
/report-orchestrator                           ← today's date, English
/report-orchestrator date=2026-03-14           ← specific date
/report-orchestrator language=French           ← reports in French
/report-orchestrator date=2026-03-14 language=Spanish
```

Run this at the end of your workday. The skill runs entirely inside your active Claude Code session — no background processes.

### Advanced: shell scripts (no Claude Code required)

```bash
# End-of-day (same auto-detection logic as the skill)
bash scripts/report-orchestrator.sh
bash scripts/report-orchestrator.sh --date 2026-03-14

# Single mode
bash scripts/trigger-report.sh --mode daily
bash scripts/trigger-report.sh --mode weekly
bash scripts/trigger-report.sh --mode monthly

# Backfill a date range
bash scripts/catchup-missed-days.sh --from 2026-03-01 --to 2026-03-13
```

## How it works

```
Git repos (local / GitHub)
       │
       ▼
/report-orchestrator  (Claude Code skill — runs in your active session)
  ├─ Detect day → daily always, +weekly on Fri, +monthly on last day
  ├─ Read projects.config
  ├─ For each project:
  │   ├─ git clone / git pull
  │   ├─ git log extraction
  │   ├─ summarize commits
  │   └─ Obsidian CLI writes reports
  └─ Print summary table
```

All vault writes go through the Obsidian CLI — your graph, Dataview queries, and backlinks stay in sync.

> **Shell-only mode** (no Claude Code session required): `bash scripts/report-orchestrator.sh` — this invokes `claude -p` headlessly to run the same skill.

## Troubleshooting

**`obsidian: command not found`**
→ Enable the Obsidian CLI community plugin inside Obsidian (Settings → Community plugins → Obsidian CLI v1.12+) and make sure it is in your `$PATH`.

**Commands with parameters fail on Windows (exit 127)**
→ The Git Bash + `Obsidian.exe` issue. Set up the [Git Bash wrapper](#windows-git-bash-wrapper-required) above.

**`VAULT_NAME is not set`**
→ Edit `.env` and set `VAULT_NAME` to the short name of your vault (the folder name visible in Obsidian's title bar).

**`ERROR: '$PROJECT_PATH' is not a git repository`**
→ The local path doesn't exist or was never cloned. Add a `git_url` to auto-clone, or clone manually first.

**`Clone failed for https://...`**
→ For private HTTPS repos, set `GITHUB_TOKEN=your_token` in `.env`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
