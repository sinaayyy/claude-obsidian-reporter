# claude-obsidian-reporter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-blueviolet?logo=anthropic&logoColor=white)](https://claude.ai/claude-code)
[![Obsidian](https://img.shields.io/badge/Obsidian-plugin-7C3AED?logo=obsidian&logoColor=white)](https://obsidian.md)
[![GitHub Stars](https://img.shields.io/github/stars/sinaayyy/claude-obsidian-reporter?style=social)](https://github.com/sinaayyy/claude-obsidian-reporter)

Type `/report-orchestrator` at the end of your day. Claude reads your Git commits and writes structured reports directly into your Obsidian vault. No copy-pasting, no manual writing.

What makes it different: reports are a **bottom-up AI synthesis**. Each level re-reads the raw commits and writes fresh prose at the right altitude, from today's specific tasks up to the full story of the project.

<img src="docs/dashboard_preview_img.jpg" height="200" alt="Reports Dashboard" /> <img src="docs/graph_example.png" height="200" alt="Graph View" />

## What you get

| Level | Scope | Tone | Subject |
|---|---|---|---|
| Daily | Today | Terse, first-person: what moved, what's blocked | *I* |
| Weekly | Week to date | Team-level: tasks compressed into outcomes | *the team* |
| Monthly | Month to date | Data-grounded: delivery vs. plan, risks surfacing | *the workstream* |
| Yearly | Year to date | Narrative: thematic, acknowledges difficulty | *the project* |
| Project index | All time | Essay: what this project is and what it built | *the project* |

All levels are written on every run and kept up to date. Missed a day? The skill auto-detects and fills gaps from the current week. Starting on an existing project? `backfill=all` populates everything from the first commit.

## How it works

- **Only reads commit messages.** No source files, no diffs. If most messages are uninformative (`wip`, `fix`, `...`), falls back to reading changed file names only. Never file contents.
- **Synthesizes at every level.** Claude calibrates its writing to the level: terse task log for daily, team outcome summary for weekly, delivery health for monthly, thematic narrative for yearly. Each one the right register for its audience.
- **Writes directly into Obsidian** via the CLI plugin. No intermediate files, no copy-paste.
- **Runs entirely inside your Claude Code session.** No background processes, no subshells spawned.
- **Vault structure mirrors the time hierarchy.** `Y-YYYY/M-MM/W-NN/D-DD.md` with `parent` links between levels, so Obsidian's graph view builds the tree automatically.

## Prerequisites

- [Obsidian](https://obsidian.md) with the **Obsidian CLI** community plugin enabled (your vault must have been opened in Obsidian at least once so the CLI can find it by name)
- [Claude Code](https://claude.ai/claude-code) installed and authenticated
- Git 2.x+
- [Dataview](https://github.com/blacksmithgu/obsidian-dataview) plugin (optional, required for the auto-generated dashboard)

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
LANGUAGE=English                # optional, any language: French, Spanish, Japanese...
```

Finally, add your projects to `projects.config`:

```
# ProjectName | /absolute/path/to/repo | optional_git_url | optional_branches | optional_tags
MyApp|/home/user/projects/my-app|
ClientX|/home/user/projects/client-x||main|client/acme,team/backend
```

The `optional_tags` column lets you attach permanent tags to a project; they'll be included in every report generated for it (see [Custom tags](#custom-tags)).

## Usage

```
/report-orchestrator                                      ← today
/report-orchestrator date=2026-03-14                      ← specific date
/report-orchestrator language=French                      ← reports in French
/report-orchestrator tags=sprint/42,client/acme           ← add tags to all reports today
/report-orchestrator check                                ← audit vault structure only
/report-orchestrator fix                                  ← audit + auto-fix all issues
/report-orchestrator add-project name=X path=/repo       ← add a project to projects.config
/report-orchestrator remove-project name=X               ← remove a project (with optional vault cleanup)
```

Open Claude Code in the `claude-obsidian-reporter` directory (where `projects.config` lives) and run the command. Reports appear in your vault instantly. No need to have Obsidian open.

### Already have an existing project?

If your project has weeks or months of Git history, you don't start from scratch. Use `backfill` to generate all missing reports in one shot:

```
# Backfill from the very first commit
/report-orchestrator backfill=all

# Backfill from a chosen date
/report-orchestrator backfill=2025-11-01
```

Your vault goes from empty to fully populated in a single run.

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

## Sanity check

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

**`Vault not found`**
→ The Obsidian CLI only recognizes vaults that have been opened in Obsidian at least once. Open Obsidian → "Open folder as vault" → select your vault folder. After that the CLI will find it by name.

**`ERROR: '$PROJECT_PATH' is not a git repository`**
→ The path doesn't exist or was never cloned. Add a `git_url` to auto-clone, or clone manually first.

**`Clone failed for https://...`**
→ Set `GITHUB_TOKEN=your_token` in `.env` for private HTTPS repos.

## License

[MIT](LICENSE)
