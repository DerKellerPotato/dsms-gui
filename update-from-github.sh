#!/bin/bash
# update-from-github.sh — fetch the latest dsms (CLI) and dsms-gui (this app)
# from GitHub and (re)install both. Invoked as root via pkexec from the GUI's
# "Update from GitHub" debug action.
#
# Usage: update-from-github.sh <cli-repo-url> <gui-repo-url> [branch]
set -euo pipefail

CLI_URL="${1:?usage: update-from-github.sh <cli-repo> <gui-repo> [branch]}"
GUI_URL="${2:?usage: update-from-github.sh <cli-repo> <gui-repo> [branch]}"
BRANCH="${3:-main}"

[[ $EUID -eq 0 ]] || { echo "ERROR: must run as root (pkexec)"; exit 1; }
command -v git >/dev/null || { echo "ERROR: git not installed (apt install git)"; exit 1; }

TMP=$(mktemp -d /tmp/dsms-update-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo "=== Updating DSMS from GitHub (branch: ${BRANCH}) ==="

echo ""
echo "--- [1/2] CLI: ${CLI_URL} ---"
git clone --depth 1 --branch "$BRANCH" "$CLI_URL" "$TMP/dsms"
bash "$TMP/dsms/install.sh"

echo ""
echo "--- [2/2] GUI: ${GUI_URL} ---"
git clone --depth 1 --branch "$BRANCH" "$GUI_URL" "$TMP/dsms-gui"
bash "$TMP/dsms-gui/install.sh"

echo ""
echo "=== Update complete ==="
echo "Restart DSMS Control Center to load the updated GUI."
