# Neovim, for people coming from VS Code

A complete, self-contained Neovim configuration: file tree, fuzzy finder,
tabs, status bar, breadcrumbs, language servers, formatters, linters,
debuggers, a command palette, working mouse support (including a right-click
menu), and a deeply integrated AI panel — all installed by one command.

No distro, no "put this in your config and figure out the rest". One folder,
one installer, everything already wired.

```
macOS / Linux        ./install.sh          (or: ./install.sh --yes)
Windows              powershell -ExecutionPolicy Bypass -File install.ps1
```

Both are **idempotent**: run them as often as you like. They check before they
act, they move any existing config to a timestamped backup, and they pick up
where they left off after a failure.

Requires **Neovim 0.11+** (0.12 is what everything here is tested against).

---

## The three things you need to know

1. **`:HelpMe` (or `F1`) lists every key**, generated from the live keymaps.
   [`KEYBINDINGS.md`](KEYBINDINGS.md) is the same list as a file.
2. **`Space`, then wait.** A menu appears explaining every group. That is
   which-key, and it is why you do not have to memorise anything.
3. **The primary modifier is `Cmd` on macOS and `Ctrl` on Linux/Windows.**
   That difference is real, it cannot be patched away, and it is explained in
   the next section.

---

## Does the Cmd key work? (read this once)

Cmd lives in macOS's window server. A program inside a terminal emulator never
sees it — that is not a Neovim limitation, it is how terminals work. So:

| Host | Cmd shortcuts | What to do |
|---|---|---|
| **Neovide** (macOS, recommended) | ✅ work natively | nothing — `Cmd+S`, `Cmd+P` just work |
| Ghostty / iTerm / Terminal.app | ❌ | use the Ctrl fallbacks (`Ctrl+S`, `Ctrl+P`) |
| Linux / Windows GUI (any) | ❌ no Cmd key exists | `Ctrl` is the primary modifier |
| tmux + `ide` | ❌ inside tmux | Ctrl fallbacks, plus tmux's `Ctrl+B` prefix |

Every shortcut is declared once with both bindings, so the Ctrl column below is
always available, on every platform. The config detects the platform and binds
whichever one can actually fire
([`lua/config/platform.lua`](lua/config/platform.lua)).

A few Ctrl chords that Vim already uses (`Ctrl+W`, `Ctrl+B`, `Ctrl+V`,
`Ctrl+P` in insert mode) are **not** stolen on Linux/Windows. Those actions get
`Ctrl+Shift+<letter>` instead, and the file/diagnostic pickers remain on their
leader keys. `KEYBINDINGS.md` shows exactly what each platform binds.

---

## What you get

**Finding things**

| macOS | Linux/Win | |
|---|---|---|
| `Cmd+P` | `Ctrl+P` | find a file by name |
| `Cmd+Shift+P` | `Ctrl+Shift+P` | **command palette**: every command *and* every keymap |
| `Cmd+Shift+F` | `Ctrl+Shift+F` | search the text of the whole project |
| `Cmd+B` | `Ctrl+Shift+B` | toggle the file tree |
| `Cmd+Shift+O` | `Ctrl+Shift+O` | jump to a symbol in this file |
| `Space g g` | same | lazygit (stage, commit, push) |

**Editing**

| macOS | Linux/Win | |
|---|---|---|
| `Cmd+S` / `Cmd+Shift+S` | `Ctrl+S` / `Ctrl+Shift+S` | save / save all |
| `Cmd+W` | `Ctrl+Shift+W` | close the current file |
| `Cmd+Z` / `Cmd+Shift+Z` | `Ctrl+Z` / `Ctrl+Shift+Z` | undo / redo |
| `Cmd+/` | `Ctrl+/` | toggle comment |
| `Option+↑/↓` | `Alt+↑/↓` | move the line |
| `Option+Shift+↑/↓` | `Alt+Shift+↑/↓` | duplicate the line |
| `Cmd+D` | `Ctrl+D` | add a cursor at the next occurrence |
| `Cmd+Shift+L` | `Ctrl+Shift+L` | add a cursor at every occurrence |
| `Cmd+C` / `Cmd+V` / `Cmd+X` | `Ctrl+C` / `Ctrl+V` / `Ctrl+Shift+X` | copy / paste / cut |

**Code intelligence**

