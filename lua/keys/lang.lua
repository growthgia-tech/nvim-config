-- lua/keys/lang.lua
--
-- Keys and commands for the languages we write most: C#/.NET, TypeScript /
-- React Native, plus the debugger.
--
-- Nothing here may crash on startup: every plugin call goes through pcall,
-- because keys are registered before plugins have necessarily loaded.

local M = {}

function M.setup(R)
  local U = require("config.util")

  -- Press Space d and wait: the debug menu explains itself.
  R.group("<leader>d", "Debug")

  -- -------------------------------------------------------------------------
  -- Small helpers
  -- -------------------------------------------------------------------------

  -- Wrap a method on a plugin module so a missing plugin is a notification,
  -- not an error message in the middle of your day.
  local function call(module, method)
    return function()
      local ok, mod = pcall(require, module)
      if not ok then
        vim.notify(
          ("%s is not available yet (plugin not installed?)"):format(module),
          vim.log.levels.WARN
        )
        return
      end

      local fn = mod[method]
      if type(fn) ~= "function" then
        vim.notify(
          ("%s.%s does not exist in this version"):format(module, method),
          vim.log.levels.WARN
        )
        return
      end

      local ok2, err = pcall(fn)
      if not ok2 then
        vim.notify(("%s.%s failed: %s"):format(module, method, tostring(err)), vim.log.levels.WARN)
      end
    end
  end

  -- The REPL lives at dap.repl.toggle(), one level deeper than the rest.
  local dap_repl = function()
    local ok, dap = pcall(require, "dap")
    if not ok or type(dap.repl) ~= "table" then
      vim.notify("nvim-dap is not installed yet", vim.log.levels.WARN)
      return
    end
    local ok2, err = pcall(dap.repl.toggle)
    if not ok2 then
      vim.notify("Could not toggle the dap REPL: " .. tostring(err), vim.log.levels.WARN)
    end
  end

  -- dap-ui has no arguments worth passing for a plain toggle.
  local dapui_toggle = function()
    local ok, ui = pcall(require, "dapui")
    if not ok then
      vim.notify("nvim-dap-ui is not installed yet", vim.log.levels.WARN)
      return
    end
    pcall(ui.toggle, {})
  end

  -- Evaluate the expression under the cursor, or the visual selection.
  local dapui_eval = function()
    local ok, ui = pcall(require, "dapui")
    if not ok then
      vim.notify("nvim-dap-ui is not installed yet", vim.log.levels.WARN)
      return
    end
    pcall(ui.eval, nil, { enter = true })
  end

  -- -------------------------------------------------------------------------
  -- Debugger
  -- -------------------------------------------------------------------------
  -- The F-keys are the VS Code muscle memory, but on a Mac keyboard F5 is
  -- Fn+F5. Every F-key therefore has a <leader>d... twin.
  R.map({
    lhs = "<F5>",
    rhs = call("dap", "continue"),
    desc = "Debug: start / continue",
    cat = "Debug",
  })

  R.map({
    lhs = "<S-F5>",
    rhs = call("dap", "terminate"),
    desc = "Debug: stop the session",
    cat = "Debug",
  })

  R.map({
    lhs = "<F9>",
    rhs = call("dap", "toggle_breakpoint"),
    desc = "Debug: toggle breakpoint",
    cat = "Debug",
  })

  R.map({
    lhs = "<F10>",
    rhs = call("dap", "step_over"),
    desc = "Debug: step over",
    cat = "Debug",
  })

  R.map({
    lhs = "<F11>",
    rhs = call("dap", "step_into"),
    desc = "Debug: step into",
    cat = "Debug",
  })

  R.map({
    lhs = "<S-F11>",
    rhs = call("dap", "step_out"),
    desc = "Debug: step out",
    cat = "Debug",
  })

  -- Leader twins (work on every keyboard).
  R.map({
    lhs = "<leader>dc",
    rhs = call("dap", "continue"),
    desc = "Debug: start / continue",
    cat = "Debug",
  })

  R.map({
    lhs = "<leader>db",
    rhs = call("dap", "toggle_breakpoint"),
    desc = "Debug: toggle breakpoint",
    cat = "Debug",
  })

  R.map({
    lhs = "<leader>dn",
    rhs = call("dap", "step_over"),
    desc = "Debug: step over",
    cat = "Debug",
  })

  R.map({
    lhs = "<leader>di",
    rhs = call("dap", "step_into"),
    desc = "Debug: step into",
    cat = "Debug",
  })

  R.map({
    lhs = "<leader>do",
    rhs = call("dap", "step_out"),
    desc = "Debug: step out",
    cat = "Debug",
  })

  -- Panels and the REPL.
  R.map({
    lhs = "<leader>du",
    rhs = dapui_toggle,
    desc = "Debug: toggle the debugger panels",
    cat = "Debug",
  })

  R.map({
    lhs = "<leader>de",
    rhs = dapui_eval,
    desc = "Debug: evaluate under cursor / selection",
    cat = "Debug",
    modes = { "n", "v" },
  })

  R.map({
    lhs = "<leader>dr",
    rhs = dap_repl,
    desc = "Debug: toggle the REPL",
    cat = "Debug",
  })

  -- -------------------------------------------------------------------------
  -- .NET commands
  -- -------------------------------------------------------------------------
  -- All of these run in the project root (nearest .git) and land in the
  -- terminal panel, so you can read output and Ctrl-C them.
  R.cmd("DotnetBuild", function()
    U.run_task("dotnet build", { cwd = U.root() })
  end, {
    desc = "Build the .NET solution",
    cat = ".NET",
  })

  R.cmd("DotnetRun", function()
    U.run_task("dotnet run", { cwd = U.root() })
  end, {
    desc = "Run the .NET project",
    cat = ".NET",
  })

  R.cmd("DotnetTest", function()
    U.run_task("dotnet test", { cwd = U.root() })
  end, {
    desc = "Run the .NET tests",
    cat = ".NET",
  })

  -- Roslyn keeps a list of discovered solutions/projects; this lets you pick
  -- one when automatic discovery guesses wrong.
  R.cmd("DotnetSolution", function()
    local ok, err = pcall(vim.cmd, "Roslyn target")
    if not ok then
      vim.notify(
        "Roslyn is not ready yet (open a C# file first): " .. tostring(err),
        vim.log.levels.WARN
      )
    end
  end, {
    desc = "Pick the .NET solution/project for Roslyn",
    cat = ".NET",
  })

  -- -------------------------------------------------------------------------
  -- React Native / Expo
  -- -------------------------------------------------------------------------
  ---True when the project root looks like an Expo app.
  local function is_expo(root)
    local package_json = root .. "/package.json"
    if vim.fn.filereadable(package_json) ~= 1 then
      return false
    end

    local ok, lines = pcall(vim.fn.readfile, package_json)
    if not ok then
      return false
    end

    -- Cheap check on purpose: a real JSON parse buys us nothing here.
    local text = table.concat(lines, "\n")
    return text:find('"expo"', 1, true) ~= nil or vim.fn.isdirectory(root .. "/.expo") == 1
  end

  R.cmd("RN", function(args)
    local sub = vim.trim(args.args or "")
    local root = U.root()

    if sub == "start" then
      local runner = is_expo(root) and "npx expo start" or "npx react-native start"
      U.run_task(runner, { cwd = root })
    elseif sub == "ios" then
      U.run_task("npx react-native run-ios", { cwd = root })
    elseif sub == "android" then
      U.run_task("npx react-native run-android", { cwd = root })
    else
      U.notify(
        (':RN needs start, ios or android (got "%s"). Try :RN start'):format(sub),
        vim.log.levels.WARN
      )
    end
  end, {
    desc = "React Native: start the bundler / run on a device",
    cat = "React Native",
    nargs = 1,
    complete = function()
      return { "start", "ios", "android" }
    end,
  })
end

return M
