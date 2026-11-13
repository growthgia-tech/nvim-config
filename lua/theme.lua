-- lua/theme.lua
--
-- The user's colourscheme choice must survive a restart, like a real editor.
-- This module is deliberately tiny and dependency-free:
--
--   theme.pick()  -> open a picker (snacks if possible, else a plain menu)
--   theme.load()  -> re-apply the saved theme at startup (safe if missing)
--
-- The choice is stored in a plain text file inside Neovim's "state" folder,
-- so it is not overwritten when plugins are reinstalled.

local M = {}

-- Themes that :Theme offers. All three are installed by lua/plugins/ui.lua.
M.available = { "tokyonight", "catppuccin", "vscode" }

M.default = "vscode"

local attached = false

---Path of the small file that remembers the theme.
local function state_file()
  return vim.fn.stdpath("state") .. "/theme.txt"
end

---Remember a theme name on disk. Failures are silent on purpose: a read-only
---state folder must not stop the editor from working.
function M.save(name)
  if type(name) ~= "string" or name == "" then
    return
  end
  pcall(vim.fn.writefile, { name }, state_file())
end

---Read the remembered theme name, or nil when nothing was saved yet.
function M.read()
  local ok, lines = pcall(vim.fn.readfile, state_file())
  if not ok or type(lines) ~= "table" then
    return nil
  end
  local name = (lines[1] or ""):gsub("%s+$", "")
  if name == "" then
    return nil
  end
  return name
end

---Apply a theme. Returns true when it worked.
function M.apply(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  local ok = pcall(vim.cmd.colorscheme, name)
  return ok
end

---Save every theme change, no matter who triggered it (picker, :Theme or a
---plugin). Registered once, the first time a theme is loaded.
local function attach_listener()
  if attached then
    return
  end
  attached = true
  pcall(vim.api.nvim_create_autocmd, "ColorScheme", {
    desc = "Remember the chosen colourscheme",
    callback = function()
      local name = vim.g.colors_name
      if name and name ~= "" then
        M.save(name)
      end
    end,
  })
end

---Apply the saved theme at startup. Falls back to the default theme when the
---saved one is gone (for example after removing a plugin).
function M.load()
  attach_listener()

  local name = M.read() or M.default
  if not M.apply(name) then
    M.apply(M.default)
  end
end

---Let the user choose a theme right now.
function M.pick()
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker and type(snacks.picker.colorschemes) == "function" then
    -- Snacks applies the theme itself; attach_listener() saves the choice.
    local picked = pcall(snacks.picker.colorschemes)
    if picked then
      return
    end
  end

  -- Fallback: a plain Neovim menu, which works before any plugin loads.
  vim.ui.select(M.available, {
    prompt = "Pick a colourscheme",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end
    if M.apply(choice) then
      M.save(choice)
    else
      vim.notify("Could not apply theme: " .. choice, vim.log.levels.WARN)
    end
  end)
end

return M
