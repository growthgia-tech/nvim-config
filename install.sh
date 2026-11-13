#!/usr/bin/env bash
# =============================================================================
#  install.sh — one-shot, idempotent setup for macOS and Linux
# =============================================================================
#
#  Windows users: run install.ps1 instead (PowerShell). Everything else in this
#  repository is cross-platform; only the tool installation differs.
#
#  What it does, in order:
#    1. sanity-checks the machine (OS, package manager, compiler for parsers)
#    2. installs the command-line tools Neovim needs
#    3. installs the GUI (Neovide) and a Nerd Font where the OS allows it
#    4. backs up any existing Neovim config and installs this one
#    5. writes terminal settings (Ghostty) and the tmux layout, if wanted
#    6. boots Neovim once, headless, to install plugins and language tools
#    7. prints a checklist of what to verify
#
#  Safe to run again at any time. Every step checks before it acts, and the
#  only destructive thing it ever does is MOVE an old config to a timestamped
#  backup folder (nothing is deleted).
#
#  Usage:
#    ./install.sh              # full install, asks before the big steps
#    ./install.sh --yes        # no questions (good for re-runs, CI, dotfiles)
#    ./install.sh --skip-gui   # skip Neovide + font
#    ./install.sh --skip-tmux  # skip tmux config
#    ./install.sh --dry-run    # print what would happen, change nothing
#
#  Tested on: macOS 14/15 (arm64, Homebrew), Debian/Ubuntu (apt), Fedora (dnf),
#  Arch (pacman). Other distributions work as long as one of those managers does.
# =============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Bookkeeping
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$SCRIPT_DIR/install.log"

ASSUME_YES=0
SKIP_GUI=0
SKIP_TMUX=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --yes|-y)     ASSUME_YES=1 ;;
    --skip-gui)   SKIP_GUI=1 ;;
    --skip-tmux)  SKIP_TMUX=1 ;;
    --dry-run)    DRY_RUN=1 ;;
    --help|-h)    sed -n '2,34p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 2 ;;
  esac
done

if [[ -t 1 ]]; then
  B=$'\033[1m'; DIM=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'
  Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'
else
  B=""; DIM=""; R=""; G=""; Y=""; C=""; N=""
fi

