#!/bin/bash

echo "=== Installing claude-obsidian-reporter ==="

# --- Create required directories ---
mkdir -p scripts Templates .claude/skills/report-orchestrator logs
echo "   [OK] Directory structure ready."

# --- CRITICAL Obsidian CLI CHECK ---
if ! command -v obsidian &> /dev/null; then
    echo ""
    echo "ERROR: obsidian-cli is REQUIRED and not found."
    echo "→ Open Obsidian → Settings → Community plugins → enable 'Obsidian CLI' (v1.12+)"
    echo ""
    exit 1
fi
echo "   [OK] Obsidian CLI detected and ready for reporting."

# --- Git check ---
if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed."
    exit 1
fi
echo "   [OK] git detected."

# --- Create .env template if missing ---
if [[ ! -f ".env" ]]; then
  cat > .env << 'EOF'
# Absolute path to your Obsidian vault folder.
# This MUST match the vault currently open in Obsidian.
# Example (Linux/macOS): VAULT_PATH=/home/user/ObsidianVault
# Example (Windows/Git Bash): VAULT_PATH=/c/Users/YourName/Documents/MyVault
VAULT_PATH=

# Short name of your Obsidian vault: this is the folder name shown in Obsidian's title bar.
# Example: if your vault is at /home/user/MyNotes, set VAULT_NAME=MyNotes
VAULT_NAME=

# Language for generated reports (default: English)
# Examples: English, French, Spanish, German, Japanese...
LANGUAGE=English

# GitHub personal access token: required ONLY for private repos accessed via HTTPS
# Generate one at: https://github.com/settings/tokens (scope: repo)
# Leave empty if you use SSH or only public repos.
GITHUB_TOKEN=
EOF
  echo "   [OK] .env created: set VAULT_PATH and VAULT_NAME before running reports."
else
  echo "   [OK] .env already exists, skipping."
fi

# --- Vault config check ---
if [[ -f ".env" ]]; then
  source .env 2>/dev/null || true
fi
if [[ -z "$VAULT_PATH" ]]; then
  echo ""
  echo "   [WARN] VAULT_PATH is not set in .env"
  echo "          → Edit .env and set VAULT_PATH to the absolute path of your Obsidian vault."
  echo "          → The vault must be currently open in Obsidian when you run reports."
else
  echo "   [OK] VAULT_PATH = $VAULT_PATH"
fi
if [[ -z "$VAULT_NAME" ]]; then
  echo ""
  echo "   [WARN] VAULT_NAME is not set in .env"
  echo "          → Edit .env and set VAULT_NAME to the short name of your vault (the folder name)."
  echo "          → Example: if your vault path ends in /MyNotes, set VAULT_NAME=MyNotes"
else
  echo "   [OK] VAULT_NAME = $VAULT_NAME"
fi

# --- Create default projects.config if missing ---
if [[ ! -f "projects.config" ]]; then
  cat > projects.config << 'EOF'
# Format: ProjectName|/absolute/local/path|git_url
#
# git_url column is optional:
#   - Leave empty      → local repo only (must already be cloned)
#   - https:// URL     → public repo, or private with GITHUB_TOKEN in .env
#   - git@github.com   → private repo via SSH (key must be loaded)
#
# Examples:
# LocalOnly|/home/user/projects/my-local-project|
# PublicRepo|/home/user/projects/pub|https://github.com/user/public-repo
# PrivateHTTPS|/home/user/projects/priv|https://github.com/user/private-repo
# PrivateSSH|/home/user/projects/ssh-priv|git@github.com:user/private-repo.git
EOF
  echo "   [OK] projects.config created (edit to add your projects)."
else
  echo "   [OK] projects.config already exists, skipping."
fi

# --- SSH agent hint ---
echo ""
echo "   [INFO] Using private repos via SSH?"
echo "          Make sure your SSH key is loaded: ssh-add ~/.ssh/id_ed25519"

# --- Make scripts executable ---
chmod +x scripts/trigger-report.sh
chmod +x scripts/catchup-missed-days.sh
chmod +x scripts/report-orchestrator.sh
chmod +x setup-local.sh
echo "   [OK] Scripts are executable."

echo ""
echo "=== Setup complete ==="
echo "Next steps:"
echo "  1. Edit .env      : set VAULT_PATH and VAULT_NAME"
echo "  2. Edit projects.config: add your repositories"
echo "  3. Open Obsidian and make sure the CLI plugin is active"
echo "  4. In Claude Code, run: /report-orchestrator"
echo ""
echo "  Optional (run from terminal without opening Claude Code's UI):"
echo "    bash scripts/report-orchestrator.sh"
echo "    (requires Claude Code CLI installed and authenticated)"
