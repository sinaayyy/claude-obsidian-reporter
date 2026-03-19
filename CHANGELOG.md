# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [3.0.0] — 2026-03-19

### Added
- **Yearly reports** — `summary.md` generated at `Y-YYYY/` level, auto-triggered on Dec 31 (or updated every run with year-to-date commits); yearly template added
- **`report/yearly` tag** — new base tag for graph coloring
- **`DAY`, `MONTH` variables** — added alongside existing `YEAR`, `WEEK_NUM` for uniform path building
- **`D-DD.md` daily files** — daily reports no longer prefixed with project name (path provides full context)

### Changed
- **New vault structure** — fully uniform `Y-YYYY/M-MM/W-NN/` folder naming; all aggregate reports renamed to `summary.md`; daily files are `D-DD.md`
- **Hierarchy extended** — `parent` chain is now Daily → Weekly → Monthly → Yearly → Project index → Dashboard
- **All four report types run on every run** — weekly, monthly, and yearly are now always overwritten with period-to-date commits (not only at period end); `IS_WEEK_END`/`IS_LAST_DAY`/`IS_LAST_YEAR` retained for catchup only
- **Project index** — now links only to yearly summaries (`Y-YYYY/summary`); navigation down to months/weeks/days is done via parent links
- **Stale report detection** — catchup now compares actual git commit count vs `nb_commits` in frontmatter instead of simple file-exists check; stale reports are regenerated
- **Graph color order fixed** — `colorGroups` reordered so report-type colors (daily/weekly/monthly/yearly) take priority over project color (first match wins in Obsidian)
- **Skip empty reports** — reports with 0 commits are never written at any level, avoiding detached nodes in the graph

### Fixed
- Reports generated after working late were missed on next catchup — stale check now catches them
- `project` tag was overriding report-type colors in graph view — fixed by moving it last in `colorGroups`
- Monthly `parent` was pointing to project index instead of yearly report

---

## [2.0.0] — 2026-03-16

### Added
- **Obsidian graph hierarchy** — all reports linked via `parent` frontmatter (Daily → Weekly → Monthly → Project index → Dashboard), creating a visual tree in Obsidian graph view
- **Project index pages** — auto-generated `PROJECT/PROJECT.md` listing all months and weeks, rebuilt on each monthly run to accumulate links (makes the project node visually larger in the graph)
- **Dataview dashboard** — `Reports/Dashboard.md` bootstrapped on first run with live queries for recent daily, weekly, and monthly reports
- **Tags in frontmatter** — `report/daily`, `report/weekly`, `report/monthly`, `project/PROJECT` for graph coloring and filtering
- **`backfill` parameter** — `/report-orchestrator backfill=all` or `backfill=YYYY-MM-DD` generates all missing reports from a chosen date; ideal for first install on existing projects
- **`WEEK_END_DAY` in `.env`** — configurable end-of-week day for weekly report trigger (default: 5 = Friday; set to 7 for Sunday, etc.)
- **Graph color config** — `graph.json` pre-configured with color groups by report type and project
- **Cost section in README** — noted as low-cost (Git log reads + Markdown writes)
- **Graph and dashboard screenshots** in README

### Changed
- **Wikilink paths corrected** — no `Reports/` prefix in wikilinks (vault root IS the Reports folder)
- **`{{parent_project}}` placeholder** added to monthly template (points to project index, not Dashboard)
- **Placeholder descriptions clarified** in SKILL.md — `parent_weekly` is used in daily, `parent_monthly` in weekly, `parent_project` in monthly
- **Dashboard Dataview queries** use `FROM ""` instead of `FROM "Reports"` and `string()` cast for week/year concatenation
- **`.env.example`** added to repo; `.env` now includes `WEEK_END_DAY` and `LANGUAGE`
- **`projects.config`** cleaned of user-specific paths
- **README** rewritten: backfill section, placeholder table updated, clarified run directory, images side by side

### Fixed
- `examples/output/` wikilinks had `Reports/` prefix — corrected across all three example files
- `monthly-example.md` parent pointed to Dashboard instead of project index — fixed
- `IS_FRIDAY` hardcoded check replaced by `IS_WEEK_END` using configurable `WEEK_END_DAY`

---

## [1.1.0] — 2026-03-15

### Added
- `scripts/report-orchestrator.sh` — end-of-day entry point; auto-detects Friday (weekly) and last day of month (monthly), delegates to `trigger-report.sh`
- `LANGUAGE` variable in `.env` — generate reports in any language (default: English); passed as `language=` argument to the skill
- `VAULT_NAME` variable in `.env` — required for Obsidian CLI vault targeting; added to setup and documented

### Changed
- **Vault structure redesigned** — reports now use a nested hierarchy: `Reports/Current/`, `Reports/PROJECT/YYYY-MM/WNN/`, `Reports/PROJECT/YYYY-MM/WNN/Daily/`; previously wrote to flat `Daily Notes/` and `Journal/Weekly|Monthly/`
- **Skill is now the primary entry point** — `/report-orchestrator` runs inside the active Claude Code session (no background `claude -p` spawned); shell scripts are now the advanced/automation path
- `SKILL.md` — updated vault paths, added `language` input, translated comments to English, added BSD `date` fallback for macOS portability
- `setup-local.sh` — adds `VAULT_NAME` and `LANGUAGE` to generated `.env`; adds `chmod +x` for `report-orchestrator.sh`; removes cron suggestion in favour of skill usage; next steps updated
- `install-windows.bat` — Git path detection now checks both `Program Files` and `Program Files (x86)`
- `Templates/monthly-report-template.md` — fixed redundant `{{month}} {{year}}` title (was rendering as `2026-03 2026`)
- `scripts/catchup-missed-days.sh` — fixed `IFS` read to capture all three config columns (`name|path|url`)
- README fully rewritten to reflect new architecture, skill-first usage, Windows Git Bash wrapper, and `.env` documentation

### Fixed
- `daily:append` failing on Windows Git Bash (exit 127) — documented fix via `Obsidian.com` wrapper in `~/bin/obsidian`
- `--overwrite` flag corrected to `overwrite` (no dashes) in all Obsidian CLI create commands

---

## [1.0.0] — 2026-03-14

### Added
- `setup-local.sh` — interactive setup with Obsidian CLI check, `.env` generation, `projects.config` template
- `scripts/trigger-report.sh` — main entry point; supports `--project`, `--path`, `--url`, `--date`, `--mode`
- `scripts/catchup-missed-days.sh` — backfill reports for a date range (`--from` / `--to`)
- `.claude/skills/report-orchestrator/SKILL.md` — Claude skill with explicit git log commands, template variable mapping, and full Obsidian CLI command sequences
- `Templates/` — daily, weekly, and monthly Markdown report templates
- `examples/` — `projects.config.example` and filled output examples (daily, weekly, monthly)
- `LICENSE` — MIT
- `CONTRIBUTING.md` — prerequisites, local testing guide, coding conventions, PR process
- `install-windows.bat` — Windows launcher (opens Git Bash and runs `setup-local.sh`)
- `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

### Platform support
- Linux (primary)
- macOS (GNU/BSD date handled)
- Windows via Git for Windows (Git Bash)
