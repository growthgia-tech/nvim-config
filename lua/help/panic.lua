-- lua/help/panic.lua
--
-- :Panic — the "I have no idea what is happening" card.
--
-- A beginner's real problem is never "I need a command reference", it is "the
-- screen is in a weird state and I do not know how to get out". So this is a
-- short, calm, centred card with the six things that actually fix 95% of
-- those moments.

local M = {}

local LINES = {
  "",
  "   YOU ARE NOT STUCK. HERE IS HOW TO GET OUT.",
  "",
  "   Esc                 leave whatever mode you are in",
  "                       (in the AI panel, press it twice)",
  "",
  "   u                   undo the last change",
  "   Ctrl-r              redo it",
  "",
  "   :w                  save the file",
  "   :q                  close this window",
  "   :q!                 close WITHOUT saving",
  "   :wq                 save and close",
  "",
  "   Cmd+S / Cmd+W       save / close (in Neovide)",
  "",
  "   :messages           what was that red error?",
  "   :Reload             reload the config without restarting",
  "   :Health             run the full diagnostic",
  "   :Lazy               plugin manager      :Mason  language tools",
  "",
  "   If all else fails: Cmd+Q. Nothing is lost — undo history is saved",
  "   on disk and comes back when you reopen the file.",
  "",
  "                    press q or Esc to close this card",
  "",
}

function M.open()
  local width = 0
  for _, line in ipairs(LINES) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, math.max(vim.o.columns - 6, 40))
  local height = #LINES

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, LINES)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = "minimal",
    border = "rounded",
    title = " Panic ",
    title_pos = "center",
  })

  -- Any of these closes the card. It is a card, not a mode: no way to get
  -- trapped inside it.
  for _, lhs in ipairs({ "q", "Q", "<Esc>", "<CR>", "<Space>" }) do
    vim.keymap.set("n", lhs, function()
      pcall(vim.api.nvim_win_close, win, true)
    end, { buffer = buf, nowait = true })
  end

  return win
end

return M
