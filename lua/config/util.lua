-- lua/config/util.lua
-- Small shared helpers. Keep this file dependency-free: it is used by
-- keymaps that must work even before plugins have loaded.

local M = {}

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim" })
end

function M.is_neovide()
  return vim.g.neovide ~= nil
end

---Project root: the nearest .git directory, else the current directory.
function M.root()
  local start = vim.api.nvim_buf_get_name(0)
  start = start ~= "" and vim.fs.dirname(start) or vim.uv.cwd()
  local git = vim.fs.find({ ".git" }, { upward = true, path = start })[1]
  if git then
    return vim.fs.dirname(git)
  end
  return vim.uv.cwd()
end

---Yes/no dialog. Returns true when the user picked "Yes".
function M.confirm(msg)
  return vim.fn.confirm(msg, "&Yes\n&No", 2) == 1
end

---Run a shell command in a terminal panel (snacks when available).
---
---Pass `cwd` instead of writing `cd <dir> &&` yourself: project paths with a
---space in them ("~/Dev/My Projects/api") would otherwise split into two
---arguments and the command would run in the wrong directory.
function M.run_task(cmd, opts)
  opts = opts or {}

  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.terminal then
    snacks.terminal.open(cmd, {
      cwd = opts.cwd,
      win = {
        position = opts.position or "bottom",
        height = opts.height or 0.3,
        enter = opts.enter ~= false,
      },
    })
    return
  end

  local prefix = ""
  if opts.cwd then
    prefix = "cd " .. vim.fn.shellescape(opts.cwd) .. " && "
  end
  vim.cmd("botright split")
  vim.cmd("terminal " .. prefix .. cmd)
end

---Save the current buffer, asking for a name if it has none.
function M.save()
  if vim.bo.buftype ~= "" then
    return -- don't try to "save" a terminal or a help buffer
  end

  if vim.api.nvim_buf_get_name(0) == "" then
    vim.ui.input(
      { prompt = "Save as: ", default = vim.uv.cwd() .. "/", completion = "file" },
      function(name)
        if name and name ~= "" then
          vim.cmd("write " .. vim.fn.fnameescape(name))
        end
      end
    )
    return
  end

  vim.cmd("write")
end

---Paste the system clipboard as if typed (works in insert mode).
function M.paste()
  local text = vim.fn.getreg("+")
  if text == "" then
    return
  end
  vim.api.nvim_paste(text, true, -1)
end

---Close the current buffer, offering to save when it has changes.
function M.close_buffer()
  if vim.bo.modified then
    local choice = vim.fn.confirm(
      ("Save changes to %s?"):format(vim.fn.expand("%:t")),
      "&Save\n&Discard\n&Cancel",
      1
    )
    if choice == 1 then
      M.save()
    elseif choice == 3 then
      return
    end
  end
  vim.cmd("bdelete")
end

return M