STEP=0
step()  { STEP=$((STEP + 1)); printf '\n%s[%d/8]%s %s\n' "$B$C" "$STEP" "$N$B" "$*"; printf '[%d/8] %s\n' "$STEP" "$*" >>"$LOG"; }
ok()    { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn()  { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
fail()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }
note()  { printf '  %s%s%s\n' "$DIM" "$*" "$N"; }

run() {
  if ((DRY_RUN)); then
    printf '  %s[dry-run]%s %s\n' "$DIM" "$N" "$*"
    return 0
  fi
  "$@" >>"$LOG" 2>&1
}

ask() {
  local prompt="$1"
  if ((ASSUME_YES)); then return 0; fi
  if ((DRY_RUN)); then printf '  %s[dry-run]%s would ask: %s\n' "$DIM" "$N" "$prompt"; return 0; fi
  local reply=""
  read -r -p "  $prompt [Y/n] " reply || true
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

: >"$LOG"
echo "Log: $LOG"
echo "${B}Neovim config installer${N}  $DIM(Neovim 0.11+)${N}"
((DRY_RUN)) && echo "${Y}DRY RUN — nothing will be installed.${N}"

# ---------------------------------------------------------------------------
# 1. Preflight: which OS, which package manager, which compiler
# ---------------------------------------------------------------------------
step "Checking this machine"

OS="unknown"
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)
    fail "Unsupported OS: $(uname -s)"
    note "On Windows, run:  powershell -ExecutionPolicy Bypass -File install.ps1"
    exit 1
    ;;
esac

if [[ "$OS" == "macos" ]]; then
  ok "macOS $(sw_vers -productVersion) ($(uname -m))"
else
  ok "Linux $(uname -r) ($(uname -m))"
  if grep -qi microsoft /proc/version 2>/dev/null; then
    ok "WSL detected — the config works normally; use Windows Terminal"
    note "Cmd does not exist here either: Ctrl is the primary modifier (see KEYBINDINGS.md)."
  fi
fi

# Package manager. One abstraction, four implementations.
PKG=""
if [[ "$OS" == "macos" ]] && have brew; then
  PKG="brew"
elif have apt-get; then
  PKG="apt"
elif have dnf; then
  PKG="dnf"
elif have pacman; then
  PKG="pacman"
elif have zypper; then
  PKG="zypper"
fi

if [[ -z "$PKG" ]]; then
  fail "No supported package manager found."
  note "Install one of: Homebrew (macOS), apt, dnf, pacman, zypper."
  note "Then re-run this script."
  exit 1
fi
ok "package manager: $PKG"

# A C compiler is required to build Tree-sitter parsers. Without it, syntax
# highlighting silently degrades, which is a confusing first impression.
if have cc || have gcc || have clang; then
  ok "C compiler present (needed for Tree-sitter parsers)"
else
  warn "no C compiler found — Tree-sitter parsers will not build"
  if [[ "$OS" == "macos" ]]; then
    note "Run:  xcode-select --install"
  else
    note "Install build-essential (Debian/Ubuntu) or gcc (Fedora/Arch)."
  fi
fi

# ---------------------------------------------------------------------------
# 2. Command-line tools
# ---------------------------------------------------------------------------

# Logical name -> package name, per manager. Empty means "not packaged here",
# in which case we print a manual instruction instead of guessing.
pkg_name() {
  local tool="$1"
  case "$PKG:$tool" in
    # macOS
    brew:*) echo "$tool" ;;
    # Debian / Ubuntu
    apt:fd)            echo "fd-find" ;;
    apt:node)          echo "nodejs" ;;
    apt:npm)           echo "npm" ;;
    apt:python)        echo "python3" ;;
    apt:neovim)        echo "neovim" ;;
    apt:stylua|apt:terraform|apt:tflint|apt:tree-sitter-cli|apt:lazygit) echo "" ;;
    apt:*)             echo "$tool" ;;
    # Fedora
    dnf:fd)            echo "fd-find" ;;
    dnf:node)          echo "nodejs" ;;
    dnf:python)        echo "python3" ;;
    dnf:stylua|dnf:terraform|dnf:tflint|dnf:tree-sitter-cli|dnf:lazygit) echo "" ;;
    dnf:*)             echo "$tool" ;;
    # Arch
    pacman:*)          echo "$tool" ;;
    # openSUSE
    zypper:fd)         echo "fd" ;;
    zypper:node)       echo "nodejs" ;;
    zypper:*)          echo "$tool" ;;
    *) echo "" ;;
  esac
}

pkg_installed() {
  local name="$1"
  [[ -z "$name" ]] && return 1
  case "$PKG" in
    brew)   brew list --formula "$name" >/dev/null 2>&1 ;;
    apt)    dpkg -s "$name" >/dev/null 2>&1 ;;
    dnf)    rpm -q "$name" >/dev/null 2>&1 ;;
    pacman) pacman -Q "$name" >/dev/null 2>&1 ;;
    zypper) rpm -q "$name" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

pkg_install() {
  case "$PKG" in
    brew)   run brew install "$@" ;;
    apt)    run sudo apt-get install -y "$@" ;;
    dnf)    run sudo dnf install -y "$@" ;;
    pacman) run sudo pacman -S --noconfirm --needed "$@" ;;
    zypper) run sudo zypper install -y "$@" ;;
  esac
}

step "Installing command-line tools"

# Homebrew needs explicit taps for two of these; they are not in homebrew-core.
if [[ "$PKG" == "brew" ]]; then
  for tap in hashicorp/tap terraform-linters/tap; do
    if brew tap | grep -qx "$tap"; then
      ok "tap $tap"
    else
      note "tapping $tap"
      run brew tap "$tap" || warn "could not tap $tap"
      # Homebrew 7 refuses to load formulae from taps it does not trust.
      run brew trust "$tap" || true
    fi
  done
  # A stale lock from an interrupted run would block every later run.
  rm -f "$(brew --prefix)/var/homebrew/locks/"* 2>/dev/null || true
