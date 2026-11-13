# Architecture

This configuration is small on purpose. Understanding four ideas is enough to
change anything in it without breaking the rest.

## The load order

`init.lua` is the whole entry point, and it runs these five lines in order:

```
vim.g.mapleader = " "        leader must exist before plugins read it
require("config.options")    editor settings (mouse, clipboard, indents)
require("keys").setup()      declare + apply every keymap and command
require("config.autocmds")   background behaviours
require("config.lazy")       lazy.nvim: bootstrap, then import lua/plugins/
require("config.commands")   core commands (:Reload, :ConfigEdit, …)
pcall(require, "local")      your overrides, if the file exists
```

Two consequences worth knowing:

- **Options and keymaps do not need plugins.** They are set before lazy.nvim
  runs, so the editor is usable on first launch even while plugins download.
- **`local.lua` wins.** It loads last, so a one-line override there beats
  anything in the maintained config.

## The registry (the core idea)

```
lua/keys/*.lua  ──R.map()/R.cmd()──▶  lua/config/registry.lua
                                            │
              ┌──────────────┬──────────────┼───────────────┬──────────────┐
              ▼              ▼              ▼               ▼              ▼
          keymaps        which-key      :HelpMe       KEYBINDINGS.md   dupe audit
        (R.apply)      (group labels)  (help_rows)    (gen-docs.lua)   (R.dupes)
```

A key is declared once, with `lhs`, `rhs`, `desc`, `cat`, and optionally a
portable `term` fallback and `term_modes`. Everything that mentions the key is
derived from that declaration. There is no second list to keep in sync, which
is why the help window cannot go stale — the usual failure mode of hand-written
Vim help.

`R.map` entries are *declared* by `keys/*.lua`, and *applied* exactly once by
`R.apply()`, at the end of `keys.setup()`. The registry records duplicates
instead of silently letting the last one win.

## Platforms

`lua/config/platform.lua` also repairs `PATH` at startup. A GUI app launched
from Finder gets a minimal `PATH`, and Homebrew is often *last* in a shell's
`PATH`, so `/usr/bin/python3` shadows the current one. The module therefore
puts Homebrew, pnpm's global bin, `~/.local/bin`, `~/.dotnet/tools` and Mason's
`bin` at the front, in that order. Without it, ripgrep, fd, opencode and every
language server would silently "not exist" inside Neovide.

It also answers one question: does this machine have a Cmd key? On macOS it does, so `<D-s>` is bound. On Linux and Windows it does not, so
the registry binds only the `term` fallback (`<C-s>`) and skips `<D-…>`
entirely. A few Vim-essential chords (`Ctrl+W`, `Ctrl+B`, `Ctrl+V`, insert-mode
`Ctrl+P`) are never stolen; those actions use `Ctrl+Shift+` instead.

Nothing else in the config asks which OS it is on.

## Plugins

`lua/plugins/` is one file per concern, imported automatically by lazy.nvim:

| File | Owns |
|---|---|
| `ui.lua` | snacks (picker, explorer, dashboard, terminal, notifier), bufferline, lualine, which-key, dropbar, mini.nvim, themes |
| `nav.lua` | neo-tree, trouble, grug-far, persistence |
| `edit.lua` | nvim-treesitter, textobjects, multicursor, autotag |
| `lsp.lua` | mason, mason-lspconfig, mason-tool-installer, blink.cmp, conform, nvim-lint, the LSP wiring |
| `lang.lua` | Roslyn, web/Python/JSON server *settings*, neotest |
| `dap.lua` | nvim-dap, dap-ui, virtual text, adapters |
| `ai.lua` | opencode.nvim |

**One plugin, one spec.** Two specs for one repository is a silent bug: the
later one merges over the earlier one and nobody notices until a setting
"does not work".

Server *definitions* live in `lsp.lua` (`vim.lsp.config("*")`, per-server
settings, `vim.lsp.enable`), except Roslyn, which is owned by `lang.lua`
because it needs its own solution discovery.

## Runtime flow of one AI request

```
Cmd+K / <leader>aa
  └─ opencode.ask("@this: ")          you type the question
       └─ opencode CLI  ── SSE ──▶  opencode.nvim
            └─ edits a file on disk
                 ├─ BufWrite/autocmd → checktime (config/autocmds.lua) → buffer reloads
                 └─ permission request → diff tab → da / dr / dp / do
```

The AI never edits a buffer directly; it edits files, and Neovim notices. That
is why `autoread` + `checktime` are part of the core config rather than an
afterthought.

## What is deliberately absent

- No distro (LazyVim, AstroNvim…): they own the layout, and the point here is a
  config you can read in an afternoon.
- No `noice.nvim` (experimental), no `telescope` (snacks.picker covers it), no
  `toggleterm` (snacks.terminal), no `diffview` (stale; `:AIDiff` is a real
  `git diff`), no `vim-visual-multi` (stale; `multicursor.nvim`).
- No `mason-nvim-dap`: its handler API churns every few months, and two
  hand-written adapters are more honest than a mapping layer that silently
  stops working.

## Verification

`scripts/health.lua` is the contract, executable: it checks that plugins
installed, every Lua file parses, the registry has no duplicates, the documented
commands exist, this platform's shortcuts are bound, servers and formatters are
configured, and the debug adapters are registered. `make verify` runs it and
fails loudly. `make docs` regenerates `KEYBINDINGS.md` from the same registry and
fails on duplicate keys.
