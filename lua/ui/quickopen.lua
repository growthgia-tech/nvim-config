-- lua/ui/quickopen.lua
--
-- VS Code's Quick Open turns into the command palette the moment you type ">"
-- at the start of the query. snacks' file picker has no such mode, so this
-- module watches the picker's input and swaps sources.
--
-- The palette already supports ">" itself (see lua/keys/nav.lua): command rows
-- carry an invisible ">" prefix, so both entry points behave the same way.

local M = {}

---The open command palette, if there is one.
---@return table?
local function palette()
  local ok, pickers = pcall(function()
    return require("snacks").picker.get()
  end)
  if not ok then
    return nil
  end
  for _, p in ipairs(pickers) do
    if p.opts and p.opts.title == "Command Palette" then
      return p
    end
  end
end

---Put `query` in the palette's input and let its normal filter run.
---@param query string
---@param tries? number
local function seed(query, tries)
  tries = tries or 0
  if query == "" then
    return
  end

  local p = palette()
  local buf = p and p.input and p.input.win and p.input.win.buf
  if type(buf) ~= "number" then
    if tries < 50 then
      vim.defer_fn(function()
        seed(query, tries + 1)
      end, 20)
    end
    return
  end

  -- Keep the ">" so the palette stays in command-only mode.
  pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, { ">" .. query })
  pcall(vim.api.nvim_exec_autocmds, "TextChangedI", { buffer = buf })
end

---Watch one files/recent picker. Safe to call on anything.
---@param picker table?
---@param tries? number retry counter while the picker creates its window
function M.watch(picker, tries)
  tries = tries or 0
  if type(picker) ~= "table" or not picker.input or not picker.input.win then
    return
  end
  local buf = picker.input.win.buf
  if type(buf) ~= "number" then
    -- Snacks creates the input window a tick after pick() returns.
    if tries < 50 then
      vim.defer_fn(function()
        M.watch(picker, tries + 1)
      end, 20)
    end
    return
  end
  local fired = false

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = buf,
    callback = function(ev)
      if fired then
        return
      end
      local text = vim.api.nvim_buf_get_lines(ev.buf, 0, 1, false)[1] or ""
      if text:sub(1, 1) ~= ">" then
        return
      end
      fired = true

      local query = vim.trim(text:sub(2))
      pcall(function()
        picker:close()
      end)
      vim.schedule(function()
        if pcall(vim.cmd, "Palette") then
          seed(query)
        end
      end)
    end,
  })
end

return M
