#!/bin/bash
# Build a Debian/Ubuntu .deb package for the DSMS GTK desktop app.
# Usage: bash packaging/build-deb.sh [--version X.Y] [--out DIR]
#
# Requires: dpkg-deb (apt install dpkg-dev)
# Result:   <out>/dsms-gui_<version>_all.deb
#
# The package declares "Depends: dsms", so installing it pulls the
# command-line tool in automatically.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.0"
OUT_DIR="${REPO}/dist"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --out)     OUT_DIR="$2";  shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

PKG_NAME="dsms-gui"

echo "=== DSMS GUI .deb builder ==="
echo "  Version : ${VERSION}"
echo "  Output  : ${OUT_DIR}/"
echo ""

command -v dpkg-deb &>/dev/null || { echo "ERROR: dpkg-deb not found (apt install dpkg-dev)"; exit 1; }

# Build staging in a native Linux tmpfs to keep correct POSIX permissions.
# NTFS mounts (/mnt/c/...) report 777 for all dirs; dpkg-deb rejects that.
BUILD_TMP=$(mktemp -d /tmp/dsms-gui-deb-XXXXXX)
PKG_DIR="${BUILD_TMP}/${PKG_NAME}_${VERSION}_all"
trap 'rm -rf "$BUILD_TMP"' EXIT
echo "  Staging : ${PKG_DIR} (Linux tmpfs)"
mkdir -p "$PKG_DIR"

inst() {
    local src="$1" dst="$2" mode="${3:-644}"
    mkdir -p "$(dirname "${PKG_DIR}${dst}")"
    install -m "$mode" "$src" "${PKG_DIR}${dst}"
}

# ---- App + assets ---------------------------------------------------------
inst "${REPO}/dsms-gui"               /usr/local/bin/dsms-gui 755
inst "${REPO}/dsms-gui.desktop"       /usr/share/applications/dsms-gui.desktop 644
inst "${REPO}/com.dsms.pkexec.policy" /usr/share/polkit-1/actions/com.dsms.pkexec.policy 644
inst "${REPO}/update-from-github.sh"  /usr/local/lib/dsms-gui/update-from-github.sh 755

# ---- DEBIAN/control -------------------------------------------------------
mkdir -p "${PKG_DIR}/DEBIAN"
cat > "${PKG_DIR}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Architecture: all
Maintainer: DSMS Project <dsms@example.com>
Depends: dsms (>= 1.0), python3, python3-gi, gir1.2-gtk-3.0,
 policykit-1 | polkitd
Recommends: git
Section: admin
Priority: optional
Description: DSMS Control Center — desktop app for DSMS
 GTK 3 desktop front-end for DSMS (Domain & Storage Management System).
 Edits /etc/dsms/dsms.conf through forms, applies the configuration, joins
 the domain and imports/exports configuration files.
 .
 The app runs as a normal user; privileged actions go through pkexec to the
 'dsms' command-line tool (this package's dependency). A debug action can
 fetch and reinstall the latest dsms / dsms-gui straight from GitHub.
EOF

# ---- DEBIAN/postinst ------------------------------------------------------
cat > "${PKG_DIR}/DEBIAN/postinst" <<'POSTINST'
#!/bin/bash
set -e
# Refresh the desktop menu database if the tool is available.
command -v update-desktop-database >/dev/null && \
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
echo "DSMS Control Center installed. Launch it from the application menu."
POSTINST
chmod 755 "${PKG_DIR}/DEBIAN/postinst"

# ---- Build ----------------------------------------------------------------
DEB_TMP="${BUILD_TMP}/${PKG_NAME}_${VERSION}_all.deb"
dpkg-deb --build --root-owner-group "$PKG_DIR" "$DEB_TMP"

mkdir -p "$OUT_DIR"
DEB="${OUT_DIR}/${PKG_NAME}_${VERSION}_all.deb"
cp "$DEB_TMP" "$DEB"

echo ""
echo "=== Build complete ==="
echo "  ${DEB}"
echo ""
echo "Install: sudo apt install ./${PKG_NAME}_${VERSION}_all.deb   # pulls in dsms"
