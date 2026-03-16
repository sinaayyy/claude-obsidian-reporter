# claude-obsidian-reporter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet?logo=anthropic&logoColor=white)](https://claude.ai/claude-code)
[![Obsidian](https://img.shields.io/badge/Obsidian-plugin-7C3AED?logo=obsidian&logoColor=white)](https://obsidian.md)
[![GitHub Stars](https://img.shields.io/github/stars/sinaayyy/claude-obsidian-reporter?style=social)](https://github.com/sinaayyy/claude-obsidian-reporter)

> Type `/report-orchestrator` at the end of your day. Claude reads your Git commits, writes a structured report, and saves it directly into your Obsidian vault.

That's it. No copy-pasting, no manual writing. Just one command.

<img src="docs/dashboard_preview_img.jpg" height="200" alt="Reports Dashboard" /> <img src="docs/graph_example.png" height="200" alt="Graph View" />

## What you get

| When you run it | Reports written |
|---|---|
| Any day | Daily report |
| Friday | Daily + Weekly summary |
| Last day of month | Daily + Monthly summary |
| First install on existing project | Run `backfill=all` or `backfill=YYYY-MM-DD` — generates everything from day one or from a chosen date |

Forgot to run it yesterday? No problem — the skill **auto-detects missing days** from the current week and fills them automatically.

## Prerequisites

- [Obsidian](https://obsidian.md) with the **Obsidian CLI** community plugin enabled
- [Claude Code](https://claude.ai/claude-code) installed and authenticated
- Git 2.x+
- [Dataview](https://github.com/blacksmithgu/obsidian-dataview) plugin (optional — required for the auto-generated dashboard)

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

Open Claude Code in the `claude-obsidian-reporter` directory (where `projects.config` lives) and run the command. Reports appear in your vault instantly — no need to have Obsidian open.

### Already have an existing project?

If your project has weeks or months of Git history, you don't start from scratch — use `backfill` to generate all missing reports in one shot:

```
# Backfill from the very first commit
/report-orchestrator backfill=all

# Backfill from a chosen date
/report-orchestrator backfill=2025-11-01
```

Your vault goes from empty to fully populated in a single run.

## Graph view

Reports are linked via a `parent` field in their frontmatter, creating a visual tree in Obsidian's graph view:

```
Dashboard
└── ProjectName          ← project index (larger node = more reports)
    └── YYYY-MM          ← monthly report
        └── WNN          ← weekly report
            └── daily    ← daily reports
```

Nodes are color-coded by type (daily / weekly / monthly / project) and grouped by project. To apply the pre-configured colors and forces, copy `graph.json` (at the root of this repo) to your vault's `.obsidian/` folder.

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

Edit the files in `Templates/` to change the format of your reports. Each template uses `{{placeholders}}` for project name, dates, commit list, AI summary, and graph hierarchy links — see the template files themselves for the full list.

After editing, re-run the skill for any date to regenerate:

```
/report-orchestrator date=2026-03-18
```

See [`examples/output/`](examples/output/) for what filled reports look like.

## Cost

Very low — the skill reads Git logs and writes Markdown files. Claude only generates short prose summaries from your commit history, making each run lightweight on tokens.

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
