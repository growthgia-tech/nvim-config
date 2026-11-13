-- lua/keys/core.lua
--
-- The shortcuts you would reach for in VS Code, bound the VS Code way.
-- These are intentionally boring and safe: they must work on day one, before
-- any plugin has loaded.
--
-- Cmd only reaches Neovim inside Neovide (or when the terminal synthesises
-- <D-...>). Every entry below also has a `term =` fallback for plain terminals.

local M = {}

function M.setup(R)
  local U = require("config.util")

  -- -------------------------------------------------------------------------
  -- Files
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<D-s>",
    rhs = U.save,
    desc = "Save file",
    cat = "Files",
    modes = { "n", "i", "v" },
    term = "<C-s>",
  })

  R.map({
    lhs = "<D-S-s>",
    rhs = "<cmd>wall<cr>",
    desc = "Save all files",
    cat = "Files",
    modes = { "n", "i" },
    term = "<C-S-s>",
  })

  R.map({
    lhs = "<D-w>",
    rhs = U.close_buffer,
    desc = "Close tab (asks to save)",
    cat = "Files",
    modes = { "n", "i", "v" },
    term = "<C-S-w>",
  })

  R.map({
    lhs = "<D-o>",
    rhs = "<cmd>edit<cr>",
    desc = "Open another file (browse)",
    cat = "Files",
    modes = { "n" },
    term = "<C-S-o>",
  })

  -- -------------------------------------------------------------------------
  -- Undo / redo
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<D-z>",
    rhs = "u",
    desc = "Undo",
    cat = "Editing",
    modes = { "n", "v" },
    term = "<C-z>",
  })

  R.map({
    lhs = "<D-z>",
    rhs = "<C-o>u",
    desc = "Undo (while typing)",
    cat = "Editing",
    modes = { "i" },
    term = "<C-z>",
  })

  R.map({
    lhs = "<D-S-z>",
    rhs = "<C-r>",
    desc = "Redo",
    cat = "Editing",
    modes = { "n", "v" },
    term = "<C-S-z>",
  })

  -- -------------------------------------------------------------------------
  -- Clipboard (system clipboard, not Vim registers)
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<D-c>",
    rhs = '"+y',
    desc = "Copy selection",
    cat = "Clipboard",
    modes = { "v", "x" },
    term = "<C-c>",
  })

  R.map({
    lhs = "<D-c>",
    rhs = '"+yy',
    desc = "Copy current line",
    cat = "Clipboard",
    modes = { "n" },
    term = "<C-c>",
  })

  R.map({
    lhs = "<D-v>",
    rhs = U.paste,
    desc = "Paste from system clipboard",
    cat = "Clipboard",
    modes = { "n", "i", "v", "c", "t" },
    term = "<C-v>",
    -- Ctrl+V in visual mode is Vim's blockwise-visual, and in normal mode it
    -- is VISUAL BLOCK. Only take it where pasting is what you want.
    term_modes = { "n", "i", "c", "t" },
  })

  R.map({
    lhs = "<D-x>",
    rhs = '"+d',
    desc = "Cut selection",
    cat = "Clipboard",
    modes = { "v", "x" },
    term = "<C-S-x>",
  })

  R.map({
    lhs = "<D-x>",
    rhs = '"+dd',
    desc = "Cut current line",
    cat = "Clipboard",
    modes = { "n" },
    term = "<C-S-x>",
  })

  R.map({
    lhs = "<D-a>",
    rhs = function()
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<Esc>ggVG", true, false, true),
        "n",
        false
      )
    end,
    desc = "Select all",
    cat = "Clipboard",
    modes = { "n", "i", "v" },
    term = "<C-S-a>",
  })

  -- -------------------------------------------------------------------------
  -- Comments (Neovim's built-in gc/gcc)
  -- feedkeys with "m" so the built-in mapping is allowed to expand.
  -- -------------------------------------------------------------------------
  local function toggle_comment()
    local mode = vim.fn.mode()
    if mode:match("[vV\22]") then
      vim.api.nvim_feedkeys("gc", "m", false)
    else
      vim.api.nvim_feedkeys("gcc", "m", false)
    end
  end

  R.map({
    lhs = "<D-/>",
    rhs = toggle_comment,
    desc = "Toggle comment",
    cat = "Editing",
    modes = { "n", "v", "x" },
    term = "<C-/>",
  })

  -- -------------------------------------------------------------------------
  -- Terminals: Esc leaves terminal mode only when pressed twice, so a single
  -- Esc still reaches programs that need it (OpenCode uses it to interrupt).
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<Esc><Esc>",
    rhs = "<C-\\><C-n>",
    desc = "Leave terminal mode (press Esc twice)",
    cat = "Terminal",
    modes = { "t" },
  })

  -- -------------------------------------------------------------------------
  -- Always-available escape routes, discoverable by muscle memory.
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<Esc>",
    rhs = "<cmd>nohlsearch<cr><Esc>",
    desc = "Clear search highlight",
    cat = "Editing",
    modes = { "n" },
    opts = { silent = true },
  })
end

return M
