# Installation

One command per platform. Both installers are idempotent: run them again after a
failure, after an update, or after you break something.

| OS | Command |
|---|---|
| **macOS** | `./install.sh` |
| **Linux** (Debian/Ubuntu, Fedora, Arch, openSUSE) | `./install.sh` |
| **Windows** 10/11 | `powershell -ExecutionPolicy Bypass -File install.ps1` |
| **WSL** | `./install.sh` (inside the WSL shell) |

All of them need **Neovim 0.11+**. macOS and Windows get that version from
Homebrew/winget automatically; on Linux many distributions still ship 0.9 or
0.10, so `install.sh` checks and, if needed, downloads the official build into
`~/.local/opt/nvim` and links it into `~/.local/bin`.

> **What has actually been run:** macOS end to end, including plugin install,
> language servers and the test suite. The Linux and Windows branches are
> implemented and syntax-checked, but were not executed on this machine — treat
> their package lists as the part most likely to need a tweak.

---

## Before you start

| Need | Why | Check |
|---|---|---|
| A C compiler | Tree-sitter compiles parsers | `cc --version` (macOS: `xcode-select --install`) |
| ~2 GB free | plugins, parsers, language servers | `df -h ~` |
| Network | everything is downloaded on first run | — |

You do **not** need to install Neovim, ripgrep, fd, a font, or any language
server by hand.

---

## macOS

### 1. Prerequisites

