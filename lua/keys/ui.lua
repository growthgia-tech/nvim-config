-- lua/keys/ui.lua
--
-- Keys that change what the editor LOOKS like and which buffer/window you are
-- in: themes, line numbers, open tabs, splits and the breadcrumb bar.
--
-- Every mapping is declared in the registry (R.map / R.cmd) so it shows up in
-- which-key, :HelpMe and KEYBINDINGS.md automatically. Nothing here calls
-- vim.keymap.set directly.
--
-- NOTE ON RESERVED KEYS: VS Code's <D-1>..<D-9> (tab switching), <C-Tab>,
-- <D-S-[>, <D-S-]> and <D-\> belong to the navigation agent, so this file uses
-- Space-leader equivalents. Both styles are documented in :HelpMe.

local M = {}

---Go to the n-th listed buffer (1-based), counting like the tab strip does.
local function goto_buffer(n)
  local seen = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      seen = seen + 1
      if seen == n then
        vim.api.nvim_set_current_buf(buf)
        return
      end
    end
  end
  require("config.util").notify(("No buffer %d"):format(n), vim.log.levels.WARN)
end

---Move to the next (+1) or previous (-1) listed buffer, wrapping around.
local function cycle_buffer(step)
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      buffers[#buffers + 1] = buf
    end
  end
  if #buffers < 2 then
    return
  end

  local current = vim.api.nvim_get_current_buf()
  local index = 1
  for i, buf in ipairs(buffers) do
    if buf == current then
      index = i
    end
  end

  local next_index = (index - 1 + step) % #buffers + 1
  vim.api.nvim_set_current_buf(buffers[next_index])
end

---Close a buffer by picking its letter in the tab strip (bufferline).
---Falls back to plain :bdelete when bufferline is not installed.
local function close_buffer_pick()
  local ok = pcall(vim.cmd, "BufferLinePickClose")
  if not ok then
    pcall(vim.cmd, "bdelete")
  end
end

---Close every other buffer. Modified buffers are left alone so no work is
---lost; the user is told how many were skipped.
local function close_other_buffers()
  local ok, snacks = pcall(require, "snacks")
  if ok and type(snacks.bufdelete) == "table" and type(snacks.bufdelete.other) == "function" then
    snacks.bufdelete.other()
    return
  end

  local current = vim.api.nvim_get_current_buf()
  local skipped = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.bo[buf].buflisted then
      if vim.bo[buf].modified then
        skipped = skipped + 1
      else
        pcall(vim.cmd, "bdelete! " .. buf)
      end
    end
  end

  if skipped > 0 then
    require("config.util").notify(
      ("Closed the others, kept %d unsaved buffer(s)"):format(skipped),
      vim.log.levels.INFO
    )
  end
end

---Toggle relative line numbers (the "Vim mode" style gutter).
local function toggle_relativenumber()
  vim.wo.relativenumber = not vim.wo.relativenumber
  vim.wo.number = true
  require("config.util").notify(
    vim.wo.relativenumber and "Relative numbers on" or "Relative numbers off",
    vim.log.levels.INFO
  )
end

---Toggle soft wrapping of long lines.
local function toggle_wrap()
  vim.wo.wrap = not vim.wo.wrap
  require("config.util").notify(vim.wo.wrap and "Wrap on" or "Wrap off", vim.log.levels.INFO)
end

function M.setup(R)
  -- -------------------------------------------------------------------------
  -- which-key group labels (Space + key opens a readable sub-menu)
  -- -------------------------------------------------------------------------
  R.group("<leader>b", "Buffers")
  R.group("<leader>u", "UI")
  R.group("<leader>w", "Windows")

  -- -------------------------------------------------------------------------
  -- Theme
  -- -------------------------------------------------------------------------
  R.cmd("Theme", function()
    local ok, theme = pcall(require, "theme")
    if ok then
      theme.pick()
    else
      require("config.util").notify("lua/theme.lua is missing", vim.log.levels.ERROR)
    end
  end, { desc = "Pick a colourscheme", cat = "UI" })

  R.map({
    lhs = "<leader>ut",
    rhs = function()
      local ok, theme = pcall(require, "theme")
      if ok then
        theme.pick()
      end
    end,
    desc = "Pick a theme",
    cat = "UI",
  })

  -- -------------------------------------------------------------------------
  -- Look and feel toggles
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<leader>ul",
    rhs = toggle_relativenumber,
    desc = "Toggle relative line numbers",
    cat = "UI",
  })

  R.map({
    lhs = "<leader>uw",
    rhs = toggle_wrap,
    desc = "Toggle line wrapping",
    cat = "UI",
  })

  -- -------------------------------------------------------------------------
  -- Buffers (the tabs). <D-1>..<D-9> and <C-Tab> are reserved for the
  -- navigation agent; these leader versions always work, even in a terminal.
  -- -------------------------------------------------------------------------
  for n = 1, 9 do
    local index = n
    R.map({
      lhs = "<leader>b" .. index,
      rhs = function()
        goto_buffer(index)
      end,
      desc = ("Go to buffer %d"):format(index),
      cat = "Buffers",
    })
  end

  R.map({
    lhs = "<leader>bn",
    rhs = function()
      cycle_buffer(1)
    end,
    desc = "Next buffer (like Ctrl+Tab)",
    cat = "Buffers",
  })

  R.map({
    lhs = "<leader>bp",
    rhs = function()
      cycle_buffer(-1)
    end,
    desc = "Previous buffer",
    cat = "Buffers",
  })

  R.map({
    lhs = "<leader>bd",
    rhs = close_buffer_pick,
    desc = "Close buffer (pick its letter)",
    cat = "Buffers",
  })

  R.map({
    lhs = "<leader>bo",
    rhs = close_other_buffers,
    desc = "Close all other buffers (keeps unsaved ones)",
    cat = "Buffers",
  })

  -- -------------------------------------------------------------------------
  -- Windows / splits. Resizing stays on Neovim's built-in <C-w> keys: after
  -- a split press <C-w> then < or > (width), + or - (height), = (equal).
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<leader>wv",
    rhs = "<cmd>vsplit<cr>",
    desc = "Vertical split  (resize: <C-w>> / <C-w><)",
    cat = "Windows",
  })

  R.map({
    lhs = "<leader>wh",
    rhs = "<cmd>split<cr>",
    desc = "Horizontal split  (resize: <C-w>+ / <C-w>-)",
    cat = "Windows",
  })

  R.map({
    lhs = "<leader>wq",
    rhs = "<cmd>close<cr>",
    desc = "Close this window  (not the file)",
    cat = "Windows",
  })

  -- -------------------------------------------------------------------------
  -- Breadcrumbs (dropbar). The plugin loads lazily, so every call is guarded.
  -- -------------------------------------------------------------------------
  local function dropbar_call(method)
    return function()
      local ok, api = pcall(require, "dropbar.api")
      if ok and type(api[method]) == "function" then
        pcall(api[method])
      else
        require("config.util").notify("dropbar is not ready yet", vim.log.levels.WARN)
      end
    end
  end

  R.map({
    lhs = "<leader>;",
    rhs = dropbar_call("pick"),
    desc = "Pick a symbol from the breadcrumbs",
    cat = "UI",
  })

  R.map({
    lhs = "[;",
    rhs = dropbar_call("goto_context_start"),
    desc = "Go to the start of this code block",
    cat = "UI",
  })

  R.map({
    lhs = "];",
    rhs = dropbar_call("select_next_context"),
    desc = "Go to the next code block",
    cat = "UI",
  })

  -- -------------------------------------------------------------------------
  -- VS Code tab switching, on the keys VS Code uses.
  -- <D-1>..<D-9> jump to a tab; <C-Tab> and <D-S-[> / <D-S-]> cycle them.
  -- Terminals cannot send Cmd, so Ctrl+Tab is also bound; some terminals
  -- (Ghostty, WezTerm) deliver it, most do not — the leader keys above always
  -- work.
  -- -------------------------------------------------------------------------
  for n = 1, 9 do
    -- Capture the value: LuaJIT closures inside a numeric for loop all see
    -- the final value of the loop variable otherwise.
    local index = n
    R.map({
      lhs = "<D-" .. index .. ">",
      rhs = function()
        goto_buffer(index)
      end,
      desc = ("Go to tab %d"):format(index),
      cat = "Buffers",
    })
  end

  R.map({
    lhs = "<C-Tab>",
    rhs = function()
      cycle_buffer(1)
    end,
    desc = "Next tab",
    cat = "Buffers",
    modes = { "n", "i", "t" },
  })

  R.map({
    lhs = "<D-S-]>",
    rhs = function()
      cycle_buffer(1)
    end,
    desc = "Next tab",
    cat = "Buffers",
  })

  R.map({
    lhs = "<D-S-[>",
    rhs = function()
      cycle_buffer(-1)
    end,
    desc = "Previous tab",
    cat = "Buffers",
  })

  -- Cmd+\ splits the editor, exactly like VS Code.
  R.map({
    lhs = "<D-\\>",
    rhs = "<cmd>vsplit<cr>",
    desc = "Split the editor vertically",
    cat = "Windows",
    modes = { "n", "i" },
    -- Ctrl+\ is the terminal's own "send next key literally" chord, so the
    -- portable version is Alt+\.
    term = "<M-\\>",
  })
end

return M
