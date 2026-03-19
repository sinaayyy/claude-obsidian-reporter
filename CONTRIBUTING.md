# Contributing to claude-obsidian-reporter

Thank you for your interest in contributing!

## Prerequisites

- Bash shell (Linux, macOS, or Git Bash on Windows)
- Git 2.x+
- Claude Code CLI (`claude --version`)
- Obsidian v1.12+ with the Obsidian CLI community plugin enabled
- A test Git repository to run reports against

## How to test locally

1. Clone the repo and run setup:
   ```bash
   git clone https://github.com/your-username/claude-obsidian-reporter.git
   cd claude-obsidian-reporter
   bash setup-local.sh
   ```

2. Create a minimal `projects.config` pointing to any local git repo:
   ```
   TestProject|/path/to/any/git/repo|
   ```

3. Run a dry trigger to confirm Claude is invoked correctly:
   ```bash
   bash scripts/trigger-report.sh --project TestProject --path /path/to/any/git/repo
   ```

4. Verify the output note appears in your Obsidian vault under `Daily Notes/`.

## Coding conventions

- Write POSIX-compatible Bash where possible (avoid bash 4+ features when a POSIX alternative exists)
- Comments in English
- Functions have a short doc comment above them explaining purpose and arguments
- Error messages follow the pattern: `[ERROR] <description>. <remediation hint>.`
- Success messages follow: `[OK] <description>.`

## How to submit a PR

1. Fork the repository and create a feature branch:
   ```bash
   git checkout -b feat/my-improvement
   ```

2. Make your changes and test locally (see above).

3. Open a Pull Request against `main` with a clear description of:
   - What problem this solves
   - How you tested it
   - Any platform-specific notes (Linux / macOS / Windows)

4. Fill in the PR template: incomplete PRs may be closed without review.

## How to report a bug

Open a GitHub Issue using the **Bug report** template. Include:
- Your OS and shell version
- Obsidian version and obsidian-cli plugin version
- The exact command you ran
- The full error output (paste it, don't screenshot it)