| Key | |
|---|---|
| `F12` / `Shift+F12` | go to definition / find references |
| `F2` | rename symbol everywhere |
| `Cmd+.` | code action / quick fix |
| `K` | hover documentation |
| `Cmd+Shift+M` | problems panel |
| `[d` / `]d` | previous / next diagnostic |

**AI (OpenCode)**

| macOS | Linux/Win | |
|---|---|---|
| `Cmd+I` | `Space a g` | open/close the chat panel |
| `Cmd+K` | `Space a a` | ask about the line or selection |
| `Cmd+Shift+K` | `Space a p` | menu of AI actions (explain, review, tests…) |
| `Cmd+Shift+.` | `Space a f` | fix the diagnostics under the cursor |
| `Ctrl+.` | `Ctrl+.` | show/hide the panel from anywhere |

> **Note on Linux/Windows:** the Cmd-based AI keys are not rebound to Ctrl,
> because `Ctrl+K`, `Ctrl+I` and `Ctrl+.` already mean something in Vim or in
> the terminal. The leader alternatives above are always available, and they
> are in the `Space a` menu, so nothing is hidden.

**Debugging**

`F5` start/continue, `F9` breakpoint, `F10` step over, `F11` step into,
`Shift+F5` stop. macOS laptops need `Fn` for these, so every one also exists as
`Space d c` / `d b` / `d n` / `d i` / `d o`.

**And the small things that make it feel like an IDE**

- Mouse everywhere: click to move, drag to select, drag window borders,
  scroll wheel, right-click for a context menu with the ten actions you
  actually use.
- A start screen with clickable shortcuts.
- Breadcrumbs above the code (dropbar).
- Tabs with per-file diagnostics, close buttons and `Cmd+1..9`.
- Format on save, lint as you type, completion as you type.
- Notifications in the corner instead of `:messages` archaeology.
- Sessions: reopen Neovim and your tabs are still there.
- `:Panic` — a centred card with the six escape routes, for when the screen
  ends up somewhere strange.

---

## Languages

Servers, formatters and linters are installed automatically on first launch
(they are Mason packages, not part of the installer). First open of a language
takes a minute while its tooling downloads.

| Language | Server | Format on save | Lint |
|---|---|---|---|
| C# / .NET | **Roslyn** (`roslyn.nvim`, solution-wide, not OmniSharp) | `csharpier` | Roslyn |
| TypeScript / JavaScript / React / React Native | `vtsls` (+ `eslint`) | `prettier` | `eslint` |
| HTML / CSS / Tailwind | `html`, `cssls`, `tailwindcss`, `emmet` | `prettier` | — |
| Python | `basedpyright` + `ruff` | `ruff` | `ruff` |
| Shell | `bashls` | `shfmt` | `shellcheck` |
| Terraform / HCL | `terraformls` | `terraform fmt` | `tflint` |
| JSON / YAML | `jsonls`, `yamlls` (+ SchemaStore) | `prettier` | — |
| Markdown | `marksman` | `prettier` | — |
| Lua | `lua_ls` | `stylua` | — |
| TOML | taplo (via Mason) | — | — |

`.NET` specifics: `:DotnetBuild`, `:DotnetRun`, `:DotnetTest`,
`:DotnetSolution`. Debugging uses `netcoredbg` through `nvim-dap`.
React Native: `:RN start`, `:RN ios`, `:RN android`, plus an attach
configuration for Metro on port 8081.
Terraform: `:Tf init|validate|plan|apply|fmt|output` (`apply` always confirms).

---

## The AI, and why it is not a chat window bolted on

The AI is a real `opencode` process. The plugin builds a bridge in both
directions:

- **You send context**: `@this` (selection or cursor), `@buffer`, `@buffers`,
  `@diagnostics`, `@quickfix`, `@visible`. Those are expanded into the prompt
  on the way out.
- **It sends edits back**: OpenCode writes to disk, Neovim notices
  (`autoread` + `checktime`) and reloads the buffer. Before anything is
  written, you get a diff: `da` accept, `dr` reject, `]c`/`[c` walk hunks,
  `dp`/`do` accept or reject a single hunk, `q` close.

Commands: `:Ask <question>`, `:AIExplain`, `:AIFix`, `:AIReview`, `:AITests`,
`:AIDiff` (review your uncommitted diff), `:AICommit` (write a commit message
from the diff). `:checkhealth opencode` diagnoses the connection.

