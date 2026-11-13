-- lua/ui/neotree_bar.lua
--
-- VS Code puts an icon toolbar above the file explorer: new file, new folder,
-- refresh, collapse all. Neo-tree has none, so those actions are keyboard-only.
-- This module draws that toolbar in the neo-tree *window bar* (file actions, a
-- divider, then the side panels). Other windows keep dropbar's breadcrumbs.

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
  editors = "\u{f0c5}", -- open editors (stacked pages)
  menu = "\u{f141}", -- "..." panel menu
}

-- Left to right: the file actions, then the panel switchers.
local TREE_BUTTONS = { "add", "folder", "refresh", "collapse" }
local PANEL_BUTTONS = { "explorer", "search", "git", "debug", "editors", "menu", "ai" }

-- Neo-tree's own keys (its defaults.lua): the bar does exactly what they do.
local TREE_KEY = { add = "a", folder = "A", refresh = "R", collapse = "z" }

-- What each panel button opens: ui/panels, or a snacks picker (with fallback).
local PANEL = {
  explorer = { panels = "explorer" },
  search = { picker = "grep" },
  git = { panels = "git_changes" },
  debug = { picker = "diagnostics", fallback = "Trouble diagnostics" },
  ai = { panels = "ai_chat", arg = true }, -- focus the chat when it opens
}

---A non-floating window showing a neo-tree buffer, or nil.
local function tree_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local split = vim.api.nvim_win_get_config(win).relative == ""
    if split and vim.bo[buf].filetype == "neo-tree" then
      return win
    end
  end
end

---Press a neo-tree key in its window. Mode "m" (remap) matters: "n" skips
---mappings, so "a" would start Insert mode instead of neo-tree's add.
local function tree_key(key)
  local win = tree_win()
  if not win then
    return vim.notify("The file explorer is not open (Cmd+B opens it)", vim.log.levels.WARN)
  end
  pcall(vim.api.nvim_set_current_win, win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "m", false)
end

---Call a function from ui/panels lazily: a missing module must only warn.
local function with_panels(name, ...)
  local ok, panels = pcall(require, "ui.panels")
  local fn = ok and panels[name]
  if type(fn) ~= "function" then
    return vim.notify("ui.panels." .. name .. " is not available", vim.log.levels.WARN)
  end
  local called, err = pcall(fn, ...)
  if not called then
    vim.notify("ui.panels." .. name .. " failed: " .. tostring(err), vim.log.levels.WARN)
  end
end

---Open a snacks picker, with a Vim command as fallback.
local function picker(what, fallback)
  local ok, snacks = pcall(require, "snacks")
  local fn = ok and snacks.picker and snacks.picker[what]
  if type(fn) == "function" and pcall(fn) then
    return
  end
  if fallback then
    return pcall(vim.cmd, fallback)
  end
  vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
end

---Run a toolbar button. Public so tests and other modules can reuse it.
function M.click(name)
  local panel = PANEL[name]
  if TREE_KEY[name] then
    tree_key(TREE_KEY[name])
  elseif panel and panel.panels then
    with_panels(panel.panels, panel.arg)
  elseif panel then
    picker(panel.picker, panel.fallback)
  end
end

-- A click item names a plain function (no quotes/parens): one global per button.
_G.NeoTreeBar = {}
for _, group in ipairs({ TREE_BUTTONS, PANEL_BUTTONS }) do
  for _, name in ipairs(group) do
    _G.NeoTreeBar[name] = function()
      -- Deferred: the click is handled mid mouse-event.
      vim.schedule(function()
        M.click(name)
      end)
    end
  end
end

local SPANS = {} -- cells each button occupies, so a click maps to a name

---One clickable icon (`%N@func@label@`): `label` is what the user sees, `func`
---runs on click. A label is " icon"; a Nerd Font glyph is two cells wide, so a
---button takes 3 cells and the bar fits neo-tree's 32-column window.
local function button(name, icon, col)
  local text = " " .. icon
  local width = vim.fn.strdisplaywidth(text)
  SPANS[#SPANS + 1] = { name = name, from = col, to = col + width - 1 }
  return string.format("%%1@v:lua.NeoTreeBar.%s@%s@", name, text), col + width
end

---The button covering 0-based cell `col`.
local function hit(col)
  for _, span in ipairs(SPANS) do
    if col >= span.from and col <= span.to then
      return span.name
    end
  end
end

---Build the bar once; highlight groups keep it in step with the theme.
local function build_bar()
  local parts = { "%#WinBar#", "%#Title#" }
  local col = 0
  for _, name in ipairs(TREE_BUTTONS) do
    parts[#parts + 1], col = button(name, ICON[name], col)
  end
  parts[#parts + 1] = "%#Comment# \u{2502} %#Title#"
  col = col + vim.fn.strdisplaywidth(" \u{2502} ")
  for _, name in ipairs(PANEL_BUTTONS) do
    parts[#parts + 1], col = button(name, ICON[name], col)
  end
  parts[#parts + 1] = "%#WinBar#"
  return table.concat(parts)
end

local BAR = build_bar()

---Make left clicks in the bar run our buttons. neo-tree maps <LeftMouse> (click
---opens), and a buffer mapping shadows a winbar's click items because Neovim
---resolves the key before the mouse position. This mapping sits in front and
---forwards other clicks to neo-tree's own.
local function install_mouse(buf)
  if vim.b[buf].neotree_bar_mouse then
    return
  end
  -- Saved before it is replaced, so clicks in the tree still open nodes.
  local prev = vim.api.nvim_buf_call(buf, function()
    return vim.fn.maparg("<LeftMouse>", "n", false, true)
  end)
  local forward = type(prev) == "table" and prev.callback or nil
  if not forward then
    return -- neo-tree's mapping is not there yet: retry on the next enter
  end
  vim.b[buf].neotree_bar_mouse = true

  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.line == 0 and pos.winrow == 1 then -- the bar, above the text
      local name = hit(pos.wincol - 1)
      if name then
        M.click(name)
      end
      return -- clicks on the bar or its gaps never open a file
    end
    if forward then
      forward()
    end
  end, { buffer = buf, nowait = true, desc = "Toolbar or open" })
end

---Draw the toolbar on every neo-tree window. Call once at startup.
function M.setup()
  local group = vim.api.nvim_create_augroup("UserNeotreeBar", { clear = true })

  ---Set the bar on the split that shows `buf`.
  local function show(buf)
    local win = tree_win()
    if win and vim.api.nvim_win_get_buf(win) == buf then
      vim.wo[win].winbar = BAR
    end
  end

  -- FileType fires once per buffer; BufWinEnter again when a toggle recreates
  -- the window around the reused buffer, which is what keeps the bar alive.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "neo-tree",
    callback = function(ev)
      show(ev.buf)
    end,
  })

  -- Mappings only exist after neo-tree sets the buffer up, hence BufWinEnter.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].filetype == "neo-tree" then
        show(ev.buf)
        install_mouse(ev.buf)
      end
    end,
  })
end

return M
