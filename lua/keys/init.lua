-- lua/keys/init.lua
--
-- Loads every keymap module, in a fixed order, then applies the registry.
-- Missing modules are tolerated on purpose: while the config is being built in
-- parallel, some files may not exist yet, and the editor must still start.

local M = {}

M.modules = {
  "core", -- Cmd+S/W/Z/C/V..., terminal escape
  "ui", -- tabs, theme, which-key
  "nav", -- explorer, pickers, palette, terminal, problems
  "edit", -- multicursor, move/duplicate line, surround, comment
  "lsp", -- definition, references, rename, code action, format
  "lang", -- .NET, React Native, debug keys
  "tf", -- Terraform keys
  "ai", -- OpenCode
  "help", -- F1, :HelpMe
}

function M.setup()
  local R = require("config.registry")
  local loaded = 0

  for _, name in ipairs(M.modules) do
    local ok, mod = pcall(require, "keys." .. name)
    if ok and type(mod) == "table" and type(mod.setup) == "function" then
      local ok2, err = pcall(mod.setup, R)
      if ok2 then
        loaded = loaded + 1
      else
        vim.notify(("keys.%s failed: %s"):format(name, err), vim.log.levels.WARN)
      end
    elseif not ok then
      -- Not built yet. Silence is intentional: see the comment above.
    end
  end

  R.apply()
  vim.g.registry_dupes = R.dupes
  vim.g.registry_modules = loaded
end

return M