fi

# Logical tools, in the order that matters if one fails.
TOOLS=(
  neovim        # the editor
  ripgrep       # live grep
  fd            # fast file listing
  git
  node          # LSP servers and formatters are npm packages
  npm
  python        # >= 3.10: debugpy (the Python debugger) is a pip package
  tmux          # optional: the `ide` layout
  jq
  shellcheck    # shell linter
  shfmt         # shell formatter
  stylua        # Lua formatter (also formats this config)
  tree-sitter-cli # compiles parsers; must be >= 0.26
  terraform     # optional: IaC
  tflint        # optional: Terraform linter
  lazygit       # optional: git UI
)

MISSING=()
MANUAL=()

for tool in "${TOOLS[@]}"; do
  if have "$tool"; then
    ok "$tool"
    continue
  fi

  name="$(pkg_name "$tool")"
  if [[ -z "$name" ]]; then
    MANUAL+=("$tool")
    continue
  fi

  if pkg_installed "$name"; then
    ok "$name (installed; check your PATH)"
    continue
  fi

  MISSING+=("$name")
done

if ((${#MISSING[@]})); then
  note "will install: ${MISSING[*]}"
  if ask "Install these ${#MISSING[@]} packages?"; then
    if [[ "$PKG" == "apt" ]]; then
      run sudo apt-get update || warn "apt-get update failed (continuing)"
    fi
    # One at a time so a single unavailable package does not abort the rest.
    for name in "${MISSING[@]}"; do
      if pkg_install "$name"; then
        ok "$name"
      else
        warn "$name failed to install (see $LOG)"
      fi
    done
  else
    warn "Skipped. Neovim starts, but search and formatting will be reduced."
  fi
fi

# Debian ships fd as `fdfind`. The picker looks for `fd`, so bridge the name.
if ! have fd && have fdfind; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd" 2>/dev/null || true
  ok "linked fdfind -> fd"
fi

# Python debugging needs 3.10+: debugpy is a pip package, not a binary.
if have python3; then
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
    ok "python3 $(python3 -c 'import platform; print(platform.python_version())')"
  else
    warn "python3 $(python3 -c 'import platform; print(platform.python_version())') is too old for debugpy (needs 3.10+)"
    note "macOS keeps an old python3 in /usr/bin for the system; install a real one:"
    note "  brew install python    # then open a new terminal"
    note "Python editing, linting and formatting still work; only the debugger needs this."
  fi
fi

# Tools that no distribution packages well. Install them the sane way, or say
# exactly what to run.
manual_hint() {
  case "$1" in
    tree-sitter-cli) echo "npm install -g tree-sitter-cli" ;;
    stylua)          echo "cargo install stylua   # or: brew install stylua (macOS)" ;;
    terraform)       echo "https://developer.hashicorp.com/terraform/install" ;;
    tflint)          echo "https://github.com/terraform-linters/tflint#installation" ;;
    lazygit)         echo "https://github.com/jesseduffield/lazygit#installation" ;;
    *)               echo "install '$1' with your package manager" ;;
  esac
}

for tool in "${MANUAL[@]:-}"; do
  [[ -z "$tool" ]] && continue
  warn "$tool is not packaged for $PKG"
  note "  $(manual_hint "$tool")"
done

# npm-based tools, when npm is now available.
if have npm; then
  if ! have tree-sitter; then
    if ask "Install tree-sitter-cli with npm (needed for syntax highlighting)?"; then
      run npm install -g tree-sitter-cli || warn "npm install failed; you can retry later"
      have tree-sitter && ok "tree-sitter-cli"
    fi
  fi
  if ! have stylua && have cargo; then
    if ask "Install stylua with cargo (Lua formatter)?"; then
      run cargo install stylua || warn "cargo install failed"
    fi
  fi
fi

# opencode CLI: the AI integration needs this binary on PATH.
if have opencode; then
  ok "opencode $(opencode --version 2>/dev/null | head -1)"
