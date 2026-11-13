-- lua/ui/mouse.lua
--
-- Snacks pickers, trouble and the quickfix list only bind <2-LeftMouse>
-- (double click) to "open". A single click moves the selection, so the list
-- looks dead to anyone coming from VS Code, where one click opens the row.
--
-- This module makes a single left click activate the row under the pointer in
-- every list that is already mouse-aware. It is buffer-local: ordinary text
-- buffers keep the normal "click to place the cursor" behaviour.

local M = {}

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

---Move the cursor to the clicked row, then run the list's own "open" key.
---
---We set the cursor explicitly instead of replaying <LeftMouse>: feedkeys
---queues the mouse event, and the follow-up <CR> could run before it is
---processed (i.e. on the previously selected row).
local function click_then(key)
  local pos = vim.fn.getmousepos()
  local win = vim.api.nvim_get_current_win()

  if not pos or pos.winid ~= win or type(pos.line) ~= "number" or pos.line <= 0 then
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local line = math.min(pos.line, vim.api.nvim_buf_line_count(buf))
  pcall(vim.api.nvim_win_set_cursor, win, { line, 0 })

  -- One tick: the list updates its selection from CursorMoved, then we open.
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    if vim.api.nvim_win_get_buf(win) ~= buf or vim.api.nvim_get_current_win() ~= win then
      return
    end
    feed(key)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserMouse", { clear = true }),
    pattern = { "snacks_picker_list", "trouble", "qf" },
    callback = function(ev)
      vim.keymap.set("n", "<LeftMouse>", function()
        click_then("<CR>")
      end, { buffer = ev.buf, nowait = true, desc = "Open the clicked row" })
    end,
  })
end

return M
