-- lua/ui/panels.lua
--
-- The two VS Code-style side panels:
--
--   left   the file explorer (neo-tree, filesystem view)
--   left   the git changes panel (neo-tree, git_status view)
--   right  the AI chat (an opencode terminal)
--
-- Both the keymaps (lua/keys/*.lua) and the start screen use these functions,
-- so a change to the panel layout only happens in one place.

local M = {}
local U = require("config.util")

---Options shared by every time the AI panel is opened.
local function chat_opts(enter)
  return {
    win = {
      position = "right",
      width = 0.38,
      enter = enter,
      border = "rounded",
    },
  }
end

---Show/hide the opencode chat on the right. `enter` focuses it when opening.
function M.ai_chat(enter)
  if vim.fn.executable("opencode") == 0 then
    U.notify("The 'opencode' CLI is not installed. Run: brew install opencode", vim.log.levels.WARN)
    return
  end

  local ok, Snacks = pcall(require, "snacks")
  if not ok or not Snacks.terminal then
    U.notify("The terminal panel needs snacks.nvim (try :Lazy sync)", vim.log.levels.WARN)
    return
  end

  Snacks.terminal.toggle("opencode", chat_opts(enter))
end

---True when neo-tree is installed and ready.
local function have_neo_tree()
  return vim.fn.exists(":Neotree") == 2
end

---Show/hide the file explorer on the left.
function M.explorer()
  if have_neo_tree() then
    vim.cmd("Neotree filesystem toggle left")
  else
    U.notify("neo-tree is not installed yet (run :Lazy)", vim.log.levels.WARN)
  end
end

---Show/hide the "source control" view: every modified file in the working tree.
function M.git_changes()
  if have_neo_tree() then
    vim.cmd("Neotree git_status toggle left")
  else
    U.notify("neo-tree is not installed yet (run :Lazy)", vim.log.levels.WARN)
  end
end

---Show/hide the debugger panels (scopes, breakpoints, stack, REPL), the
---right-hand "Run and Debug" sidebar from VS Code.
function M.debug_panel()
  local ok, dapui = pcall(require, "dapui")
  if ok and type(dapui.toggle) == "function" then
    dapui.toggle()
  else
    U.notify("nvim-dap-ui is not installed yet (run :Lazy)", vim.log.levels.WARN)
  end
end

---Open the explorer at `dir` (used after "Open folder").
function M.reveal(dir)
  if have_neo_tree() then
    pcall(vim.cmd, "Neotree filesystem dir=" .. vim.fn.fnameescape(dir))
  else
    pcall(vim.cmd, "Explore " .. vim.fn.fnameescape(dir))
  end
end

return M