else
  warn "the 'opencode' CLI is not on PATH"
  if ask "Install the opencode CLI?"; then
    if [[ "$PKG" == "brew" ]]; then
      run brew install opencode || warn "opencode install failed"
    elif have npm; then
      run npm install -g opencode-ai || warn "opencode install failed"
    else
      note "See https://opencode.ai/docs for the install command on your platform."
    fi
    have opencode && ok "opencode" || note "Install it manually, then re-run this script."
  else
    note "Without it, :Ask and the AI keymaps show a clear error instead of working."
  fi
fi

# .NET is deliberately NOT installed or upgraded: projects pin SDK versions and
# silently changing the SDK breaks builds. We only report what is there.
if have dotnet; then
  ok "dotnet $(dotnet --version 2>/dev/null | head -1) (left untouched)"
else
  note "no .NET SDK: C# support and :DotnetBuild stay inactive until you install one"
fi

# ---------------------------------------------------------------------------
# 3. GUI and font
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Neovim version. Distributions ship old versions (Ubuntu 24.04 has 0.9.5,
# Fedora 41 has 0.10), and this config needs 0.11+ for vim.lsp.config(),
# 'winborder' and vim.hl. If the packaged one is too old we fetch the official
# build into ~/.local/opt instead of leaving a half-broken editor behind.
# ---------------------------------------------------------------------------
nvim_minor() {
  nvim --version 2>/dev/null | head -1 | sed -E 's/^NVIM v([0-9]+)\.([0-9]+).*/\2/'
}
nvim_major() {
  nvim --version 2>/dev/null | head -1 | sed -E 's/^NVIM v([0-9]+)\.([0-9]+).*/\1/'
}

neovim_ok() {
  have nvim || return 1
  local major minor
  major="$(nvim_major)"
  minor="$(nvim_minor)"
  [[ -n "$major" && -n "$minor" ]] || return 1
  (( major > 0 || (major == 0 && minor >= 11) ))
}

if neovim_ok; then
  ok "Neovim $(nvim --version | head -1 | awk '{print $2}')"
elif have nvim; then
  warn "Neovim $(nvim --version | head -1 | awk '{print $2}') is too old (need 0.11+)"
  if ask "Download the official Neovim build into ~/.local/opt?"; then
    case "$(uname -m)" in
      x86_64|amd64) NVIM_ARCH="x86_64" ;;
      aarch64|arm64) NVIM_ARCH="arm64" ;;
      *) NVIM_ARCH="" ;;
    esac

    if [[ -z "$NVIM_ARCH" ]]; then
      fail "unknown architecture $(uname -m); install Neovim 0.11+ by hand"
    elif ((DRY_RUN)); then
      note "[dry-run] would download nvim-linux-$NVIM_ARCH.tar.gz to ~/.local/opt/nvim"
    else
      mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
      TARBALL="/tmp/nvim-linux-$NVIM_ARCH.tar.gz"
      if curl -fsSL -o "$TARBALL" \
        "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$NVIM_ARCH.tar.gz"; then
        rm -rf "$HOME/.local/opt/nvim"
        mkdir -p "$HOME/.local/opt/nvim"
        tar -xzf "$TARBALL" -C "$HOME/.local/opt/nvim" --strip-components=1
        ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
        ok "Neovim $("$HOME/.local/opt/nvim/bin/nvim" --version | head -1 | awk '{print $2}')"
        case ":$PATH:" in
          *":$HOME/.local/bin:"*) ;;
          *) warn "add ~/.local/bin to PATH before your packaged nvim:"
             note '  echo '"'"'export PATH="$HOME/.local/bin:$PATH"'"'"' >> ~/.zshrc   # or ~/.bashrc' ;;
        esac
        hash -r
      else
        fail "download failed. Get Neovim 0.11+ from https://github.com/neovim/neovim/releases"
        rm -f "$TARBALL"
      fi
    fi
  fi
else
  fail "Neovim is not installed and could not be installed automatically."
  note "Get a 0.11+ build from https://github.com/neovim/neovim/releases"
