-- lua/config/commands.lua
-- The commands that belong to the core config itself.
-- Feature commands (:Tf, :Ask, :HelpMe, :Format, ...) are declared by the
-- matching lua/keys/*.lua file so they show up in :HelpMe automatically.

local R = require("config.registry")

-- Reload the config without restarting Neovim.
R.cmd("Reload", function()
  for name in pairs(package.loaded) do
    if name:match("^config%.") or name:match("^keys") or name:match("^help") then
      package.loaded[name] = nil
    end
  end
  vim.cmd("source " .. vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded", vim.log.levels.INFO)
end, { desc = "Reload the Neovim config", cat = "Config" })

R.cmd("ConfigEdit", function()
  vim.cmd("tabnew " .. vim.fn.stdpath("config") .. "/init.lua")
end, { desc = "Open this config for editing", cat = "Config" })

R.cmd("ConfigUpdate", function()
  vim.cmd("Lazy update")
  vim.cmd("MasonUpdate")
  vim.notify("Plugins and tools updated", vim.log.levels.INFO)
end, { desc = "Update plugins and Mason tools", cat = "Config" })

R.cmd("Home", function()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    vim.notify("snacks.nvim is not loaded yet (try :Lazy sync)", vim.log.levels.WARN)
    return
  end
  snacks.dashboard()
end, { desc = "Open the start screen", cat = "Config" })

-- ---------------------------------------------------------------------------
-- Beginner mode vs Vim mode.
-- Beginner mode: arrow keys work, so you can edit before you learn hjkl.
-- Vim mode: arrows stop working and nudge you towards real motions.
-- ---------------------------------------------------------------------------
local function set_arrows(enabled)
  local hint = function()
    vim.notify("Arrows are off in Vim mode. Use h j k l (or :Beginner).", vim.log.levels.INFO)
  end

  for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
    if enabled then
      pcall(vim.keymap.del, { "n", "i", "v" }, key)
    else
      vim.keymap.set({ "n", "i", "v" }, key, hint, { desc = "Hint: use hjkl" })
    end
  end
end

R.cmd("Beginner", function()
  vim.g.beginner_mode = true
  set_arrows(true)
  vim.opt.relativenumber = false
  vim.notify("Beginner mode: arrows and absolute line numbers", vim.log.levels.INFO)
end, { desc = "Beginner mode (arrows on)", cat = "Config" })

R.cmd("VimMode", function()
  vim.g.beginner_mode = false
  set_arrows(false)
  vim.opt.relativenumber = true
  vim.notify("Vim mode: arrows off, relative numbers on", vim.log.levels.INFO)
end, { desc = "Vim mode (arrows off)", cat = "Config" })

R.cmd("Health", function()
  vim.cmd("checkhealth")
end, { desc = "Run :checkhealth", cat = "Config" })

-- Regenerate KEYBINDINGS.md from the live registry.
R.cmd("ConfigDocs", function()
  local root = vim.fn.stdpath("config")
  local script = root .. "/scripts/gen-docs.lua"
  if vim.fn.filereadable(script) == 0 then
    vim.notify("scripts/gen-docs.lua is missing", vim.log.levels.WARN)
    return
  end
  local res = vim
    .system({ "nvim", "--headless", "-c", "lua dofile('" .. script .. "')", "-c", "qa" }, {
      cwd = root,
      text = true,
    })
    :wait()
  if res.code == 0 then
    vim.notify("KEYBINDINGS.md regenerated", vim.log.levels.INFO)
  else
    vim.notify(
      "Docs generation failed (duplicate keymaps?):\n" .. (res.stdout or "") .. (res.stderr or ""),
      vim.log.levels.ERROR
    )
  end
end, { desc = "Regenerate KEYBINDINGS.md", cat = "Config" })

-- :Panic, :HelpMe and :HelpTutorial live in lua/keys/help.lua, because they
-- need windows and a bit of formatting. One owner per command, always.
