-- ~/.config/nvim/init.lua
--
-- This is the front door. It is deliberately tiny: it only wires modules
-- together. Everything real lives in lua/config/ and lua/plugins/.
--
-- Read order matters:
--   1. options        -> editor settings (mouse, clipboard, indents)
--   2. keys           -> every keymap + user command (the single registry)
--   3. autocmds       -> small background behaviours
--   4. lazy           -> plugin manager (installs plugins on first launch)
--   5. commands       -> the handful of commands that belong to the core

-- The leader key must be set BEFORE lazy.nvim loads.
-- Space is the de-facto standard: press Space and wait, a menu appears.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

-- Neovide opened from Finder, and terminals that put Homebrew last, both give
-- Neovim a PATH where ripgrep, fd, opencode and the language servers are
-- missing. Fix that before anything tries to look for a binary.
require("config.platform").ensure_path()

require("keys").setup()
require("config.autocmds")
require("config.lazy")
require("config.commands")

-- Your personal overrides, if any. install.sh creates this file; it is
-- git-ignored, so it is the safe place to experiment.
pcall(require, "local")
