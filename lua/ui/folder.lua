-- lua/ui/folder.lua
--
-- "Open Folder", the way VS Code does it: a clickable directory browser built
-- on the snacks picker.
--
-- Why a browser and not a prompt: asking someone to *type* a path from memory
-- is the least forgiving part of the old flow. Here the folder you are in is
-- always row one, every subfolder is a row you can click, and typing a path is
-- still possible for people who prefer the keyboard.
--
--   M.pick()  -> the browser (falls back to M.input() when snacks is missing)
--   M.input() -> one prompt with real Tab completion for directories
--
-- Both entry points are defensive: a missing snacks, a broken picker or an
-- on_choose callback that raises must end in a message, never in an error. The
-- dashboard calls these functions directly, so throwing would take the start
-- screen with it.

local M = {}

-- ---------------------------------------------------------------------------
-- Small helpers (paths, messages)
-- ---------------------------------------------------------------------------

---Tell the user something without ever raising. The dashboard is the caller,
---so a notification failure may not become a dashboard failure.
---@param msg string
---@param level? number
local function notify(msg, level)
  pcall(vim.notify, msg, level or vim.log.levels.INFO, { title = "Open folder" })
end

---A short, readable form of a directory: "~/Dev", not "/Users/me/Dev".
---@param path string
---@return string
local function display(path)
  local ok, short = pcall(vim.fn.fnamemodify, path, ":~")
  if ok and type(short) == "string" and short ~= "" then
    return short
  end
  return tostring(path)
end

---Resolve what the user typed (or what a caller passed) to an absolute
---directory, or nil when it points at something else.
---
---`vim.fs.normalize` expands "~" and "$VARS" but keeps relative paths relative,
---and `fnamemodify(":p")` makes a path absolute but does not expand "$VARS".
---Running both, in that order, is what accepts every form people actually type.
---@param path? string
---@return string?
local function resolve_dir(path)
  if type(path) ~= "string" then
    return nil
  end
  path = vim.trim(path)
  if path == "" then
    return nil
  end
  -- Paths copied from Finder/Explorer often arrive wrapped in quotes.
  path = path:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")

  local ok, expanded = pcall(vim.fs.normalize, path)
  if not ok or type(expanded) ~= "string" or expanded == "" then
    return nil
  end
  local abs_ok, absolute = pcall(vim.fn.fnamemodify, expanded, ":p")
  if not abs_ok or type(absolute) ~= "string" or absolute == "" then
    return nil
  end
  local norm_ok, dir = pcall(vim.fs.normalize, absolute)
  if not norm_ok or type(dir) ~= "string" or dir == "" then
    return nil
  end
  if vim.fn.isdirectory(dir) == 1 then
    return dir
  end
  return nil
end

---The directory above `dir`, or nil at the filesystem root.
---@param dir string
---@return string?
local function parent_dir(dir)
  local ok, parent = pcall(vim.fs.dirname, dir)
  if ok and type(parent) == "string" and parent ~= "" and parent ~= dir then
    return parent
  end
  return nil
end

---Does the typed text look like a path rather than a folder-name filter?
---
---This is what makes "type a path" work without a second mode: as soon as the
---text starts like a path, the picker stops filtering names and offers to open
---that exact folder instead.
---@param text string
---@return boolean
local function looks_like_path(text)
  return text:sub(1, 1) == "~"
    or text:sub(1, 1) == "/"
    or text == "."
    or text == ".."
    or text:sub(1, 2) == "./"
    or text:sub(1, 3) == "../"
    or text:match("^%a:[/\\]") ~= nil -- Windows drive letters
end

