-- lua/keys/tf.lua
--
-- Terraform, the short way: :Tf <subcommand> plus five leader keys.
--
-- Every command runs in the project root (nearest .git) inside the terminal
-- panel, so you get history, colours and Ctrl-C for free. `apply` always asks
-- first: it changes real infrastructure.

local M = {}

function M.setup(R)
  local U = require("config.util")

  R.group("<leader>t", "Terraform")

  -- The real subcommand per short name. `fmt` is recursive on purpose: a
  -- Terraform repo is almost always a folder of modules.
  local subcommands = {
    init = "init",
    validate = "validate",
    plan = "plan",
    apply = "apply",
    fmt = "fmt -recursive",
    output = "output",
  }

  ---Run one Terraform subcommand in the project root.
  local function run(sub)
    U.run_task("terraform " .. sub, { cwd = U.root() })
  end

  ---`apply` is the only command that needs a decision, so it gets its own
  ---function: yes/no dialog, default "No".
  local function apply()
    local choice = vim.fn.confirm("Apply these changes?", "&Yes\n&No", 2)
    if choice ~= 1 then
      U.notify("Terraform apply cancelled")
      return
    end
    run("apply")
  end

  -- -------------------------------------------------------------------------
  -- Command: :Tf <subcommand>
  -- -------------------------------------------------------------------------
  R.cmd("Tf", function(args)
    local name = vim.trim(args.args or "")
    local sub = subcommands[name]

    if not sub then
      U.notify(
        (':Tf needs one of: init, validate, plan, apply, fmt, output (got "%s")'):format(name),
        vim.log.levels.WARN
      )
      return
    end

    if name == "apply" then
      apply()
      return
    end

    run(sub)
  end, {
    desc = "Run a Terraform command in the project root",
    cat = "Terraform",
    nargs = 1,
    complete = function()
      return { "init", "validate", "plan", "apply", "fmt", "output" }
    end,
  })

  -- -------------------------------------------------------------------------
  -- Keys
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<leader>ti",
    rhs = function()
      run("init")
    end,
    desc = "Terraform: init (download providers)",
    cat = "Terraform",
  })

  R.map({
    lhs = "<leader>tv",
    rhs = function()
      run("validate")
    end,
    desc = "Terraform: validate the configuration",
    cat = "Terraform",
  })

  R.map({
    lhs = "<leader>tp",
    rhs = function()
      run("plan")
    end,
    desc = "Terraform: plan (preview changes)",
    cat = "Terraform",
  })

  R.map({
    lhs = "<leader>ta",
    rhs = apply,
    desc = "Terraform: apply (asks to confirm)",
    cat = "Terraform",
  })

  R.map({
    lhs = "<leader>tf",
    rhs = function()
      run("fmt -recursive")
    end,
    desc = "Terraform: format every file",
    cat = "Terraform",
  })
end

return M
