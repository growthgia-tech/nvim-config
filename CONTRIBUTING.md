# Contributing

This config is meant to be edited — by you, on a Tuesday, when something
annoys you. These are the habits that keep it from rotting.

## Before you change anything

```sh
git -C ~/.config/nvim init          # first time only
git -C ~/.config/nvim add -A
git -C ~/.config/nvim commit -m "baseline"
```

A commit before an experiment turns "I broke my editor" into
`git checkout .`.

## The loop

1. Edit a file in `lua/keys/` or `lua/plugins/`.
2. `:Reload` inside Neovim (or restart for plugin changes).
3. Test the thing. Not "it loaded" — actually press the key.
4. `make docs` if you touched keymaps, and commit the regenerated
   `KEYBINDINGS.md`.
5. `make verify` before you call it done.

## Where a new behaviour goes

- **A key or a command** → `lua/keys/*.lua`, declared with `R.map` / `R.cmd`.
- **A plugin setting** → the matching file in `lua/plugins/`.
- **Something that needs a plugin loaded and is called from more than one
  place** (the dashboard, a panel, a preview) → `lua/ui/*.lua`, wired from
  `lua/plugins/ui.lua`'s `config`. Those modules must never error when the
  plugin is missing: `pcall(require, ...)` and a readable `vim.notify`.

## Adding a key

Everything goes through the registry (`lua/config/registry.lua`):

```lua
R.map({
  lhs = "<leader>fz",
  rhs = function() ... end,
  desc = "Fuzzy-find in the current buffer",  -- a sentence, imperative mood
  cat = "Search",                              -- a :HelpMe section
  term = "<C-S-z>",                            -- portable fallback, optional
})
```

Rules that the duplicate audit enforces for you:

- `desc` is required and is a sentence: "Find file", not "find".
- `cat` must be one of the existing categories, otherwise you create a new,
  lonely section in the help. `make docs` shows you the full list.
- Do not bind `<D-...>` unless the action is a genuine VS Code equivalent; and
  if you do, provide `term` so Linux and Windows can reach it too.
- Reserved Vim keys stay reserved: `Ctrl+W`, `Ctrl+B`, `Ctrl+V`, `Ctrl+O`,
  `Ctrl+I`, and insert-mode `Ctrl+P`/`Ctrl+N`. Use `Ctrl+Shift+` or a leader
  key instead.

## Adding a plugin

```lua
-- lua/plugins/<area>.lua
return {
  {
    "author/plugin",
    event = "VeryLazy",          -- or lazy = false when the UI needs it early
    opts = { ... },              -- prefer opts over config + setup()
  },
}
```

- One spec per plugin, in the file that owns that area. `snacks.nvim` lives in
  `ui.lua` and nowhere else.
- Prefer `opts`; use `config` only when setup is not a plain table merge.
- No `mason-nvim-dap`, no bundled distro, no plugin that duplicates something
  Neovim 0.12 already does.
- If it needs a binary, add it to `mason-tool-installer`'s `ensure_installed`
  (in `lua/plugins/lsp.lua`) rather than telling the user to install it.

## Installing a Node tool

Use pnpm, never a second npm tree:

```sh
pnpm add -g <package>          # shared store, one copy per version
pnpm store path                # where that store lives
```

The config's installer does the same thing, falls back to npm only when pnpm is
absent, and `lua/config/platform.lua` puts pnpm's global `bin` on Neovim's
`PATH`. A tool installed by Homebrew or pnpm is used as-is: `scripts/install-tools.lua`
skips any Mason package whose binary is already on `PATH`, so you never end up
with two copies of the same server.

## Adding a language

1. `:Mason`, install the server, confirm it starts on a real file.
2. Add the server name to `servers` in `lua/plugins/lsp.lua` (one list, used
   by both Mason and `vim.lsp.enable`).
3. Add its formatter to `conform.nvim`'s `formatters_by_ft`, and its linter to
   `nvim-lint`'s `linters_by_ft` if it has one.
4. Add a parser to the `nvim-treesitter` install list in `lua/plugins/edit.lua`.
5. Add a row to the languages table in `README.md`.

## Editing the installers

`install.sh` (macOS/Linux) and `install.ps1` (Windows) are run by people whose
editor is currently broken, so they must be:

- **idempotent** — every step checks before acting;
- **non-destructive** — back up, never delete a config;
- **honest** — when a package is not available, print the exact manual command
  instead of pretending it worked;
- **tested** — `bash -n install.sh` at minimum, `./install.sh --dry-run` when
  you add a stage.

Changing a package name? Check it exists on the platform you are claiming to
support, or route it through `pkg_name()` in `install.sh` with a per-manager
mapping.

## Reporting a problem

Include: `nvim --version`, `:Health` output, the failing key or command, and
what you expected. `make verify` output is even better.