---Absolute paths of the directories directly inside `dir`, sorted the way a
---human reads a list: case-insensitively, hidden folders included, files
---ignored (this picker only ever chooses folders).
---
---Exposed because it is the one piece of this module that can be exercised
---without a UI: `require("ui.folder").dirs("/tmp")`.
---@param dir string
---@return string[]
function M.dirs(dir)
  local root = resolve_dir(dir)
  if not root then
    return {}
  end

  local found = {}
  -- vim.fs.dir throws on an unreadable folder; a browser that cannot show a
  -- folder should look empty instead of breaking the dashboard.
  local ok = pcall(function()
    for name, kind in vim.fs.dir(root) do
      local path = vim.fs.joinpath(root, name)
      -- Symlinks are reported as "link" even when they point at a directory,
      -- so ask the filesystem rather than trusting `kind` alone.
      if kind == "directory" or vim.fn.isdirectory(path) == 1 then
        found[#found + 1] = path
      end
    end
  end)
  if not ok then
    return {}
  end

  table.sort(found, function(a, b)
    local la, lb = a:lower(), b:lower()
    if la == lb then
      return a < b
    end
    return la < lb
  end)
  return found
end

---The snacks picker API, or nil when snacks is missing or not usable.
---@return table?
local function picker_api()
  local ok, snacks = pcall(require, "snacks")
  if not ok or type(snacks) ~= "table" then
    return nil
  end
  local api = snacks.picker
  if type(api) == "table" and type(api.pick) == "function" then
    return api
  end
  return nil
end

---The typed filter text, as the finder receives it. With `live = true` snacks
---stores the input in `filter.search`; anything else is a defensive blank.
---@param ctx table
---@return string
local function typed_text(ctx)
  local ok, text = pcall(function()
    return ctx.filter.search
  end)
  if ok and type(text) == "string" then
    return vim.trim(text)
  end
  return ""
end

---The folder the picker is currently browsing. Derived from the picker itself
---rather than a closure so a stale action on a reused picker cannot create a
---folder somewhere else.
---@param picker table
---@param fallback string
---@return string
local function picker_dir(picker, fallback)
  local ok, dir = pcall(function()
    return picker:cwd()
  end)
  if ok then
    local resolved = resolve_dir(dir)
    if resolved then
      return resolved
    end
  end
  return fallback
end

---The folder icon snacks uses, so this picker looks like the other ones.
---@param picker table
---@return string
local function folder_icon(picker)
  local ok, icon = pcall(function()
    return picker.opts.icons.files.dir
  end)
  if ok and type(icon) == "string" and icon ~= "" then
    return icon
  end
  return "󰉋 "
end

-- ---------------------------------------------------------------------------
-- Choosing a folder
-- ---------------------------------------------------------------------------

---Hand `dir` to the caller, or announce it when there is nobody to hand it to.
---@param opts table
---@param dir string
local function choose(opts, dir)
  local target = resolve_dir(dir)
  if not target then
    notify(("Not a folder: %s"):format(display(dir)), vim.log.levels.ERROR)
    return
  end

  local callback = opts.on_choose
  if type(callback) ~= "function" then
    -- No callback is a valid call (a keymap without integration yet). Saying
    -- the folder out loud is more useful than silently doing nothing.
    notify("Open folder: " .. display(target))
    return
  end

  local ok, err = pcall(callback, target)
  if not ok then
    notify("Could not open folder: " .. tostring(err), vim.log.levels.ERROR)
  end
end

---Ask for a folder name and create it inside `dir`.
---
---Only one path segment is accepted: "a/b" would create folders somewhere the
---browser is not showing, which is exactly the kind of surprise this picker is
---meant to remove.
---@param dir string
---@return string? path the created (or already existing) folder
local function make_folder(dir)
  local ok, name = pcall(vim.fn.input, {
    prompt = ("New folder in %s: "):format(display(dir)),
  })
  if not ok or type(name) ~= "string" then
    return nil
  end

  name = vim.trim(name)
  if name == "" then
    return nil -- cancelled
  end
  if name == "." or name == ".." or name:find("[/\\]") or name:find("%z") then
    notify("Use a plain folder name, without slashes: " .. name, vim.log.levels.WARN)
    return nil
  end

  local path = vim.fs.joinpath(dir, name)
  if vim.fn.isdirectory(path) == 1 then
    notify("Folder already exists: " .. display(path), vim.log.levels.WARN)
    return path
  end

  local made = pcall(vim.fn.mkdir, path, "p")
  if not made or vim.fn.isdirectory(path) == 0 then
    notify("Could not create " .. display(path), vim.log.levels.ERROR)
    return nil
  end

  notify("Created " .. display(path))
  return path
end

-- ---------------------------------------------------------------------------
-- The picker
-- ---------------------------------------------------------------------------

---@param dir string
---@param typed string
---@return table[]
local function browser_items(dir, typed)
  -- Items store their target in `path`, not `dir`: snacks gives `item.dir` the
  -- meaning "this item is a directory" (a boolean), and a picker field that
  -- silently changes type is a bug waiting for the next picker hook.
  --
  -- A path the user typed wins over the tree: show exactly one actionable row
  -- so Enter (or a click) opens it without further navigation.
  if looks_like_path(typed) then
    local target = resolve_dir(typed)
    if target then
      return { { kind = "typed", path = target, text = "Open: " .. display(target) } }
    end
    -- Still being typed (or simply wrong): an empty list is less confusing
    -- than showing folders that do not relate to the text.
    return {}
  end

  local items = {
    { kind = "current", path = dir, text = "Open this folder: " .. display(dir) },
  }

  local parent = parent_dir(dir)
  if parent then
    items[#items + 1] = {
      kind = "parent",
      path = parent,
      label = "../",
      text = "../",
    }
  end

  local needle = typed:lower()
  for _, path in ipairs(M.dirs(dir)) do
    local name = vim.fs.basename(path)
    if needle == "" or name:lower():find(needle, 1, true) then
      items[#items + 1] = {
        kind = "folder",
        path = path,
        label = name .. "/",
        text = name .. "/",
      }
    end
  end

  return items
end

---The row label for one item. Rows are built from plain segments rather than
---a string so the icon, the name and the folder highlight stay separate.
---@param item table
---@param picker table
---@return snacks.picker.Highlight[]
local function format_item(item, picker)
  if item.kind == "current" then
    return {
      { "✓ ", "SnacksPickerToggle" },
      { "Open this folder: ", "SnacksPickerComment" },
      { display(item.path), "SnacksPickerDirectory" },
    }
  elseif item.kind == "typed" then
    return {
      { "Open: ", "SnacksPickerComment" },
      { display(item.path), "SnacksPickerDirectory" },
    }
  end
  return {
    { folder_icon(picker), "SnacksPickerDir" },
    { item.label or "", "SnacksPickerDirectory" },
  }
end

---Open the browser at `dir`. Navigation closes this picker and calls this
---function again: a fresh picker is the only way to get both a clean filter
---box and a title that names the folder you are now looking at.
---@param opts table
---@param dir string
---@return boolean opened
---@return string? err
local function open(opts, dir)
  local api = picker_api()
  if not api then
    return false
  end

  local base_title = type(opts.title) == "string" and opts.title ~= "" and opts.title
    or "Open folder"

  local function open_after(picker, fn)
    -- A double click can deliver two confirms for the same picker. Only the
    -- first may close-and-reopen, or two browsers end up stacked.
    if type(picker) == "table" and picker.closed then
      return
    end
    pcall(function()
      picker:close()
    end)
    vim.schedule(function()
      local ok, err = pcall(fn)
      if not ok then
        notify("Folder browser error: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end

  local actions = {
    folder_new = {
      desc = "New folder",
      action = function(picker)
        local at = picker_dir(picker, dir)
        -- Close first: the prompt must not be opened from insert mode inside a
        -- prompt buffer, and a refresh is just reopening at the same folder.
        open_after(picker, function()
          make_folder(at)
          open(opts, at)
        end)
      end,
    },
    folder_path = {
      desc = "Type a path",
      action = function(picker)
        local at = picker_dir(picker, dir)
        open_after(picker, function()
          M.input({ start = at, on_choose = opts.on_choose })
        end)
      end,
    },
  }

  local ok, err = pcall(api.pick, {
    title = ("%s — %s"):format(base_title, display(dir)),
    -- `live` is what lets the finder see the typed text on every keystroke.
    -- Without it snacks only uses the text for client-side matching, and the
    -- finder could never notice that the user typed a path.
    live = true,
    cwd = dir,
    -- Nothing to preview in a folder browser: an empty pane would just steal
    -- half the width on wide screens.
    layout = { hidden = { "preview" } },
    actions = actions,
    format = format_item,
    finder = function(_, ctx)
      local built, items = pcall(browser_items, dir, typed_text(ctx))
      if not built then
        return {}
      end
      return items
    end,
    confirm = function(picker, item)
      if type(item) ~= "table" then
        return
      end
      if item.kind == "folder" or item.kind == "parent" then
        open_after(picker, function()
          open(opts, item.path)
        end)
      elseif item.kind == "current" or item.kind == "typed" then
        open_after(picker, function()
          choose(opts, item.path)
        end)
      end
    end,
    win = {
      input = {
        keys = {
          -- `a` is a normal-mode key: in insert mode it must keep typing "a"
          -- into the filter (that is how a folder name is typed).
          a = { "folder_new", mode = "n" },
          -- Ctrl-L is available in both modes: typing a whole path is a
          -- keyboard-only affair anyway.
          ["<C-l>"] = { "folder_path", mode = { "i", "n" } },
          -- Every "open" gesture must go through our confirm: the default
          -- jump would try to load a *directory* as a file and assert.
          ["<S-CR>"] = { "confirm", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          a = { "folder_new", mode = "n" },
          ["<C-l>"] = { "folder_path", mode = "n" },
          ["<S-CR>"] = { "confirm", mode = { "n", "x" } },
          ["<C-s>"] = { "confirm", mode = "n" },
          ["<C-v>"] = { "confirm", mode = "n" },
          ["<C-t>"] = { "confirm", mode = "n" },
        },
      },
    },
  })

  if not ok then
    return false, err
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Open the clickable folder browser.
---
---Typing "~", "/", "./" or "../" in the filter offers that exact folder as the
---first row; typing plain text filters the list of subfolders.
---@param opts? { start?: string, title?: string, on_choose?: fun(dir: string) }
function M.pick(opts)
  opts = type(opts) == "table" and opts or {}

  if not picker_api() then
    -- No snacks is not an error: the prompt still works everywhere.
    return M.input(opts)
  end

  local start = resolve_dir(opts.start)
    or resolve_dir(vim.fn.getcwd())
    or resolve_dir(vim.uv.os_homedir())
  if not start then
    notify("There is no folder to show", vim.log.levels.ERROR)
    return
  end

  local ok, opened, err = pcall(open, opts, start)
  if not ok then
    notify("Folder browser failed: " .. tostring(opened), vim.log.levels.WARN)
    return M.input(opts)
  end
  if not opened then
    if err then
      notify("Folder browser failed: " .. tostring(err), vim.log.levels.WARN)
    end
    return M.input(opts)
  end
end

---Ask for a folder in one prompt, with real Tab completion.
---
---This is the secondary path for people who know where they are going. It uses
---the dictionary form of vim.fn.input on purpose: that is the prompt that has
---`completion = "dir"`; the vim.ui.input wrapper used by this config does not.
---@param opts? { start?: string, on_choose?: fun(dir: string) }
function M.input(opts)
  opts = type(opts) == "table" and opts or {}

  local start = resolve_dir(opts.start) or resolve_dir(vim.fn.getcwd())
  local default = start and (start:gsub("[/\\]?$", "/")) or ""

  local ok, answer = pcall(vim.fn.input, {
    prompt = "Open folder: ",
    default = default,
    completion = "dir",
  })
  if not ok or type(answer) ~= "string" then
    notify("Could not ask for a folder: " .. tostring(answer), vim.log.levels.ERROR)
    return
  end

  answer = vim.trim(answer)
  if answer == "" then
    return -- cancelled
  end

  local dir = resolve_dir(answer)
  if not dir then
    notify("Not a folder: " .. answer, vim.log.levels.ERROR)
    return
  end

  choose(opts, dir)
end

return M
