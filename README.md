# claude-obsidian-reporter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/powered%20by-Claude%20Code-blueviolet.svg)](https://claude.ai/claude-code)

> Type `/report-orchestrator` at the end of your day. Claude reads your Git commits, writes a structured report, and saves it directly into your Obsidian vault.

That's it. No copy-pasting, no manual writing. Just one command.

## What you get

| When you run it | Reports written |
|---|---|
| Any day | Daily report |
| Friday | Daily + Weekly summary |
| Last day of month | Daily + Monthly summary |

Forgot to run it yesterday? No problem — the skill **auto-detects missing days** from the current week and backfills them automatically.

## Prerequisites

- [Obsidian](https://obsidian.md) with the **Obsidian CLI** community plugin enabled
- [Claude Code](https://claude.ai/claude-code) installed and authenticated
- Git 2.x+

## Install

```bash
git clone https://github.com/sinaayyy/claude-obsidian-reporter.git
cd claude-obsidian-reporter
bash setup-local.sh
```

On Windows: double-click `install-windows.bat` instead.

Then open `.env` and fill in:

```bash
VAULT_NAME=MyNotes              # folder name shown in Obsidian's title bar
VAULT_PATH=/home/user/MyNotes   # absolute path to your vault
LANGUAGE=English                # optional — any language: French, Spanish, Japanese...
```

Finally, add your projects to `projects.config`:

```
# ProjectName | /absolute/path/to/repo | optional_git_url
MyApp|/home/user/projects/my-app|
```

## Usage

```
/report-orchestrator                          ← today
/report-orchestrator date=2026-03-14          ← specific date
/report-orchestrator language=French          ← reports in French
```

Open Claude Code in your project directory and run the command. Reports appear in your vault instantly — no need to have Obsidian open.

## Vault structure

Reports are organized so you can navigate month → week → day:

```
Reports/
├── Current/
│   └── ProjectName.md              ← link to today's daily (always up to date)
└── ProjectName/
    └── YYYY-MM/
        ├── ProjectName-YYYY-MM.md  ← monthly report
        └── WNN/
            ├── ProjectName-WNN-YYYY.md   ← weekly report
            └── Daily/
                ├── ProjectName-YYYY-MM-DD.md
                └── ...
```

## Customizing report templates

Edit the files in `Templates/` to change the format of your reports:

| File | Used for |
|---|---|
| `Templates/daily-report-template.md` | Every daily report |
| `Templates/weekly-report-template.md` | Friday weekly reports |
| `Templates/monthly-report-template.md` | End-of-month reports |

Available placeholders:

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

After editing a template, regenerate existing reports:

```bash
# Single day
/report-orchestrator date=2026-03-18

# Date range
bash scripts/catchup-missed-days.sh --from 2026-03-01 --to 2026-03-31 --force
```

See [`examples/output/`](examples/output/) for what filled reports look like.

## Troubleshooting

**`obsidian: command not found`**
→ Enable the Obsidian CLI community plugin in Obsidian (Settings → Community plugins).

**Commands fail on Windows (exit 127)**
→ Git Bash resolves `obsidian` to `Obsidian.exe` instead of `Obsidian.com`. Fix with a wrapper:
```bash
mkdir -p ~/bin
echo '#!/bin/bash' > ~/bin/obsidian
echo '"/c/Users/$USERNAME/AppData/Local/Programs/Obsidian/Obsidian.com" "$@"' >> ~/bin/obsidian
chmod +x ~/bin/obsidian
```

**`VAULT_NAME is not set`**
→ Open `.env` and set `VAULT_NAME` to the vault folder name shown in Obsidian's title bar.

**`ERROR: '$PROJECT_PATH' is not a git repository`**
→ The path doesn't exist or was never cloned. Add a `git_url` to auto-clone, or clone manually first.

**`Clone failed for https://...`**
→ Set `GITHUB_TOKEN=your_token` in `.env` for private HTTPS repos.

## License

[MIT](LICENSE)
