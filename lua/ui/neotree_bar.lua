-- lua/ui/neotree_bar.lua
--
-- VS Code puts a small icon toolbar above the file explorer: new file, new
-- folder, refresh, collapse all. Neo-tree has nothing there, so those actions
-- are keyboard-only ("a", "A", "R", "z") and hard to discover.
--
-- This module draws that toolbar in the neo-tree window's *window bar*, with
-- every icon a mouse target, plus a second group that switches the side panels.
-- Only neo-tree windows get a bar; every other window keeps dropbar's bars.

local M = {}

-- Font Awesome glyphs, all part of Nerd Fonts (no extra font needed).
local ICON = {
  add = "\u{f15b}", -- file
  folder = "\u{f07b}", -- folder
  refresh = "\u{f021}", -- refresh arrow
  collapse = "\u{f078}", -- chevron up: collapse the whole tree
  explorer = "\u{f0db}", -- sitemap
  search = "\u{f002}", -- magnifier
  git = "\u{f1d3}", -- git branch
  debug = "\u{f188}", -- bug
  ai = "\u{f086}", -- speech bubbles
}

-- Neo-tree's own default mappings (see its defaults.lua). Reusing the keys
-- instead of calling internals keeps the toolbar correct across neo-tree
-- versions and gives exactly the behaviour the keys already have.
local TREE_KEY = {
  add = "a", -- add
  folder = "A", -- add_directory
  refresh = "R", -- refresh
  collapse = "z", -- close_all_nodes
}

-- Left to right: the file actions, then the panel switchers.
local TREE_BUTTONS = { "add", "folder", "refresh", "collapse" }
local PANEL_BUTTONS = { "explorer", "search", "git", "debug", "ai" }

---True for a real neo-tree split (not a float, not another buffer).
local function is_tree(win)
  return vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_config(win).relative == ""
    and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
end

---The neo-tree window to act on, or nil when the explorer is closed.
local function neo_tree_win()
  -- The click arrives on the tree's own winbar, so that window is normally the
  -- current one. After a toggle it can be gone, hence the search below.
  local current = vim.api.nvim_get_current_win()
  if is_tree(current) then
    return current
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_tree(win) then
      return win
    end
  end
end

---Press a neo-tree key in its window. Mode "m" (remap) matters: "n" would skip
---mappings, so "a" would start Insert mode instead of neo-tree's add.
local function feed(win, keys)
  pcall(vim.api.nvim_set_current_win, win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
end

---Call a function from ui/panels lazily: a missing module must only warn.
local function with_panels(name, ...)
  local ok, panels = pcall(require, "ui.panels")
  local fn = ok and panels[name]
  if type(fn) ~= "function" then
    vim.notify("ui.panels." .. name .. " is not available", vim.log.levels.WARN)
    return
  end
  local called, err = pcall(fn, ...)
  if not called then
    vim.notify("ui.panels." .. name .. " failed: " .. tostring(err), vim.log.levels.WARN)
  end
end

---Open a snacks picker, falling back to a Vim command when snacks fails.
local function picker(what, fallback)
  local ok, snacks = pcall(require, "snacks")
  local fn = ok and snacks.picker and snacks.picker[what]
  if type(fn) == "function" and pcall(fn) then
    return
  end
  if fallback then
    pcall(vim.cmd, fallback)
  else
    vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
  end
end

---Run one toolbar button by name.
local function run(name)
  local key = TREE_KEY[name]
  if key then
    local win = neo_tree_win()
    if not win then
      vim.notify("The file explorer is not open (Cmd+B opens it)", vim.log.levels.WARN)
      return
    end
    feed(win, key)
    return
  end

  if name == "explorer" then
    with_panels("explorer")
  elseif name == "search" then
    picker("grep")
  elseif name == "git" then
    with_panels("git_changes")
  elseif name == "debug" then
    picker("diagnostics", "Trouble diagnostics")
  elseif name == "ai" then
    with_panels("ai_chat", true) -- true = focus the chat when it opens
  end
end

---Run a toolbar button. Public so tests and other modules can reuse it.
function M.click(name)
  run(name)
end

-- Neovim reads a click item's target as a plain function *name*, not as Lua:
-- `require'ui.neotree_bar'.click('add')` is accepted but never called (quotes
-- and parentheses are not part of a name). A dotted name does work, so publish
-- one small global table with a function per button.
_G.NeoTreeBar = {}
for _, group in ipairs({ TREE_BUTTONS, PANEL_BUTTONS }) do
  for _, name in ipairs(group) do
    _G.NeoTreeBar[name] = function()
      -- Defer: the click is handled mid mouse-event, where changing windows
      -- or feeding keys is unsafe.
      vim.schedule(function()
        M.click(name)
      end)
    end
  end
end

---One clickable icon: `%N@func@label@` is the statusline click syntax, where
---`label` is what the user sees and `func` is the function name run on click.
---
---Each label is " icon" (leading space only). A Nerd Font glyph is two cells
---wide, so this gives 3 cells per button: nine buttons plus the divider fit in
---neo-tree's 32-column window without the bar being truncated.
local function button(name, icon)
  return string.format("%%1@v:lua.NeoTreeBar.%s@ %s@", name, icon)
end

---Build the toolbar once, with standard highlight groups so it follows the
---colourscheme: Title for the icons, Comment for the divider.
local function build_bar()
  local parts = { "%#WinBar#", "%#Title#" }
  for _, name in ipairs(TREE_BUTTONS) do
    parts[#parts + 1] = button(name, ICON[name])
  end
  parts[#parts + 1] = "%#Comment# \u{2502} %#Title#"
  for _, name in ipairs(PANEL_BUTTONS) do
    parts[#parts + 1] = button(name, ICON[name])
  end
  parts[#parts + 1] = "%#WinBar#"
  return table.concat(parts)
end

local BAR = build_bar()

---Draw the toolbar on every neo-tree window. Call once at startup.
function M.setup()
  local group = vim.api.nvim_create_augroup("UserNeotreeBar", { clear = true })

  ---Put the winbar on the window showing `buf`, when it is a real split.
  local function attach(buf)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) ~= buf then
      win = vim.fn.win_findbuf(buf)[1]
      if not win then
        return -- not displayed yet: BufWinEnter will call us again
      end
    end
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return -- a float: no room for a bar
    end
    vim.wo[win].winbar = BAR
  end

  -- FileType fires once per neo-tree buffer; BufWinEnter fires again when the
  -- window is recreated (a toggle reuses the buffer), which keeps the bar.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "neo-tree",
    callback = function(ev)
      attach(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype == "neo-tree" then
        attach(ev.buf)
      end
    end,
  })
end

return M
