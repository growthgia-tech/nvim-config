-- lua/help/tutorial.lua
--
-- Opens docs/TUTORIAL.md in a read-only tab. The tutorial is a real Markdown
-- file in the repository, so you can also read it on GitHub or in any editor,
-- and there is only one copy of it.

local M = {}

local function config_root()
  -- The config directory is on the runtime path as "~/.config/nvim".
  for _, dir in ipairs(vim.api.nvim_list_runtime_paths()) do
    if vim.fn.filereadable(dir .. "/docs/TUTORIAL.md") == 1 then
      return dir
    end
  end
  return vim.fn.stdpath("config")
end

function M.open()
  local path = config_root() .. "/docs/TUTORIAL.md"

  if vim.fn.filereadable(path) == 0 then
    vim.notify(
      "Tutorial not found at " .. path .. " (reinstall the config to restore it)",
      vim.log.levels.WARN
    )
    return
  end

  vim.cmd("tabnew " .. vim.fn.fnameescape(path))
  vim.bo.modifiable = false
  vim.bo.readonly = true
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.number = false
  vim.wo.signcolumn = "no"
  vim.bo.filetype = "markdown"

  -- The tutorial is long, so start at the top and make it easy to leave.
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, { buffer = 0, desc = "Close the tutorial" })
end

return M
