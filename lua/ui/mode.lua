-- lua/ui/mode.lua
--
-- The status bar says INSERT or NORMAL with an icon, and clicking it switches
-- between the two. Someone coming from VS Code expects a file they opened to
-- accept typing immediately; beginner mode gives them that, and this module
-- puts the current state (and the way back) where their eye already is.
--
-- Deliberately small: no ModeChanged notification (it would fire on every
-- cursor movement through operator-pending) and no global keymaps (those live
-- in lua/keys/ and the registry).

local M = {}

-- Nerd Font glyphs, matching the icons used elsewhere in the status bar.
local ICON_INSERT = "\u{f040}" -- pencil
local ICON_NORMAL = "\u{f02d}" -- book

-- vim.fn.mode() returns a short code, sometimes with a suffix ("ic" for
-- insert completion, "Rv" for virtual replace). Only the first character
-- decides insert vs normal. Replace is insert-like here: the point of the
-- toggle is "can I type?", and in both modes Esc is the answer.
local function is_insert_mode(mode)
  local first = (mode or vim.fn.mode()):sub(1, 1)
  return first == "i" or first == "R"
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

---Switch between typing and navigating.
---
---From insert/replace: Esc (via :stopinsert) so the cursor stays put but the
---next key is a command again. From anything else: :startinsert. Both are
---wrapped in pcall because a statusline click must never throw: a failed
---toggle is a wasted click, not a broken editor.
function M.toggle()
  local mode = vim.fn.mode()
  local first = mode:sub(1, 1)

  if is_insert_mode(mode) then
    local ok = pcall(vim.cmd.stopinsert)
    if not ok then
      feed("<Esc>")
    end
    return
  end

  if first == "c" then
    -- The command line covers the pill, so this is only reachable from a
    -- mapping. Leave it first; :startinsert is ignored while it is open.
    feed("<Esc>")
    vim.schedule(M.toggle)
    return
  end

  local ok = pcall(vim.cmd.startinsert)
  if not ok then
    feed("i")
  end
end

---The lualine component for `lualine_a`.
---
---Returned as a table (not a plain function) so lualine can attach the click
---handler. The reader runs on every redraw, so the label is always live.
function M.pill()
  return {
    function()
      if is_insert_mode() then
        return ICON_INSERT .. " INSERT"
      end
      return ICON_NORMAL .. " NORMAL"
    end,
    on_click = function()
      M.toggle()
    end,
    padding = { left = 1, right = 1 },
  }
end

-- Sidebars, dashboards and pickers are normal buffers with a filetype but no
-- file name; typing into them is never what the user meant. Their filetypes
-- are listed so the check does not depend on buffer names being empty.
local SKIP_FILETYPES = {
  ["snacks_dashboard"] = true,
  ["snacks_picker_input"] = true,
  ["snacks_picker_list"] = true,
  ["snacks_picker_preview"] = true,
  ["neo-tree"] = true,
  ["Trouble"] = true,
}

local function should_auto_insert(buf, name)
  if not vim.g.beginner_mode then
    return false
  end
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  if name == "" then
    return false
  end
  if SKIP_FILETYPES[vim.bo[buf].filetype] then
    return false
  end

  -- A syntax-highlighted 20 MB log would freeze the editor; those files are
  -- for reading, not for the auto-insert convenience. getfsize returns -1 for
  -- a file that does not exist yet (BufNewFile), which is fine.
  local size = vim.fn.getfsize(name)
  if size > 2 * 1024 * 1024 then
    return false
  end

  return true
end

local function schedule_insert(buf)
  -- BufReadPost fires while the buffer is still being set up; Entering insert
  -- immediately would race the filetype/LSP work. One tick later the window
  -- already shows the file.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    -- Opening a file from a picker can leave focus in the picker (preview
    -- windows, for instance). Only act when the file is what we are looking at.
    if vim.api.nvim_get_current_buf() ~= buf then
      return
    end
    -- The user may have flipped to Vim mode in the meantime.
    if not vim.g.beginner_mode then
      return
    end
    if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "n" then
      return
    end
    pcall(vim.cmd.startinsert)
  end)
end

---Install the auto-insert autocmds. Pass `opts.auto_insert = false` to keep
---the pill but never enter insert on open.
function M.setup(opts)
  opts = opts or {}

  local group = vim.api.nvim_create_augroup("UserMode", { clear = true })
  if opts.auto_insert == false then
    return
  end

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    callback = function(ev)
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if not should_auto_insert(ev.buf, name) then
        return
      end
      schedule_insert(ev.buf)
    end,
  })
end

return M