Two habits that double the quality of the answers: **save first** (the AI reads
from disk, not from your buffer), and **select narrowly** (`@this` on 30 lines
beats `@buffer` on 900).

The commands attach to the OpenCode session for this directory. If none exists
yet, open the panel first (`Cmd+I`, `Ctrl+.`, or `Space a g`) — that starts the
TUI, and the commands reuse it.

If you prefer the tmux layout — editor left, AI right, survives a window close
— install the `ide` script (`install.sh` does this) and run `ide`.

---

## Install, in detail

```sh
git clone <this-repo> ~/.config/nvim     # or copy the folder there
cd ~/.config/nvim
./install.sh
```

The installer is staged and skippable:

| Flag | Effect |
|---|---|
| `--yes` | no questions (re-runs, dotfiles, CI) |
| `--skip-gui` | do not install Neovide or the font |
| `--skip-tmux` | do not touch `~/.tmux.conf` or install `ide` |
| `--dry-run` | print every action, change nothing |

What it installs, by platform:

| | macOS (Homebrew) | Linux (apt/dnf/pacman/zypper) | Windows (winget) |
|---|---|---|---|
| Editor | `neovim` | `neovim` | `Neovim.Neovim` |
| Search | `ripgrep`, `fd` | `ripgrep`, `fd-find` (linked as `fd`) | `BurntSushi.ripgrep.MSVC`, `sharkdp.fd` |
| Git | `git`, `lazygit` | `git` | `Git.Git`, `JesseDuffield.lazygit` |
| Node | `node` + `pnpm` | `nodejs`, `npm`, `pnpm` | `OpenJS.NodeJS.LTS`, `pnpm.pnpm` |
| Python (Python debugging) | `python` (3.10+) | `python3` (3.10+) | via `:Mason` |
| Parsers | `tree-sitter-cli` | via `npm` | via `npm` |
| Lua/shell tooling | `stylua`, `shfmt`, `shellcheck` | `shfmt`, `shellcheck` (+ `cargo` for stylua) | via Mason |
| IaC | `terraform`, `tflint` (taps) | manual link if unpackaged | via Mason |
| GUI | `neovide` cask | AppImage link printed | `Neovide.Neovide` |
| Font | `font-jetbrains-mono-nerd-font` cask | downloaded to `~/.local/share/fonts` | manual link printed |
| tmux | installed on request | installed on request | n/a |

Then it runs `:Lazy sync` and `scripts/install-tools.lua` headlessly, so the first
interactive launch is not a wall of installers.

There is also a `Makefile` for the three things you will actually repeat
(`make` is not installed on Windows by default; use `install.ps1` there):

```sh
make            # list the targets
make verify     # headless self-check: plugins, syntax, keys, LSP, DAP
make docs       # regenerate KEYBINDINGS.md from the live keymaps
make tools      # install or repair language servers, formatters, debuggers
make update     # update plugins and tools
```

**.NET is never installed or upgraded by the scripts.** Projects pin SDK
versions; silently changing them breaks builds.

---

## Layout

```
~/.config/nvim
├── init.lua               the whole entry point (20 lines)
├── lua/
│   ├── config/
│   │   ├── options.lua    editor settings: mouse, clipboard, indents
│   │   ├── registry.lua   THE single source of truth for keys and commands
│   │   ├── platform.lua   macOS/Linux/Windows differences, in one place
│   │   ├── lazy.lua       plugin manager bootstrap (self-healing clone)
│   │   ├── autocmds.lua   reload-on-change, yank highlight, big-file guard
│   │   ├── commands.lua   :Reload :ConfigEdit :ConfigUpdate :ConfigDocs …
│   │   └── util.lua       small shared helpers
│   ├── keys/              one file per area, all declared through the registry
│   ├── plugins/           one lazy.nvim spec per area
│   ├── help/              :HelpMe, :HelpTutorial, :Panic
│   └── local.lua          YOUR overrides — git-ignored, loaded last
├── docs/TUTORIAL.md       the guided tour for a Vim beginner
├── KEYBINDINGS.md         generated from the registry
├── extras/                neovide / ghostty / tmux configs + the `ide` script
├── scripts/               gen-docs.lua, install-tools.lua, health.lua, verify.sh
├── install.sh             macOS + Linux
└── install.ps1            Windows
```

