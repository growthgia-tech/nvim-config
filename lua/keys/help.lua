-- lua/keys/help.lua
--
-- Discoverability is the feature here. A beginner should never have to guess:
-- F1 opens the list of everything, Space + wait shows the menu, and :Panic
-- answers "how do I get out of this".

local M = {}

function M.setup(R)
  local U = require("config.util")
  local WARN = vim.log.levels.WARN

  local function help()
    local ok, mod = pcall(require, "help")
    if ok then
      mod.open()
    else
      U.notify("Help module failed to load: " .. tostring(mod), WARN)
    end
  end

  local function tutorial()
    local ok, mod = pcall(require, "help.tutorial")
    if ok then
      mod.open()
    else
      U.notify("Tutorial failed to load: " .. tostring(mod), WARN)
    end
  end

  local function panic()
    local ok, mod = pcall(require, "help.panic")
    if ok then
      mod.open()
    else
      U.notify(
        "Esc = normal mode.  u = undo.  :w = save.  :q! = quit.  :Reload = reload.",
        WARN
      )
    end
  end

  ---------------------------------------------------------------------------
  -- Keys
  ---------------------------------------------------------------------------

  -- F1 is "help" in every program ever written. Keep that promise.
  R.map({
    lhs = "<F1>",
    rhs = help,
    desc = "Every key and command (this is the manual)",
    cat = "Help",
    modes = { "n", "i", "v" },
  })

  R.group("<leader>h", "Help")

  R.map({
    lhs = "<leader>hh",
    rhs = help,
    desc = "Cheat sheet of every key",
    cat = "Help",
  })

  R.map({
    lhs = "<leader>ht",
    rhs = tutorial,
    desc = "Beginner tutorial",
    cat = "Help",
  })

  R.map({
    lhs = "<leader>hp",
    rhs = panic,
    desc = "What to press when stuck",
    cat = "Help",
  })

  R.map({
    lhs = "<leader>hk",
    rhs = function()
      local ok, Snacks = pcall(require, "snacks")
      if ok then
        Snacks.picker.keymaps()
      else
        vim.cmd("map")
      end
    end,
    desc = "Search all keymaps",
    cat = "Help",
  })

  R.map({
    lhs = "<leader>hc",
    rhs = function()
      local ok, Snacks = pcall(require, "snacks")
      if ok then
        Snacks.picker.commands()
      else
        vim.cmd("command")
      end
    end,
    desc = "Search all commands",
    cat = "Help",
  })

  ---------------------------------------------------------------------------
  -- Commands
  ---------------------------------------------------------------------------

  R.cmd("HelpMe", help, { desc = "Show every key and command", cat = "Help" })
  R.cmd("HelpTutorial", tutorial, { desc = "Open the beginner tutorial", cat = "Help" })
  R.cmd("Panic", panic, { desc = "What to press when stuck", cat = "Help" })
end

return M
