#!/bin/bash
# DSMS GUI — installer for the GTK desktop app (DSMS Control Center).
#
# Installs the app, its menu entry, the polkit policy and the GitHub update
# helper. The app drives the 'dsms' command-line tool, which is a dependency
# and must be installed too:  https://github.com/DerKellerPotato/dsms
#
# Usage: sudo bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Error: run as root (sudo bash install.sh)"; exit 1; }

echo "=== DSMS GUI Installer ==="
echo ""

install -m 755 "${SCRIPT_DIR}/dsms-gui" /usr/local/bin/dsms-gui
echo "  Installed: /usr/local/bin/dsms-gui"

install -d /usr/share/applications /usr/share/polkit-1/actions /usr/local/lib/dsms-gui
install -m 644 "${SCRIPT_DIR}/dsms-gui.desktop" \
    /usr/share/applications/dsms-gui.desktop
install -m 644 "${SCRIPT_DIR}/com.dsms.pkexec.policy" \
    /usr/share/polkit-1/actions/com.dsms.pkexec.policy
install -m 755 "${SCRIPT_DIR}/update-from-github.sh" \
    /usr/local/lib/dsms-gui/update-from-github.sh
echo "  Installed: menu entry, polkit policy, update helper"

# --- Dependency checks (warn only) ---
if ! python3 -c "import gi" 2>/dev/null; then
    echo "  NOTE: dsms-gui needs PyGObject:  apt install python3-gi gir1.2-gtk-3.0"
fi
if ! command -v dsms >/dev/null && [[ ! -x /usr/local/bin/dsms ]]; then
    echo "  NOTE: the 'dsms' command is not installed — the GUI needs it."
    echo "        Install from https://github.com/DerKellerPotato/dsms"
    echo "        (sudo bash install.sh), or 'apt install dsms'."
fi

echo ""
echo "=== Installation complete ==="
echo "Launch 'DSMS Control Center' from the application menu, or run: dsms-gui"
