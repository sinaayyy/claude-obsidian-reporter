# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
