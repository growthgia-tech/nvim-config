-- lua/config/options.lua
--
-- Plain editor settings. No plugins here, so this file always works even if
-- a plugin fails to install. Safe defaults for a VS Code user.

local opt = vim.opt

-- ---------------------------------------------------------------------------
-- Who am I / where are my files
-- ---------------------------------------------------------------------------
vim.g.beginner_mode = true -- toggled by :Beginner and :VimMode

-- ---------------------------------------------------------------------------
-- Mouse: click to move, drag to select, drag borders to resize, wheel to scroll
-- ---------------------------------------------------------------------------
opt.mouse = "a"

-- `mousemoveevent` is what makes hover tooltips and dropbar breadcrumb
-- highlighting work. Neovim warns it can interrupt pending key sequences if
-- the mouse moves; that is a fair trade for "hover works everywhere".
opt.mousemoveevent = true

-- Right-click opens OUR context menu (lua/keys/nav.lua). `extend` stops
-- Neovim's built-in (and empty) popup menu from stealing the click first.
opt.mousemodel = "extend"

-- ---------------------------------------------------------------------------
-- System clipboard: Cmd+C/V/X/A talk to the macOS clipboard
-- ---------------------------------------------------------------------------
opt.clipboard = "unnamedplus"

-- ---------------------------------------------------------------------------
-- Look and feel
-- ---------------------------------------------------------------------------
opt.termguicolors = true
opt.number = true
opt.relativenumber = false -- absolute numbers: less confusing for a beginner
opt.signcolumn = "yes:2" -- always reserve room, so text never jumps
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true
opt.list = false
opt.showmode = false -- the statusline shows the mode in words instead
opt.cmdheight = 1
opt.pumheight = 12
opt.splitright = true
opt.splitbelow = true
opt.winborder = "rounded" -- every floating window gets a border (0.11+)
opt.laststatus = 3 -- one global statusline, like VS Code's single bar

-- ---------------------------------------------------------------------------
-- Behaviour
-- ---------------------------------------------------------------------------
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.autoindent = true
opt.shiftround = true -- indent in whole steps of shiftwidth

opt.ignorecase = true -- searching is case-insensitive...
opt.smartcase = true -- ...unless you type a capital letter
opt.hlsearch = true
opt.incsearch = true

opt.undofile = true -- persistent undo: survives closing Neovim
opt.undolevels = 10000
opt.backup = false
opt.writebackup = false
opt.swapfile = false -- fewer scary "swap file" dialogs for a beginner

opt.updatetime = 250
opt.timeoutlen = 300 -- how long to wait for the rest of a key sequence
opt.ttimeoutlen = 10

opt.autoread = true -- reload files changed on disk (OpenCode edits!)
opt.confirm = true -- "Save changes?" instead of refusing to quit
opt.title = true

opt.completeopt = { "menu", "menuone", "noselect" }
opt.diffopt:append("linematch:60") -- readable side-by-side diffs

-- Sessions: what gets restored by persistence.nvim
opt.sessionoptions = {
  "buffers",
  "curdir",
  "tabpages",
  "winsize",
  "help",
  "globals",
  "skiprtp",
  "folds",
}

-- ---------------------------------------------------------------------------
-- Neovide (the recommended GUI). Harmless when running in a terminal.
-- ---------------------------------------------------------------------------
if vim.g.neovide then
  -- JetBrainsMono Nerd Font is installed by install.sh.
  vim.o.guifont = "JetBrainsMono Nerd Font Mono:h14"

  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_padding_top = 8
  vim.g.neovide_padding_bottom = 8
  vim.g.neovide_padding_left = 8
  vim.g.neovide_padding_right = 8
  vim.g.neovide_opacity = 1.0
  vim.g.neovide_normal_opacity = 1.0
  vim.g.neovide_window_blurred = false

  -- REQUIRED. Default is "none", which means Option+Arrow never reaches
  -- Neovim as <M-Up>/<M-Down> and "move line" silently stops working.
  -- "only_left" keeps Option-composed characters (é, ñ) working on the right.
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"

  vim.g.neovide_confirm_quit = true
  vim.g.neovide_remember_window_size = true
  vim.g.neovide_cursor_animation_length = 0.08
  vim.g.neovide_cursor_trail_size = 0.6
  vim.g.neovide_system_scrollbar = true -- real macOS scrollbar
  vim.g.neovide_proxy_icon = true -- native title-bar file icon + edited dot
  vim.g.neovide_theme = "auto"
end