Nothing in `lua/plugins/` calls `vim.keymap.set` for a global key. Keys go
through `require("config.registry")`, which feeds *five* consumers at once:
the real keymap, which-key's group labels, `:HelpMe`, `KEYBINDINGS.md`, and a
duplicate-key audit. Adding a key in one place updates all of them, which is
why the help cannot go stale.

---

## Making it yours

- **Anything at all:** `~/.config/nvim/lua/local.lua`. Git-ignored, loaded
  last, so your settings win.
- **Theme:** `:Theme` (`Space u t`). The choice is remembered.
- **A key:** edit the matching file in `lua/keys/`, then `:Reload`. Run
  `:ConfigDocs` to regenerate the docs.
- **A language:** `:Mason` → install the server → add its name to the `servers`
  list in `lua/plugins/lsp.lua`.
- **Updates:** `:ConfigUpdate` (plugins + Mason tools), then `:Health`.

---

## Verification checklist

Run these once after installing. They are the difference between "it launched"
and "it works".

| # | Check | Expected |
|---|---|---|
| 1 | `nvim --version` | 0.11+ |
| 2 | `:Health` | no red errors under lazy/mason/lsp |
| 3 | `:Lazy` | every plugin installed, none errored |
| 4 | `make tools` (or `:Mason`) | language tools installed (allow a few minutes) |
| 5 | `:checkhealth opencode` | server reachable, or "not running" (start it with `Cmd+I`) |
| 6 | `:HelpMe` | a full cheat sheet, grouped by category |
| 7 | `Cmd+P` / `Ctrl+P` | the file picker opens and finds files |
| 8 | `Cmd+Shift+P` | the command palette lists commands *and* keymaps |
| 9 | right-click in the editor | a context menu appears at the pointer |
| 10 | open a `.ts` file | completion appears; status bar shows `vtsls` |
| 11 | open a `.cs` file | Roslyn attaches; `F12` jumps to a definition |
| 12 | `:Tf validate` in a TF project | output appears in the bottom panel |
| 13 | `Cmd+K` / `Space a a` | the AI prompt opens, pre-filled with `@this:` |
| 14 | `:AIDiff` with uncommitted changes | the AI reviews your diff |
| 15 | `:Panic` | a centred card, `q` closes it |

`bash scripts/verify.sh` runs the headless half of this automatically.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Typing does nothing | you are in Normal mode: press `i` |
| `Cmd` shortcuts do nothing | you are in a terminal, not Neovide — use the Ctrl column |
| A red error appeared | `:messages` |
| A plugin broke after updating | `:Lazy restore`, then restart |
| No completion in a file | `:LspInfo`; check the filetype is in the table above |
| A server never installs | `:Mason`, `:MasonLog` |
| Icons are boxes | the Nerd Font is missing; re-run the installer without `--skip-gui` |
| `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` | run `pnpm setup`, or add `~/Library/pnpm/bin` to PATH (Neovim already does this for itself) |
| A Node tool is installed but Neovim cannot see it | it is probably in pnpm's global bin; `:lua print(vim.fn.exepath("name"))` shows what Neovim resolves |
| `module 'lazy' not found` | interrupted download; delete `~/.local/share/nvim/lazy/lazy.nvim` and restart |
| Everything is on fire | `Cmd+Q` / `:q!`; undo history is on disk |

---

## Platform support

| | Status |
|---|---|
| macOS (arm64, Homebrew) | **primary target**, tested end to end |
| Linux (apt, dnf, pacman, zypper) | supported; Cmd layer becomes a Ctrl layer |
| WSL | supported, same as Linux; use Windows Terminal |
| Windows (winget) | supported via `install.ps1`; no tmux, no `ide` script |
| Neovim &lt; 0.11 | not supported (`vim.lsp.config`, `winborder`, `vim.hl`) |

---

## Credits

Built on the work of, among others: folke (snacks.nvim, lazy.nvim,
which-key.nvim, tokyonight), nvim-lspconfig, mason.nvim, blink.cmp,
conform.nvim, nvim-lint, bufferline.nvim, lualine.nvim, neo-tree.nvim,
trouble.nvim, nvim-dap + dap-ui, dropbar.nvim, persistence.nvim,
grug-far.nvim, mini.nvim, nvim-treesitter, roslyn.nvim, SchemaStore.nvim,
venv-selector.nvim, neotest-dotnet, multicursor.nvim, and
[nickjvandyke/opencode.nvim](https://github.com/nickjvandyke/opencode.nvim).

MIT for this configuration itself; each plugin keeps its own licence.
