#!/bin/bash
# DSMS GUI test runner — pure-Python config tests + shell syntax checks.
# Exit code: 0 = all passed, 1 = failures present

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

BOLD=$'\e[1m'; RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RESET=$'\e[0m'
FAIL=0

echo ""
echo "${BOLD}DSMS GUI Test Suite${RESET}"
echo "Repository: $REPO"
echo ""

# --- Shell syntax check (bash -n) ---
echo "${BOLD}=== shell syntax ===${RESET}"
for f in install.sh update-from-github.sh packaging/build-deb.sh; do
    [[ -f "$f" ]] || continue
    if bash -n "$f"; then
        echo "  ok: $f"
    else
        echo "  ${RED}FAIL: $f${RESET}"; FAIL=1
    fi
done
echo ""

# --- Python config tests ---
echo "${BOLD}=== python ===${RESET}"
if ! command -v python3 &>/dev/null; then
    echo "${YELLOW}SKIP: python3 not found${RESET}"
else
    if python3 -m pytest --version &>/dev/null 2>&1; then
        python3 -m pytest tests/unit -v --tb=short || FAIL=1
    else
        python3 -m unittest discover -s tests/unit -p 'test_*.py' -v || FAIL=1
    fi
fi
echo ""

echo "────────────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
    echo "${GREEN}${BOLD}ALL TESTS PASSED${RESET}"; exit 0
else
    echo "${RED}${BOLD}FAILURES — see above${RESET}"; exit 1
fi
