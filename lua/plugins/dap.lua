-- lua/plugins/dap.lua
--
-- Debugging with a VS Code-shaped experience:
--   * nvim-dap          -> the debugger engine
--   * nvim-dap-ui      -> the panels (scopes, breakpoints, stack, REPL)
--   * nvim-dap-virtual-text -> inline variable values next to the code
--
-- Adapters are configured by hand here instead of with mason-nvim-dap: that
-- plugin keeps changing its handlers API and we only need two adapters.
-- The binaries themselves (netcoredbg, js-debug-adapter) are installed by
-- mason-tool-installer in lua/plugins/lsp.lua.

---Find a debugger binary without crashing when it is missing.
local function exe(name)
  local path = vim.fn.exepath(name)
  if path == "" then
    vim.notify(
      ("dap.lua: %s not found on PATH. Install it with mason (:Mason) or your package manager."):format(
        name
      ),
      vim.log.levels.WARN
    )
    return name -- still hand it to dap: the error will be clearer at launch
  end
  return path
end

-- ---------------------------------------------------------------------------
-- nvim-dap: adapters + launch configurations
-- ---------------------------------------------------------------------------

local function configure_dap()
  local ok, dap = pcall(require, "dap")
  if not ok then
    vim.notify("dap.lua: nvim-dap failed to load", vim.log.levels.WARN)
    return
  end

  -- ---- .NET (coreclr via netcoredbg) ------------------------------------
  dap.adapters.coreclr = {
    type = "executable",
    command = exe("netcoredbg"),
    args = { "--interpreter=vscode" },
  }

  dap.configurations.cs = {
    {
      type = "coreclr",
      request = "launch",
      name = "Launch .NET (pick dll)",
      -- You point at the built dll; the path is remembered per project by
      -- dap's own history.
      program = function()
        return vim.fn.input(
          "dll: ",
          vim.fn.getcwd() .. "/bin/Debug/",
          "file"
        )
      end,
    },
  }

  -- ---- JavaScript / TypeScript (vscode-js-debug) -------------------------
  dap.adapters["pwa-node"] = {
    type = "server",
    host = "127.0.0.1",
    port = "${port}",
    executable = {
      command = exe("js-debug-adapter"),
      args = { "${port}" },
    },
  }

  -- One launch + one attach configuration per JS-ish filetype. React Native
  -- and plain node projects both use the same shapes.
  local js_filetypes = {
    "typescript",
    "typescriptreact",
    "javascript",
    "javascriptreact",
  }

  for _, ft in ipairs(js_filetypes) do
    dap.configurations[ft] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch current file",
        program = "${file}",
        cwd = "${workspaceFolder}",
        sourceMaps = true,
        skipFiles = { "<node_internals>/**" },
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach to Metro (8081)",
        port = 8081,
        cwd = "${workspaceFolder}",
        localRoot = "${workspaceFolder}",
        remoteRoot = "${workspaceFolder}",
        sourceMaps = true,
      },
    }
  end
end

-- ---------------------------------------------------------------------------
-- nvim-dap-ui: panels that appear and disappear with the session
-- ---------------------------------------------------------------------------

local function configure_dapui()
  local ok, dapui = pcall(require, "dapui")
  if not ok then
    vim.notify("dap.lua: nvim-dap-ui failed to load", vim.log.levels.WARN)
    return
  end

  dapui.setup()

  local ok2, dap = pcall(require, "dap")
  if not ok2 then
    return
  end

  -- pcall inside every listener: a UI hiccup must not abort the session.
  local function open()
    pcall(dapui.open)
  end

  local function close()
    pcall(dapui.close)
  end

  dap.listeners.before.attach.dapui_config = open
  dap.listeners.before.launch.dapui_config = open
  dap.listeners.before.event_terminated.dapui_config = close
  dap.listeners.before.event_exited.dapui_config = close
end

-- ---------------------------------------------------------------------------
-- Plugin specs
-- ---------------------------------------------------------------------------

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio", -- async runtime used by dap-ui
      "theHamsta/nvim-dap-virtual-text",
    },
    config = configure_dap,
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-lua/plenary.nvim",
    },
    -- We call dapui.setup() ourselves above, so no plain `opts` here.
    config = configure_dapui,
  },

  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap" },
    -- Defaults are good: show values inline, only for the current session.
    opts = {},
  },
}
