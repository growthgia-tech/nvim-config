-- lua/ui/dashboard.lua
--
-- The start screen (snacks' dashboard) is a normal buffer with a few
-- buffer-local keymaps. That means the mouse only moves the cursor: clicking
-- "Find file" does nothing, and there is no way to *open a folder* the way
-- VS Code's "File -> Open Folder" does.
--
-- This module adds the three things people expect from a start screen:
--
--   1. a single left click runs the item under the pointer
--   2. hovering an item shows a tooltip explaining what it does
--   3. a folder picker (`:OpenFolder`, and the "Open folder" item)
--
-- Everything is defensive: snacks.nvim is optional at runtime, a dashboard that
-- is already closed is ignored, and a missing folder shows a message instead of
-- an error.

local M = {}

local current ---@type table? -- the live Snacks.dashboard instance
local tip_win, tip_buf ---@type number?, number?

---The live dashboard instance (exposed for tests and for `:checkhealth`).
function M.instance()
  return current
end

---Close the hover tooltip, if one is open.
function M.close_tooltip()
  if tip_win and vim.api.nvim_win_is_valid(tip_win) then
    pcall(vim.api.nvim_win_close, tip_win, true)
  end
  if tip_buf and vim.api.nvim_buf_is_valid(tip_buf) then
    pcall(vim.api.nvim_buf_delete, tip_buf, { force = true })
  end
  tip_win, tip_buf = nil, nil
end

---The dashboard item rendered on buffer line `line` (if it is actionable).
---@param inst table
---@param line number 1-based buffer line
---@return table?
local function item_at(inst, line)
  for _, item in ipairs(inst.items or {}) do
    if item._ and item._.row == line then
      return item
    end
  end
end

---The lines shown in the tooltip for `item`.
---@param item table
---@return string[]
local function tooltip_lines(item)
  local lines = {}

  if item.file then
    lines[#lines + 1] = vim.fn.fnamemodify(item.file, ":~")
    lines[#lines + 1] = vim.fn.isdirectory(item.file) == 1 and "Switch to this project folder"
      or "Open this file in the editor"
  elseif item.desc then
    lines[#lines + 1] = item.desc
  end

  if item.tooltip then
    lines[#lines + 1] = item.tooltip
  end

  if item.key then
    lines[#lines + 1] = ("Shortcut: %s"):format(item.key)
  end

  return lines
end

---Draw a small "what does this do?" window below (or above) `item`.
---@param item table
local function show_tooltip(item)
  M.close_tooltip()

  local lines = tooltip_lines(item)
  if #lines == 0 then
    return
  end

  local win = vim.api.nvim_get_current_win()
  local row = (item._ and item._.row) or vim.api.nvim_win_get_cursor(win)[1]

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(math.max(width + 2, 22), 78)

  local height = #lines
  local win_h = vim.api.nvim_win_get_height(win)
  -- Below the item normally (there is usually room), above it when the item
  -- sits near the bottom of the screen.
  local top = row + height + 1 <= win_h and row or math.max(0, row - 1 - height)
  local col = math.max(0, math.floor((vim.api.nvim_win_get_width(win) - width) / 2))

  tip_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(tip_buf, 0, -1, false, lines)
  vim.bo[tip_buf].bufhidden = "wipe"
  vim.bo[tip_buf].modifiable = false

  local ok, winid = pcall(vim.api.nvim_open_win, tip_buf, false, {
    relative = "win",
    win = win,
    row = top,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 70,
    title = " What this does ",
    title_pos = "center",
  })

  if not ok then
    tip_buf = nil
    return
  end
  tip_win = winid

  vim.api.nvim_buf_add_highlight(tip_buf, -1, "Title", 0, 0, -1)
  if #lines > 1 then
    vim.api.nvim_buf_add_highlight(tip_buf, -1, "Comment", #lines - 1, 0, -1)
  end
end

---Left click: move to the clicked item and run it.
local function click()
  local pos = vim.fn.getmousepos()
  local inst = current
  M.close_tooltip()

  -- Keep the normal left-click behaviour (place the cursor on the clicked cell)
  -- by replaying the key without remapping, then run the item ourselves.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true),
    "n",
    false
  )

  if not inst or not pos or type(pos.line) ~= "number" or pos.line <= 0 then
    return
  end
  -- Only the dashboard's own window: a click on a split next to it is normal.
  if pos.winid ~= vim.api.nvim_get_current_win() then
    return
  end

  local item = item_at(inst, pos.line)
  if not item or not item.action then
    return
  end

  vim.schedule(function()
    if not inst.buf or not vim.api.nvim_buf_is_valid(inst.buf) then
      return
    end
    inst:action(item.action)
  end)
end

---Hover: describe the item under the cursor (fires `updatetime` after it stops).
local function idle()
  local inst = current
  if not inst or not inst.items then
    return M.close_tooltip()
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local item = item_at(inst, line)
  if item and item.action then
    show_tooltip(item)
  else
    M.close_tooltip()
  end
end

---Attach the mouse/tooltip layer to one dashboard buffer.
---@param buf number
local function attach(buf)
  vim.b[buf].user_dashboard = true

  vim.keymap.set("n", "<LeftMouse>", click, {
    buffer = buf,
    desc = "Open the dashboard item under the mouse",
    nowait = true,
  })

  local group = vim.api.nvim_create_augroup("UserDashboard", { clear = true })
  vim.api.nvim_create_autocmd("CursorHold", {
    group = group,
    buffer = buf,
    callback = idle,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "InsertEnter" }, {
    group = group,
    buffer = buf,
    callback = M.close_tooltip,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = M.close_tooltip,
  })
end

---Read the folder that should be opened: argument, prompt, or nil.
---@param given? string
---@param cb fun(dir: string)
local function ask_folder(given, cb)
  if given and given ~= "" then
    return cb(given)
  end

  local start = vim.fn.expand("~/Dev")
  if vim.fn.isdirectory(start) == 0 then
    start = vim.fn.getcwd()
  end

  vim.ui.input({
    prompt = "Open folder: ",
    default = start .. "/",
    -- snacks' input forwards this to the completion popup, so Tab (and the
    -- mouse) can walk the directory tree instead of typing it from memory.
    completion = "dir",
  }, function(answer)
    if answer and answer ~= "" then
      cb(answer)
    end
  end)
end

---Open `dir` as the current project: change directory, close the start screen,
---and show the file tree, like VS Code's "Open Folder".
---@param dir string
function M.open_dir(dir)
  dir = vim.fs.normalize(vim.fn.expand(dir))

  if vim.fn.isdirectory(dir) == 0 then
    vim.notify(("Not a folder: %s"):format(dir), vim.log.levels.ERROR)
    return
  end

  M.close_tooltip()
  vim.cmd("cd " .. vim.fn.fnameescape(dir))

  -- Wipe the start screen only when it is the buffer we are on (a floating
  -- dashboard is closed before its action runs, so the current buffer there is
  -- the user's file and must not be touched).
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "snacks_dashboard" then
    vim.cmd("silent! bwipeout! " .. buf)
  end

  local ok, panels = pcall(require, "ui.panels")
  if ok then
    pcall(panels.reveal, dir)
  else
    pcall(vim.cmd, "silent! Explore " .. vim.fn.fnameescape(dir))
  end

  vim.notify("Opened " .. vim.fn.fnamemodify(dir, ":~"), vim.log.levels.INFO)
end

---Create a new file by name (VS Code's "New File"): asks for a path with file
---completion, then opens it. The file appears on disk when you save.
---@param given? string
function M.new_file(given)
  if given and given ~= "" then
    local path = vim.fs.normalize(vim.fn.expand(given))
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    return
  end

  local dir = vim.uv.cwd()
  vim.ui.input({
    prompt = "New file: ",
    default = dir .. "/",
    completion = "file",
  }, function(name)
    if not name or name == "" then
      return
    end
    local path = vim.fs.normalize(vim.fn.expand(name))
    if vim.fn.isdirectory(path) == 1 then
      vim.notify("That is a folder: " .. path, vim.log.levels.ERROR)
      return
    end
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end)
end

---Ask for a folder (unless one was given) and open it.
---
---The browser (lua/ui/folder.lua) is the main path: navigating with the mouse
---is the part a beginner can use. Typing a path is still available inside it
---(`<C-l>`) and as a fallback when the module is missing.
---@param given? string
function M.open_folder(given)
  if given and given ~= "" then
    return M.open_dir(given)
  end

  local ok, folder = pcall(require, "ui.folder")
  if ok and type(folder.pick) == "function" then
    return folder.pick({ on_choose = M.open_dir })
  end

  ask_folder(nil, M.open_dir)
end

---The dashboard's own "Git Changes" section: the working tree, at a glance.
---
---This is what VS Code shows in Source Control without opening anything. If
---the current folder is not a repository (or there is nothing to show) the
---section renders as an empty list and disappears.
---@return snacks.dashboard.Item[]
local function git_changes_section()
  local root = vim.fn.getcwd()
  local ok, out = pcall(vim.fn.systemlist, {
    "git",
    "-C",
    root,
    "status",
    "--porcelain=v1",
    "--untracked-files=all",
  })
  if not ok or vim.v.shell_error ~= 0 then
    return {}
  end

  local items = {}
  for _, line in ipairs(out) do
    local path = line:sub(4)
    if path ~= "" then
      -- Renames are "R  old -> new": keep the new name.
      path = path:gsub("^.* %-> ", "")
      items[#items + 1] = {
        file = vim.fs.joinpath(root, path),
        icon = "file",
        action = ":e " .. vim.fn.fnameescape(path),
        autokey = true,
      }
      if #items >= 5 then
        break
      end
    end
  end
  return items
end

---Wrap Snacks.dashboard.open so every dashboard gets the mouse layer.
function M.setup()
  local ok, dashboard = pcall(require, "snacks.dashboard")
  if not ok or type(dashboard.open) ~= "function" then
    return
  end

  -- A custom section, used by ui.lua's dashboard config.
  dashboard.sections = dashboard.sections or {}
  dashboard.sections.git_changes = git_changes_section
  if dashboard.__user_clickable then
    return
  end

  local open = dashboard.open
  dashboard.open = function(opts)
    local self = open(opts)
    if self and self.buf and vim.api.nvim_buf_is_valid(self.buf) then
      current = self
      attach(self.buf)
    end
    return self
  end
  dashboard.__user_clickable = true
end

return M
