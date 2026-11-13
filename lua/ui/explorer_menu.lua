-- lua/ui/explorer_menu.lua
--
-- VS Code's explorer has a right-click menu; neo-tree has only keys. This
-- draws it under the mouse, then feeds the tree's own action or does the work.

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Explorer" })
end

---True when the screen clipboard holds something worth pasting.
local function clipboard_filled()
  for _, reg in ipairs({ "+", '"' }) do
    local ok, value = pcall(vim.fn.getreg, reg)
    if ok and value ~= "" then
      return true
    end
  end
  return false
end

---Feed one of neo-tree's keys to its mapping. "m" (remap) is required: the
---action lives in a mapping, so feeding "a" unmapped would type into the tree.
local function feed_tree_key(key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "m", false)
end

---The neo-tree state for `winid`, trying the public entry points in order.
local function tree_state(winid)
  local ok, neotree = pcall(require, "neo-tree")
  if ok and type(neotree.get_state) == "function" then
    local found, state = pcall(neotree.get_state, "filesystem")
    if found and state then
      return state
    end
  end

  local manager_ok, manager = pcall(require, "neo-tree.sources.manager")
  if not manager_ok then
    return nil
  end
  local found, state = pcall(manager.get_state_for_window, winid)
  return found and state or nil
end

---What the menu needs to know about the clicked row. Prefer the node; fall
---back to the filename under the cursor joined to the tree root.
local function row_info(winid)
  local state = tree_state(winid)
  local root = state and state.path
  local node
  if state and state.tree then
    pcall(function()
      node = state.tree:get_node()
    end)
  end
  local path = node and (node.path or node:get_id()) or nil
  local kind = node and node.type
  if type(path) ~= "string" or path == "" then
    local name = vim.trim(vim.fn.expand("<cfile>"))
    local candidate = root and name ~= "" and (root .. "/" .. name)
    path = candidate and vim.uv.fs_stat(candidate) and candidate or nil
  end
  local is_dir = kind == "directory" or (path ~= nil and vim.fn.isdirectory(path) == 1)
  local is_root = node ~= nil and path ~= nil and (node:get_parent_id() == nil or path == root)
  local dir = is_dir and path or (path and vim.fs.dirname(path)) or root
  return { path = path, dir = dir, is_root = is_root }
end
-- Actions -------------------------------------------------------------------

---Reveal the row in the operating system's file manager.
local function reveal(info)
  local cmd = { "xdg-open", vim.fs.dirname(info.path) }
  if vim.fn.has("mac") == 1 then
    cmd = { "open", "-R", info.path }
  elseif vim.uv.os_uname().sysname == "Windows_NT" then
    cmd = { "explorer", "/select," .. info.path }
  end
  if vim.fn.jobstart(cmd, { detach = true }) <= 0 then
    notify("Could not open the file manager", vim.log.levels.ERROR)
  end
end
local function terminal(info)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.terminal then
    snacks.terminal.open(nil, { cwd = info.dir, win = { position = "botright", height = 0.3 } })
    return
  end
  -- Without snacks, a plain :terminal with the window-local directory.
  vim.cmd("botright split")
  vim.cmd("lcd " .. vim.fn.fnameescape(info.dir))
  vim.cmd("terminal")
end
local function find_in_folder(info)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker and snacks.picker.grep then
    snacks.picker.grep({ cwd = info.dir })
    return
  end
  vim.ui.input({ prompt = "Find in " .. vim.fs.basename(info.dir) .. ": " }, function(term)
    if term and term ~= "" then
      pcall(vim.cmd, "grep! " .. vim.fn.shellescape(term) .. " " .. vim.fn.shellescape(info.dir))
      pcall(vim.cmd, "copen")
    end
  end)
end

local function copy(text, what)
  if text then
    pcall(vim.fn.setreg, "+", text)
    notify("Copied " .. what)
  end
end

local function copy_path(info)
  copy(info.path, "path")
end

local function copy_relative_path(info)
  copy(info.path and vim.fn.fnamemodify(info.path, ":."), "relative path")
end