fi

step "Installing the GUI and font"


if ((SKIP_GUI)); then
  warn "skipped (--skip-gui)"
elif [[ "$OS" == "macos" ]]; then
  CASKS=()
  brew list --cask neovide >/dev/null 2>&1 || CASKS+=(neovide)
  brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1 || CASKS+=(font-jetbrains-mono-nerd-font)

  if ((${#CASKS[@]})); then
    note "will install: ${CASKS[*]}"
    if ask "Install Neovide (GUI) and the JetBrains Mono Nerd Font?"; then
      run brew install --cask "${CASKS[@]}" || {
        warn "cask install failed — 'nvim' in a terminal still works"
        note "Try manually:  brew install --cask neovide font-jetbrains-mono-nerd-font"
      }
      brew list --cask neovide >/dev/null 2>&1 && ok "Neovide" || warn "Neovide missing"
    fi
  else
    ok "Neovide"
    ok "JetBrainsMono Nerd Font"
  fi
else
  # Linux: Neovide ships an AppImage rather than a package we can trust
  # silently. Point at it, install the font ourselves, and move on.
  note "Neovide on Linux is an AppImage: https://github.com/neovide/neovide/releases"
  note "Any GUI terminal works too (Ghostty, WezTerm, kitty). Ctrl replaces Cmd there."

  if ask "Download the JetBrains Mono Nerd Font into ~/.local/share/fonts?"; then
    FONT_DIR="$HOME/.local/share/fonts"
    run mkdir -p "$FONT_DIR"
    ZIP="/tmp/jbmono-nerd.zip"
    if ((DRY_RUN)); then
      note "[dry-run] would download the Nerd Font archive"
    else
      if curl -fsSL -o "$ZIP" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
        && unzip -oq "$ZIP" -d "$FONT_DIR"; then
        fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        ok "JetBrainsMono Nerd Font installed"
      else
        warn "font download failed (offline?). Icons will show as boxes until you install one."
      fi
      rm -f "$ZIP"
    fi
  fi
fi

# Neovide's own config file (window size, Option key behaviour, hotkeys).
NEOVIDE_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/neovide"
if ((SKIP_GUI == 0)) && { have neovide || [[ -d /Applications/Neovide.app ]]; }; then
  if [[ -f "$NEOVIDE_CFG/config.toml" ]] && ! cmp -s "$SCRIPT_DIR/extras/neovide/config.toml" "$NEOVIDE_CFG/config.toml"; then
    run mkdir -p "$NEOVIDE_CFG"
    cp "$NEOVIDE_CFG/config.toml" "$NEOVIDE_CFG/config.toml.bak"
    warn "existing Neovide config backed up to config.toml.bak"
  fi
  run mkdir -p "$NEOVIDE_CFG"
  run cp "$SCRIPT_DIR/extras/neovide/config.toml" "$NEOVIDE_CFG/config.toml"
  ok "Neovide settings written to $NEOVIDE_CFG/config.toml"
fi

# ---------------------------------------------------------------------------
# 4. This Neovim config
# ---------------------------------------------------------------------------
step "Installing the Neovim config"

if [[ ! -f "$SCRIPT_DIR/init.lua" ]]; then
  fail "$SCRIPT_DIR does not look like the config (no init.lua)."
  exit 1
fi

if [[ "$SCRIPT_DIR" == "$NVIM_DEST" ]]; then
  ok "already running from $NVIM_DEST — nothing to copy"
else
  run mkdir -p "$(dirname "$NVIM_DEST")"
  if [[ -e "$NVIM_DEST" ]] && [[ -n "$(ls -A "$NVIM_DEST" 2>/dev/null || true)" ]]; then
    BACKUP="$NVIM_DEST.backup.$STAMP"
    if ask "There is already a config at $NVIM_DEST. Move it to $BACKUP?"; then
      run mv "$NVIM_DEST" "$BACKUP"
      ok "old config moved to $BACKUP"
    else
      fail "Not overwriting your config. Nothing else was changed."
      exit 1
    fi
  fi

  if ((DRY_RUN)); then
    printf '  %s[dry-run]%s rsync %s -> %s\n' "$DIM" "$N" "$SCRIPT_DIR" "$NVIM_DEST"
  else
    mkdir -p "$NVIM_DEST"
    rsync -a --exclude '.git/' --exclude 'install.log' --exclude '.DS_Store' \
      "$SCRIPT_DIR/" "$NVIM_DEST/"
  fi
  ok "config installed at $NVIM_DEST"
fi

# Optional: local machine overrides that are never committed.
if [[ ! -f "$NVIM_DEST/lua/local.lua" ]] && ((!DRY_RUN)); then
  cat >"$NVIM_DEST/lua/local.lua" <<'LUA'
-- lua/local.lua
--
-- Your personal overrides. This file is git-ignored, so you can experiment
-- here without touching the maintained config. It is loaded last (see
-- init.lua). Delete the contents to get back to the defaults.
--
-- Examples:
--   vim.opt.relativenumber = true          -- your preference wins
--   vim.opt.mouse = "a"                    -- if a plugin ever changes it
LUA
  ok "created lua/local.lua for your own tweaks"
fi

# ---------------------------------------------------------------------------
# 5. Terminal + tmux settings (both optional, both backed up)
# ---------------------------------------------------------------------------
step "Configuring terminals"

if [[ -d "/Applications/Ghostty.app" ]] || brew list --cask ghostty >/dev/null 2>&1; then
  GHOSTTY_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  run mkdir -p "$GHOSTTY_CFG"
  if [[ -f "$GHOSTTY_CFG/config" ]] && ! cmp -s "$SCRIPT_DIR/extras/ghostty/config.ghostty" "$GHOSTTY_CFG/config"; then
    cp "$GHOSTTY_CFG/config" "$GHOSTTY_CFG/config.bak"
    warn "existing Ghostty config backed up to config.bak"
  fi
  if [[ ! -f "$GHOSTTY_CFG/config" ]] || ((ASSUME_YES)); then
    run cp "$SCRIPT_DIR/extras/ghostty/config.ghostty" "$GHOSTTY_CFG/config"
    ok "Ghostty settings written to $GHOSTTY_CFG/config"
  else
    note "Ghostty config exists and differs — left alone"
  fi
else
  note "Ghostty not installed — skipping"
fi

if ((SKIP_TMUX == 0)) && have tmux; then
  if [[ -f "$HOME/.tmux.conf" ]] && ! cmp -s "$SCRIPT_DIR/extras/tmux/tmux.conf" "$HOME/.tmux.conf"; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
    warn "existing ~/.tmux.conf backed up to ~/.tmux.conf.bak"
  fi
  if [[ ! -f "$HOME/.tmux.conf" ]] || ((ASSUME_YES)); then
    run cp "$SCRIPT_DIR/extras/tmux/tmux.conf" "$HOME/.tmux.conf"
    ok "tmux settings written to ~/.tmux.conf"
  else
    note "~/.tmux.conf left alone (re-run with --yes to replace it)"
  fi

  run mkdir -p "$HOME/.local/bin"
  run cp "$SCRIPT_DIR/extras/tmux/ide" "$HOME/.local/bin/ide"
  run chmod +x "$HOME/.local/bin/ide"
  ok "'ide' layout script installed at ~/.local/bin/ide"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "add ~/.local/bin to PATH:  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
  esac
else
  note "tmux not installed — skipping the optional IDE layout"
fi

# ---------------------------------------------------------------------------
# 6. First boot: plugins + tools
# ---------------------------------------------------------------------------
step "Installing plugins and language tools (this takes a few minutes)"

if ((DRY_RUN)); then
  printf '  %s[dry-run]%s nvim --headless "+Lazy! sync" +qa\n' "$DIM" "$N"
  printf '  %s[dry-run]%s nvim --headless "+MasonToolsInstallSync" +qa\n' "$DIM" "$N"
elif ! have nvim; then
  fail "nvim is not on PATH yet. Open a new terminal, then run:"
  note '  nvim --headless "+Lazy! sync" +qa'
  note '  nvim --headless "+MasonToolsInstallSync" +qa'
else
  # The network problems that interrupt a plugin download are almost always
  # HTTP/2 multiplexing, and git's HTTP/1.1 mode does not have them. These two
  # variables apply to every git process this script starts (and to the ones
  # Neovim starts), without touching your global git config.
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="http.version"
  export GIT_CONFIG_VALUE_0="HTTP/1.1"

  note "plugins…"
  # A failed plugin install must not abort the installer: the editor still
  # opens and :Lazy can retry later.
  if nvim --headless "+Lazy! sync" +qa >>"$LOG" 2>&1; then
    ok "plugins installed"
  else
    warn "plugin sync had errors (see $LOG) — open Neovim and run :Lazy sync"
  fi

  note "LSP servers, formatters, linters, debug adapters…"
  # install-tools.lua reads the package lists straight out of the plugin specs
  # and waits for every install to finish, which :MasonToolsInstallSync does
  # not do reliably on a slow connection.
  if nvim --headless -c "lua dofile('$NVIM_DEST/scripts/install-tools.lua')" -c qa >>"$LOG" 2>&1; then
    ok "language tools installed"
  else
    warn "some Mason tools failed (see $LOG) — open Neovim and run :Mason"
  fi

  note "Tree-sitter parsers compile in the background on your first launch (~1 min)."
fi

# ---------------------------------------------------------------------------
# 7. Git, so your changes are recoverable
# ---------------------------------------------------------------------------
step "Version control"

if [[ -d "$NVIM_DEST/.git" ]] || ((DRY_RUN)); then
  ok "config is already a git repository"
elif have git; then
  run git -C "$NVIM_DEST" init -q
  run git -C "$NVIM_DEST" add -A
  if git -C "$NVIM_DEST" config user.email >/dev/null 2>&1; then
    run git -C "$NVIM_DEST" commit -q -m "Initial Neovim config" || warn "commit skipped"
  else
    warn "git user.email is not set, so no commit was made"
    note "Set it with: git config --global user.email you@example.com"
  fi
  ok "git repository initialised at $NVIM_DEST"
else
  warn "git not found, skipping"
fi

# ---------------------------------------------------------------------------
# 8. What to do now
# ---------------------------------------------------------------------------
MODIFIER="Cmd"
[[ "$OS" == "linux" ]] && MODIFIER="Ctrl"

printf '\n%s[8/8]%s %sDone.%s\n' "$B$C" "$N" "$B$G" "$N"
cat <<EOF

  ${B}Start here${N}
    ${C}neovide${N}                 open the GUI (Cmd shortcuts work here — macOS)
    ${C}nvim${N}                    open in a terminal

  ${B}On this platform the primary modifier is ${MODIFIER}${N}
    macOS:    Cmd+S, Cmd+P, Cmd+Shift+P     (Neovide)
    Linux/WSL: Ctrl+S, Ctrl+P, Ctrl+Shift+P
    Every shortcut is listed in KEYBINDINGS.md with both columns.

  ${B}First five things to try${N}
    1. ${C}Space${N} then wait            — a menu of everything, grouped
    2. ${C}${MODIFIER}+Shift+P${N}        — the command palette
    3. ${C}${MODIFIER}+P${N}              — open a file by name
    4. ${C}F1${N}                         — interactive help + tutorial
    5. ${C}${MODIFIER}+K${N}              — ask the AI about this file

  ${B}If anything looks broken${N}
    ${C}:Health${N}        full diagnostic report
    ${C}:Panic${N}         "how do I get out of here"
    ${C}:HelpMe${N}        searchable list of every key and command
    log:          ${DIM}$LOG${N}

  ${B}Docs${N}
    ${DIM}$NVIM_DEST/README.md${N}
    ${DIM}$NVIM_DEST/KEYBINDINGS.md${N}
    ${DIM}$NVIM_DEST/docs/TUTORIAL.md${N}

EOF

if ((DRY_RUN)); then
  echo "  ${Y}Dry run finished — nothing was changed.${N}"
fi
