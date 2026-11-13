-- lua/ui/explorer_panel.lua
--
-- VS Code's Explorer header has a "..." menu: Show Open Editors, Close All,
-- Close Saved, Preview Editors, Configure Editors. Neo-tree has the data for
-- all of it but no menu, and its "buffers" source (the live list of open
-- editors) is never surfaced.
--
-- This module draws that menu at the mouse and switches the sidebar between
-- neo-tree's own sources, so nothing here is a copy of the buffer list: it is
-- neo-tree's view, kept live by neo-tree. The winbar button and the commands
-- live elsewhere and only call M.menu() / M.open_editors() / M.show_files(),
-- so this file has no global keymaps and no autocommands outside its menu.

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Explorer" })
end

---Run neo-tree's own command, because its sources are the only truthful view
---of "open editors" and of the file tree. Guarded: a missing plugin must only
---warn, and a broken source must only notify.
local function neo_tree(command)
  if vim.fn.exists(":Neotree") ~= 2 then
    notify("neo-tree is not installed yet (run :Lazy)", vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(vim.cmd, command)
  if not ok then
    notify("neo-tree failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Sidebar sources ------------------------------------------------------------

---Show the "open editors" list: neo-tree's buffers source, in the same sidebar
---slot as the file tree. Toggle, so calling it twice hides the sidebar.
function M.open_editors()
  neo_tree("Neotree buffers toggle left")
end

---Switch the shared sidebar back to the file tree.
function M.show_files()
  neo_tree("Neotree filesystem toggle left")
end

-- Buffers --------------------------------------------------------------------

-- Neo-tree itself must survive every close action; the rest are windows that
-- are not editors, so closing them would break a panel instead of a document.
local PROTECTED_FILETYPES = {
  ["neo-tree"] = true,
  terminal = true,
  help = true,
  dashboard = true,
  ["snacks_dashboard"] = true,
  ["snacks_terminal"] = true,
}

local function is_protected(buf)
  if PROTECTED_FILETYPES[vim.bo[buf].filetype] then
    return true
  end
  local buftype = vim.bo[buf].buftype
  return buftype == "terminal"
    or buftype == "help"
    or buftype == "nofile"
    or buftype == "quickfix"
    or buftype == "prompt"
end

---Listed editor buffers, optionally only the unmodified ones.
local function closeable(saved_only)
  local out = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local listed = vim.bo[buf].buflisted
    local modified = vim.bo[buf].modified
    if listed and not is_protected(buf) and not (saved_only and modified) then
      out[#out + 1] = buf
    end
  end
  return out
end

---Ask what to do with one modified buffer. Returns true when it may be closed.
local function resolve_modified(buf)
  local name = vim.fn.fnamemodify(vim.fn.bufname(buf), ":~:.")
  if name == "" then
    name = "this buffer"
  end
  local choice = vim.fn.confirm(("Save changes to %s?"):format(name), "&Save\n&Discard\n&Cancel", 3)
  if choice == 1 then
    local saved, err = pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("write")
    end)
    if not saved then
      notify("Could not save " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
      return false
    end
    return true
  end
  return choice == 2
end

---The snacks buffer deleter, when it is installed and enabled.
local function bufdelete()
  local ok, snacks = pcall(require, "snacks")
  local module = ok and type(snacks) == "table" and snacks.bufdelete
  return type(module) == "table" and module or nil
end

---Delete one buffer. Snacks keeps the window layout intact and asks about
---modified buffers; without it, `:bdelete` on exactly this buffer, after the
---same question (a plain `:bufdo bd` would walk into the explorer buffer and
---break its own iteration).
local function delete_one(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local module = bufdelete()
  if module then
    local deleted, err = pcall(module, buf)
    if deleted then
      return
    end
    notify("Could not close " .. vim.fn.bufname(buf) .. ": " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  if vim.bo[buf].modified and not resolve_modified(buf) then
    return
  end
  local deleted, err = pcall(vim.api.nvim_buf_delete, buf, { force = false })
  if not deleted then
    notify("Could not close " .. vim.fn.bufname(buf) .. ": " .. tostring(err), vim.log.levels.ERROR)
  end
end

---Delete exactly `targets`, never touching another buffer.
local function delete_buffers(targets)
  for _, buf in ipairs(targets) do
    delete_one(buf)
  end
end

---True when every listed buffer is one of `targets`, i.e. no panel or terminal
---is listed. Only then may `Snacks.bufdelete.all()` be used: its `all` ignores
---a custom filter, so it would otherwise close protected buffers as well.
local function only_listed(targets)
  local allowed = {}
  for _, buf in ipairs(targets) do
    allowed[buf] = true
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and not allowed[buf] then
      return false
    end
  end
  return true
end

---Close every open editor, leaving the explorer itself open.
function M.close_all()
  local targets = closeable(false)
  if #targets == 0 then
    notify("No editors are open")
    return
  end

  local dirty = 0
  for _, buf in ipairs(targets) do
    if vim.bo[buf].modified then
      dirty = dirty + 1
    end
  end
  local prompt = ("Close all %d editor%s?"):format(#targets, #targets == 1 and "" or "s")
  if dirty > 0 then
    prompt = ("Close all %d editor%s? %d unsaved."):format(
      #targets,
      #targets == 1 and "" or "s",
      dirty
    )
  end
  if vim.fn.confirm(prompt, "&Close\n&Cancel", 2) ~= 1 then
    return
  end

  -- `Snacks.bufdelete.all()` is the layout-preserving "close every editor"
  -- when the listed buffers really are all editors. Protected buffers (the
  -- explorer, terminals, dashboards) force the explicit list instead.
  local module = bufdelete()
  if module and type(module.all) == "function" and only_listed(targets) then
    local closed, err = pcall(module.all)
    if closed then
      return
    end
    notify("Closing editors failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  delete_buffers(targets)
end

---Close only the editors without unsaved changes.
function M.close_saved()
  local targets = closeable(true)
  if #targets == 0 then
    notify("No saved editors to close")
    return
  end
  local prompt = ("Close %d saved editor%s?"):format(#targets, #targets == 1 and "" or "s")
  if vim.fn.confirm(prompt, "&Close\n&Cancel", 2) ~= 1 then
    return
  end
  delete_buffers(targets)
end

-- Preview editors ------------------------------------------------------------

---Neo-tree has no preview-editor concept (VS Code's italic tab that is replaced
---by the next single click). The flag is kept so a future integration can read
---it, but nothing is pretended here.
M.preview_editors = false

function M.toggle_preview()
  M.preview_editors = not M.preview_editors
  notify("Preview editors are a VS Code concept; neo-tree opens files normally.")
end

-- Configure the explorer -----------------------------------------------------

---Open the neo-tree spec in a new tab, with the cursor on it.
function M.configure()
  local path = vim.fn.stdpath("config") .. "/lua/plugins/nav.lua"
  if vim.fn.filereadable(path) == 0 then
    notify("Could not find the explorer config: " .. path, vim.log.levels.ERROR)
    return
  end
  local opened, err = pcall(vim.cmd, "tabnew " .. vim.fn.fnameescape(path))
  if not opened then
    notify("Could not open the explorer config: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  pcall(vim.fn.search, "neo-tree", "w")
end

-- The floating menu ----------------------------------------------------------

-- Font Awesome glyphs, part of Nerd Fonts like the winbar icons.
local ICON = {
  editors = "\u{f0c5}", -- stacked documents: the open editors list
  tree = "\u{f07b}", -- folder: the file tree
  close_all = "\u{f00d}", -- cross
  close_saved = "\u{f0c7}", -- floppy disk
  preview = "\u{f06e}", -- eye
  gear = "\u{f013}", -- gear
}

---The menu rows. Built per call so the preview hint shows the current state.
local function entries()
  return {
    { icon = ICON.editors, label = "Show Open Editors", hint = "buffers", run = M.open_editors },
    { icon = ICON.tree, label = "Show File Tree", hint = "files", run = M.show_files },
    { icon = ICON.close_all, label = "Close All Editors", hint = "all", run = M.close_all },
    { icon = ICON.close_saved, label = "Close Saved Editors", hint = "saved", run = M.close_saved },
    {
      icon = ICON.preview,
      label = "Toggle Preview Editors",
      hint = M.preview_editors and "on" or "off",
      run = M.toggle_preview,
    },
    { icon = ICON.gear, label = "Configure Explorer", hint = "config", run = M.configure },
  }
end

---Where to put a floating window of `width`x`height`: at the mouse, or centred
---when there is no usable mouse position (headless, or a keyboard invocation).
local function anchor(width, height)
  local mouse = vim.fn.getmousepos()
  local row, col
  if type(mouse) == "table" and (mouse.screenrow or 0) > 0 and (mouse.screencol or 0) > 0 then
    row = mouse.screenrow - 1
    col = mouse.screencol - 1
  else
    row = math.floor((vim.o.lines - height) / 2)
    col = math.floor((vim.o.columns - width) / 2)
  end
  row = math.min(math.max(row, 0), math.max(vim.o.lines - height - 3, 0))
  col = math.min(math.max(col, 0), math.max(vim.o.columns - width - 2, 0))
  return row, col
end

---Draw the Explorer menu. Public: the winbar button and the command call this.
function M.menu()
  local items = entries()

  -- Fixed width: every hint ends up on the same right edge, like a native menu.
  local width = 0
  for _, item in ipairs(items) do
    local left = vim.fn.strdisplaywidth(" " .. item.icon .. " " .. item.label)
    width = math.max(width, left + #item.hint + 3)
  end
  width = math.min(math.max(width, 30), math.max(vim.o.columns - 4, 20))

  local rows, hints = {}, {}
  for i, item in ipairs(items) do
    local left = " " .. item.icon .. " " .. item.label
    local pad = math.max(width - vim.fn.strdisplaywidth(left) - #item.hint - 1, 1)
    rows[i] = left .. string.rep(" ", pad) .. item.hint .. " "
    -- Byte offsets for the hint highlight (`pad` is spaces, so 1:1 here).
    hints[i] = { line = i - 1, start = #left + pad, stop = #left + pad + #item.hint }
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, rows)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local row, col = anchor(width, #items)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = #items,
    style = "minimal",
    border = "rounded",
    title = " Explorer ",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  -- Standard groups, so the menu follows the colorscheme.
  for i, item in ipairs(items) do
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", i - 1, 1, 1 + #item.icon)
    local hint = hints[i]
    vim.api.nvim_buf_add_highlight(buf, -1, "Comment", hint.line, hint.start, hint.stop)
  end

  local function close()
    pcall(vim.api.nvim_win_close, win, true)
  end

  local function run_at(index)
    local item = items[index]
    if not item then
      return
    end
    close()
    -- Deferred: a menu action may toggle the sidebar, which changes windows and
    -- must not happen in the middle of the mouse/key event.
    vim.schedule(function()
      local ok, err = pcall(item.run)
      if not ok then
        notify(item.label .. " failed: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end

  -- j/k and the arrows move the cursor natively; normal windows lack these.
  vim.keymap.set("n", "<CR>", function()
    run_at(vim.api.nvim_win_get_cursor(win)[1])
  end, { buffer = buf, desc = "Run explorer action" })
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Close the explorer menu" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Close the explorer menu" })

  -- A single click runs the row under the pointer; anywhere else closes.
  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == win and pos.line >= 1 and pos.line <= #items then
      pcall(vim.api.nvim_win_set_cursor, win, { pos.line, 0 })
      run_at(pos.line)
    else
      close()
    end
  end, { buffer = buf, desc = "Run the clicked explorer action" })

  -- Clicking another window (or the border) closes the menu.
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })
end

-- Setup ----------------------------------------------------------------------

---Nothing to install: the menu has no global keymaps and no autocommands
---(its WinLeave is buffer-local), and the winbar button/commands call the
---functions above directly. Kept so every ui/ module is set up the same way.
function M.setup() end

return M