-- The item list. `needs` is the row requirement (dir, path, non-root file, or
-- a folder plus clipboard text); a `feed` item runs its neo-tree mapping.
local ACTIONS = {
  { icon = "󰈔", label = "New File…", key = "a", needs = "dir", feed = "a" },
  { icon = "󰉋", label = "New Folder…", key = "A", needs = "dir", feed = "A" },
  { icon = "󰈈", label = "Reveal in Finder", needs = "path", run = reveal },
  { icon = "󰆍", label = "Open in Integrated Terminal", needs = "dir", run = terminal },
  { icon = "󰍉", label = "Find in Folder", needs = "dir", run = find_in_folder },
  { icon = "󰆐", label = "Cut", key = "x", needs = "file", feed = "x" },
  { icon = "󰆏", label = "Copy", key = "y", needs = "file", feed = "y" },
  { icon = "󰆒", label = "Paste", key = "p", needs = "paste", feed = "p" },
  { icon = "󰌷", label = "Copy Path", needs = "path", run = copy_path },
  { icon = "󰌷", label = "Copy Relative Path", needs = "path", run = copy_relative_path },
  { icon = "󰑕", label = "Rename…", key = "r", needs = "file", feed = "r" },
  { icon = "󰗽", label = "Delete…", key = "d", needs = "file", feed = "d" },
}

local function allowed(item, info)
  if item.needs == "dir" then
    return info.dir ~= nil
  elseif item.needs == "path" then
    return info.path ~= nil
  elseif item.needs == "file" then
    return info.path ~= nil and not info.is_root
  elseif item.needs == "paste" then
    return info.dir ~= nil and clipboard_filled()
  end
  return true
end

-- The floating menu ---------------------------------------------------------

---Open the menu for `info`, anchored at the mouse position.
local function show_menu(info, tree_win)
  local items = vim.tbl_filter(function(item)
    return allowed(item, info)
  end, ACTIONS)
  if #items == 0 then
    notify("No actions for this row", vim.log.levels.WARN)
    return
  end

  -- Fixed width: every shortcut ends up on the same right edge.
  local width = math.min(40, math.max(vim.o.columns - 4, 20))
  local rows = {}
  for _, item in ipairs(items) do
    local left = item.icon .. " " .. item.label
    local pad = math.max(width - vim.fn.strdisplaywidth(left) - 2, 1)
    rows[#rows + 1] = " " .. left .. string.rep(" ", pad) .. (item.key or "")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, rows)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Put the menu at the click, then pull it back inside the screen.
  local mouse = vim.fn.getmousepos()
  local row = math.min(math.max(mouse.screenrow - 1, 0), math.max(vim.o.lines - #items - 3, 0))
  local col = math.min(math.max(mouse.screencol - 1, 0), math.max(vim.o.columns - width - 1, 0))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = #items,
    style = "minimal",
    border = "rounded",
    title = " Actions ",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local function close()
    pcall(vim.api.nvim_win_close, win, true)
  end

  local function run_at(index)
    local item = items[index]
    if not item then
      return
    end
    close()
    -- Let the float finish closing before feeding the tree its key.
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(tree_win) then
        return
      end
      vim.api.nvim_set_current_win(tree_win)
      local run = item.feed and feed_tree_key or item.run
      local ok, err = pcall(run, item.feed or info)
      if not ok then
        notify("Explorer action failed: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end

  -- j/k and the arrows move the cursor natively; normal buffers lack these.
  vim.keymap.set("n", "<CR>", function()
    run_at(vim.api.nvim_win_get_cursor(win)[1])
  end, { buffer = buf, desc = "Run action" })
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Close menu" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Close menu" })

  -- A single click runs the row under the pointer, like a native menu.
  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == win and pos.line >= 1 and pos.line <= #items then
      pcall(vim.api.nvim_win_set_cursor, win, { pos.line, 0 })
      run_at(pos.line)
    else
      close()
    end
  end, { buffer = buf, desc = "Run clicked action" })

  -- Clicking another window (or the border) simply closes the menu.
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })
end

-- Setup ---------------------------------------------------------------------

---Open the menu for the row under the pointer. Public for tests and keymaps.
function M.open()
  local mouse = vim.fn.getmousepos()
  local win = mouse and mouse.winid or 0
  if win == 0 or mouse.line == 0 or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "neo-tree" then
    return
  end

  pcall(vim.api.nvim_set_current_win, win)
  local line = math.min(mouse.line, vim.api.nvim_buf_line_count(buf))
  pcall(vim.api.nvim_win_set_cursor, win, { line, math.max((mouse.column or 1) - 1, 0) })

  local ok, info = pcall(row_info, win)
  if not ok then
    notify("Could not read this row: " .. tostring(info), vim.log.levels.ERROR)
    return
  end
  show_menu(info, win)
end

---Install the right-click mapping in every explorer buffer.
function M.setup()
  local function attach(ev)
    local buf = type(ev) == "table" and ev.buf or ev
    vim.keymap.set("n", "<RightMouse>", M.open, { buffer = buf, desc = "Explorer actions" })
  end

  vim.api.nvim_create_autocmd("FileType", { pattern = "neo-tree", callback = attach })
  -- A tree may already be open when setup runs; attach to it as well.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "neo-tree" then
      attach(buf)
    end
  end
end

return M