```sh
xcode-select --install                      # compiler for Tree-sitter
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install

```sh
git clone <this-repo> ~/.config/nvim
cd ~/.config/nvim
./install.sh
```

If the config already lives at `~/.config/nvim` (the usual case), just run
`./install.sh` from there.

### 3. What it installs

| Kind | Packages |
|---|---|
| Formulae | `neovim`, `ripgrep`, `fd`, `git`, `node`, `npm`, `pnpm`, `python`, `tmux`, `jq`, `shellcheck`, `shfmt`, `stylua`, `tree-sitter-cli`, `terraform`, `tflint`, `lazygit`, `chafa`, `imagemagick` |
| Taps | `hashicorp/tap`, `terraform-linters/tap` (both trusted during install) |
| Casks | `neovide`, `font-jetbrains-mono-nerd-font` |
| Node servers (via pnpm) | `@vtsls/language-server`, `yaml-language-server`, `bash-language-server`, `vscode-langservers-extracted`, `@olrtg/emmet-language-server`, `@tailwindcss/language-server`, `basedpyright`, `prettier` |
| After first launch (Mason) | `roslyn`, `csharpier`, `netcoredbg`, `debugpy`, `js-debug-adapter`, `ruff`, `marksman`, `lua-language-server`, `terraform-ls`, `vtsls`, … |

`install.sh` never upgrades your .NET SDK: projects pin versions, so it only
reports what is installed.

### 4. Open it

```sh
neovide                  # GUI: Cmd shortcuts work here
nvim                     # terminal: use the Ctrl column in KEYBINDINGS.md
```

---

## Linux

### 1. Install

```sh
git clone <this-repo> ~/.config/nvim
cd ~/.config/nvim
./install.sh
```

`install.sh` detects `apt-get`, `dnf`, `pacman` or `zypper` and asks before
installing anything with `sudo`. It maps package names per manager:

| Tool | Debian/Ubuntu | Fedora | Arch | openSUSE |
|---|---|---|---|---|
| `fd` | `fd-find` (linked to `fd`) | `fd-find` | `fd` | `fd` |
| Node | `nodejs` + `npm` | `nodejs` | `node` | `nodejs` |
| Python | `python3` (needs ≥ 3.10 for `debugpy`) | `python3` | `python` | `python3` |
| `stylua`, `terraform`, `tflint`, `lazygit`, `tree-sitter-cli` | not packaged → installed via `cargo`/`npm`/manual hint | same | usually packaged | same |
| Image previews | `chafa` + `imagemagick` | `chafa` + `ImageMagick` | `chafa` + `imagemagick` | `chafa` + `ImageMagick` |

Anything a distribution does not package is reported with the exact manual
command rather than silently skipped.

### 2. Neovim version

If `nvim --version` is below 0.11 (common: Ubuntu 24.04 ships 0.9.5, Fedora 41
ships 0.10), the installer offers to download the official tarball:

```
~/.local/opt/nvim/bin/nvim   →   ~/.local/bin/nvim
```

Make sure `~/.local/bin` comes before the distribution's `nvim` in your `PATH`;
the installer prints the line to add if it does not.

### 3. GUI and font

There is no distro package for Neovide we can trust, so the installer prints the
AppImage link instead:

```
https://github.com/neovide/neovide/releases
```

Any GUI terminal works too — Ghostty, WezTerm, kitty, GNOME Terminal. On Linux
the primary modifier is **Ctrl**, not Cmd (there is no Cmd key), so use the Ctrl
column of `KEYBINDINGS.md`.

The Nerd Font is downloaded into `~/.local/share/fonts` and picked up with
`fc-cache` (accept the prompt; skip it if you already have a Nerd Font).

### 4. tmux layout (optional)

```sh
brew/apt install tmux        # the installer offers this
ide                          # editor left, opencode right, survives a window close
```

### 5. WSL

Works exactly like Linux. Two notes:

- Run the installer **inside WSL**, not in PowerShell — the config must live in
  the Linux home directory.
- Use Windows Terminal. `Ctrl` is the primary modifier, and the Windows font has
  to be installed on the Windows side (see below).

---

## Windows

### 1. Prerequisites

Windows 10 1809+ with **winget** (the "App Installer" from the Microsoft Store).
Check with `winget --version`.

### 2. Install

```powershell
git clone <this-repo> $env:LOCALAPPDATA\nvim-src
cd $env:LOCALAPPDATA\nvim-src
powershell -ExecutionPolicy Bypass -File install.ps1
```

Or, if you already downloaded the folder elsewhere:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The config is installed to `%LOCALAPPDATA%\nvim` (Neovim's native location),
never to `~/.config`.

### 3. What it installs

| Tool | winget package |
|---|---|
| Neovim | `Neovim.Neovim` |
| ripgrep | `BurntSushi.ripgrep.MSVC` |
| fd | `sharkdp.fd` |
| Git | `Git.Git` |
| Node LTS | `OpenJS.NodeJS.LTS` |
| pnpm | `pnpm.pnpm` |
| lazygit | `JesseDuffield.lazygit` |
| Neovide | `Neovide.Neovide` |
| ImageMagick (image info) | `ImageMagick.ImageMagick` |

Node tools use pnpm when present (shared store), npm otherwise. Language
servers/adapters that winget does not carry are installed by Mason on first
launch.

### 4. Font (manual, one time)

Download **JetBrainsMono Nerd Font** from <https://www.nerdfonts.com/font-downloads>,
unzip, select the `.ttf` files → right-click → *Install for all users*. Without
it, icons render as empty boxes; nothing else breaks.

In Windows Terminal: *Settings → Startup* → set Windows Terminal as the default
terminal, then pick `JetBrainsMono Nerd Font Mono` as the font face.

### 5. Things that are Unix-only

- `tmux` and the `ide` script. Use Windows Terminal split panes instead
  (`Alt+Shift+D`), Neovim in one, `opencode` in the other.
- The `./install.sh` script itself — use `install.ps1`.

### 6. Open it

```powershell
neovide        # GUI
nvim           # Windows Terminal
```

`Ctrl` is the primary modifier on Windows.

---

## Flags

Both installers accept the same ideas; `install.sh` uses dashes, `install.ps1`
uses PowerShell switches.

| `install.sh` | `install.ps1` | Effect |
|---|---|---|
| `--yes` / `-y` | `-Yes` | no questions (re-runs, dotfiles, CI) |
| `--skip-gui` | `-SkipGui` | skip Neovide and the font |
| `--skip-tmux` | — | leave `~/.tmux.conf` and `ide` alone |
| `--dry-run` | `-DryRun` | print every action, change nothing |
| `--help` / `-h` | `Get-Help .\install.ps1` | usage |

`--dry-run` is the safe way to see what it would touch on your machine:

```sh
./install.sh --dry-run --yes
```

---

## What gets backed up (nothing is deleted)

| Existing file | Becomes |
|---|---|
| `~/.config/nvim/` (non-empty) | `~/.config/nvim.backup.YYYYMMDD-HHMMSS/` |
| `%LOCALAPPDATA%\nvim\` | `%LOCALAPPDATA%\nvim.backup.YYYYMMDD-HHMMSS\` |
| `~/.config/neovide/config.toml` | `config.toml.bak` |
| `~/.config/ghostty/config` | `config.bak` |
| `~/.tmux.conf` | `~/.tmux.conf.bak` |

Every run appends to `install.log` next to the script. If a step fails, that log
is the first thing to read.

---

## Re-running, updating, uninstalling

```sh
cd ~/.config/nvim

