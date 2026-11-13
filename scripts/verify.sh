#!/usr/bin/env bash
# =============================================================================
#  scripts/verify.sh — is this installation actually working?
# =============================================================================
#
#  Runs the headless half of the verification checklist in README.md:
#
#    * Neovim version
#    * every plugin installed and loadable
#    * every Lua file parses
#    * the keymap registry has no duplicate keys
#    * every documented command exists
#    * the shortcuts for THIS platform are bound
#    * colourscheme, mouse and clipboard are on
#    * language servers, formatters and debug adapters are configured
#
#  Exit code 0 means "the config is sound". Anything else prints what failed.
#
#  Usage:
#    bash scripts/verify.sh
#    make verify
#
#  Safe to run any time. It never changes your config; it opens Neovim
#  headless and throws it away.
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'

echo "${BOLD}Verifying the Neovim config${RESET}  ${DIM}$ROOT${RESET}"

problems=0

note() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
bad()  { problems=$((problems + 1)); printf '  %s✗%s %s\n' "$RED" "$RESET" "$*"; }
good() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }

# ---------------------------------------------------------------------------
# Static checks: things a headless Neovim cannot tell us
# ---------------------------------------------------------------------------

if ! command -v nvim >/dev/null 2>&1; then
  bad "nvim is not on PATH"
  echo
  echo "Install it first:  ./install.sh"
  exit 1
fi
good "$(nvim --version | head -1)"

if [[ -x install.sh ]]; then
  good "install.sh is executable"
else
  note "install.sh is not executable (chmod +x install.sh)"
fi

for file in README.md KEYBINDINGS.md docs/TUTORIAL.md; do
  if [[ -s "$file" ]]; then
    good "$file present"
  else
    bad "$file is missing or empty"
  fi
done

# Shell syntax of the installers, when the tools exist.
if command -v bash >/dev/null 2>&1; then
  if bash -n install.sh 2>/dev/null; then
    good "install.sh has valid shell syntax"
  else
    bad "install.sh has a shell syntax error"
  fi
fi

if command -v shellcheck >/dev/null 2>&1; then
  # Only errors, not style: this script is meant to run everywhere.
  if shellcheck -S error install.sh extras/tmux/ide >/dev/null 2>&1; then
    good "shellcheck: no errors in install.sh / ide"
  else
    note "shellcheck found issues (run: shellcheck install.sh extras/tmux/ide)"
  fi
else
  note "shellcheck not installed, skipping the shell lint"
fi

# ---------------------------------------------------------------------------
# Dynamic checks: load the config headless and interrogate it
# ---------------------------------------------------------------------------

echo
echo "${BOLD}Loading the config headless…${RESET}"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# --clean would skip the user config, which is the opposite of what we want.
nvim --headless -c "lua dofile('scripts/health.lua')" -c qa >"$LOG" 2>&1
status=$?

# Print the PASS/FAIL lines from the Lua side, indented.
if grep -q '^PASS' "$LOG"; then
  sed -n 's/^PASS  /  ✓ /p' "$LOG"
fi
if grep -q '^FAIL' "$LOG"; then
  sed -n 's/^FAIL  /  ✗ /p' "$LOG" | while IFS= read -r line; do printf '%s%s%s\n' "$RED" "$line" "$RESET"; done
  problems=$((problems + $(grep -c '^FAIL' "$LOG")))
fi
if grep -q '^NOTE' "$LOG"; then
  sed -n 's/^NOTE  /  ! /p' "$LOG"
fi

# Startup errors that never reached a check (a missing plugin, a bad spec).
if grep -qE 'Error (in|executing)|E5113|Lua chunk' "$LOG"; then
  echo
  bad "Neovim reported startup errors:"
  grep -E 'Error (in|executing)|E5113|Lua chunk' -A3 "$LOG" | head -20 | sed 's/^/      /'
fi

echo
if ((status == 0 && problems == 0)); then
  echo "${GREEN}${BOLD}Everything checks out.${RESET}"
  echo "${DIM}Next: open it (neovide or nvim), press F1, and read docs/TUTORIAL.md${RESET}"
  exit 0
fi

echo "${RED}${BOLD}$problems problem(s) found.${RESET}"
echo "${DIM}Details: nvim --headless -c \"lua dofile('scripts/health.lua')\" -c qa${RESET}"
exit 1