make verify        # is the installation healthy? (16 headless checks)
make tools         # finish/repair language servers after a bad network day
make docs          # regenerate KEYBINDINGS.md after changing keys
make update        # update plugins and language tools
./install.sh       # re-run the installer (safe; picks up where it stopped)
```

Rollback:

```sh
# your previous config is still there, untouched:
ls -d ~/.config/nvim.backup.*
mv ~/.config/nvim ~/.config/nvim.broken
mv ~/.config/nvim.backup.20260101-120000 ~/.config/nvim

# or, if you only regret an edit to this config:
git -C ~/.config/nvim checkout .
```

To remove installed plugins/tools but keep the config: `make clean`.

---

## Manual install (no installer)

If you are on an unsupported platform, or want to control every step:

```sh
# 1. the config
git clone <this-repo> ~/.config/nvim

# 2. a toolchain (macOS example; use your package manager elsewhere)
brew install neovim ripgrep fd git node pnpm python

# 3. plugins + language tools, headless
nvim --headless "+Lazy! sync" +qa
nvim --headless -c "lua dofile('scripts/install-tools.lua')" -c qa

# 4. verify
bash scripts/verify.sh
```

Minimum viable setup: Neovim 0.11+, `git`, `ripgrep`, `fd`. Everything else
degrades gracefully — the editor opens and tells you what is missing.

---

## Post-install checklist

| # | Check | Expected |
|---|---|---|
| 1 | `nvim --version` | 0.11 or newer |
| 2 | `bash scripts/verify.sh` | 16 passes, exit code 0 |
| 3 | `:Health` in Neovim | no red errors under lazy/mason/lsp |
| 4 | `make tools` | every tool installed (network permitting) |
| 5 | `F1` | the cheat sheet opens, grouped by category |
| 6 | `Cmd+Shift+P` / `Ctrl+Shift+P` | the command palette lists commands and keys |
| 7 | right-click in the editor | a context menu appears |
| 8 | open a `.ts`, `.cs`, `.py`, `.tf` file | the status bar names a language server |

---

## Troubleshooting

| Symptom | OS | Fix |
|---|---|---|
| `module 'lazy' not found` | all | interrupted download: `rm -rf ~/.local/share/nvim/lazy/lazy.nvim`, restart |
| `unexpected disconnect while reading sideband packet` | all | flaky HTTP/2: the installers force `http.version=HTTP/1.1`; if you clone by hand add `-c http.version=HTTP/1.1` |
| `E919`/`packadd` errors | all | a plugin is half-installed: `:Lazy sync` |
| `vtsls is not executable` | all | `make tools`, and check `:lua print(vim.fn.exepath("vtsls"))` |
| `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` | all | `pnpm setup`, or add `~/Library/pnpm/bin` (macOS) / `~/.local/share/pnpm` (Linux) to `PATH` |
| debugpy will not install | macOS | system `python3` is 3.9: `brew install python` (Neovim already prefers Homebrew's) |
| Neovim is 0.9/0.10 after install | Linux | the distribution package won; put `~/.local/bin` before `/usr/bin`, or use the downloaded `~/.local/opt/nvim/bin/nvim` |
| Icons are boxes | all | Nerd Font missing; re-run without `--skip-gui`, or install it manually |
| Cmd shortcuts do nothing | all | you are in a terminal, not Neovide — use the Ctrl column |
| Plugins load but nothing completes | all | the language may not be supported yet: `:LspInfo`, then `:Mason` |
| `winget` not found | Windows | install "App Installer" from the Microsoft Store |

More: `README.md` (what every key does), `docs/TUTORIAL.md` (guided tour),
`ARCHITECTURE.md` (how the config is put together).
