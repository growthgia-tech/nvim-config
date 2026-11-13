-- scripts/health.lua
--
-- Headless self-check. Run it with:
--   bash scripts/verify.sh
-- or directly:
--   nvim --headless -c "lua dofile('scripts/health.lua')" -c qa
--
-- Every check prints PASS or FAIL. Exit code is 1 if anything failed, so CI
-- (and you) can trust the result.

local failures = 0
local passes = 0

local function pass(name)
  passes = passes + 1
  print("PASS  " .. name)
end

local function fail(name, reason)
  failures = failures + 1
  print("FAIL  " .. name .. (reason and (": " .. tostring(reason)) or ""))
end

local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass(name)
  else
    fail(name, err)
  end
end

local function assert_eq(got, want, label)
  if got ~= want then
    error(("%s: expected %s, got %s"):format(label, vim.inspect(want), vim.inspect(got)), 2)
  end
end

local function assert_true(value, label)
  if not value then
    error(label, 2)
  end
end

-- ---------------------------------------------------------------------------
-- 1. Version
-- ---------------------------------------------------------------------------
check("Neovim 0.11+", function()
  assert_true(vim.fn.has("nvim-0.11") == 1, "this config needs Neovim 0.11 or newer")
end)

-- ---------------------------------------------------------------------------
-- 2. Plugins actually loaded
-- ---------------------------------------------------------------------------
check("lazy.nvim loaded every plugin", function()
  local lazy = require("lazy")
  local plugins = lazy.plugins()
  assert_true(#plugins >= 20, "only " .. #plugins .. " plugins registered")

  local broken = {}
  for _, p in ipairs(plugins) do
    -- A plugin that never installed has no directory.
    if p.dir and vim.fn.isdirectory(p.dir) == 0 then
      table.insert(broken, p.name)
    end
  end

  if #broken > 0 then
    error("not installed: " .. table.concat(broken, ", "))
  end
end)

check("no plugin load errors", function()
  local ok, err = pcall(function()
    for _, mod in ipairs({
      "snacks",
      "lualine",
      "bufferline",
      "which-key",
      "dropbar",
      "blink.cmp",
      "conform",
      "lint",
      "mason",
      "telescope_placeholder_should_fail_silently",
    }) do
      if mod ~= "telescope_placeholder_should_fail_silently" then
        assert_true(require(mod) ~= nil, "could not require " .. mod)
      end
    end
  end)
  if not ok then
    error(err)
  end
end)

-- ---------------------------------------------------------------------------
-- 3. Every file in the config parses
-- ---------------------------------------------------------------------------
check("all Lua files parse", function()
  local root = vim.fn.stdpath("config")
  local files = vim.fn.globpath(root, "lua/**/*.lua", false, true)
  vim.list_extend(files, vim.fn.globpath(root, "scripts/*.lua", false, true))

  local bad = {}
  for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    if not chunk then
      table.insert(bad, file .. " -> " .. tostring(err))
    end
  end

  if #bad > 0 then
    error(table.concat(bad, " | "))
  end
end)

-- ---------------------------------------------------------------------------
-- 4. The registry: no duplicate keys, docs can be generated
-- ---------------------------------------------------------------------------
check("registry has no duplicate keys", function()
  local R = require("config.registry")
  if #R.entries == 0 then
    error("the registry is empty: keys/*.lua did not declare anything")
  end
  if #R.dupes > 0 then
    local lines = {}
    for _, d in ipairs(R.dupes) do
      table.insert(lines, ("[%s] %s"):format(d.mode, d.lhs))
    end
    error("duplicates: " .. table.concat(lines, ", "))
  end
end)

check("help rows are generated", function()
  local rows = require("config.registry").help_rows()
  assert_true(#rows > 40, "only " .. #rows .. " rows")
end)

-- ---------------------------------------------------------------------------
-- 5. The commands the docs promise actually exist
-- ---------------------------------------------------------------------------
check("every documented command exists", function()
  local commands = {
    "Ask",
    "AICommit",
    "AIDiff",
    "AIExplain",
    "AIFix",
    "AIReview",
    "AITests",
    "Beginner",
    "ConfigDocs",
    "ConfigEdit",
    "ConfigUpdate",
    "DotnetBuild",
    "DotnetRun",
    "DotnetTest",
    "Format",
    "FormatToggle",
    "Health",
    "HelpMe",
    "HelpTutorial",
    "Palette",
    "Panic",
    "Problems",
    "Proj",
    "RN",
    "Reload",
    "Tf",
    "Theme",
    "VimMode",
  }

  local missing = {}
  for _, name in ipairs(commands) do
    if vim.fn.exists(":" .. name) ~= 2 then
      table.insert(missing, ":" .. name)
    end
  end
  if #missing > 0 then
    error("missing: " .. table.concat(missing, ", "))
  end
end)

-- ---------------------------------------------------------------------------
-- 6. Keymaps are bound for this platform
-- ---------------------------------------------------------------------------
check("primary shortcuts are bound", function()
  local P = require("config.platform")

  -- The modifier actually usable on this OS.
  local keys = {
    { "n", P.is_mac and "<D-s>" or "<C-s>" },
    { "n", P.is_mac and "<D-p>" or "<C-p>" },
    { "n", P.is_mac and "<D-S-p>" or "<C-S-p>" },
    { "n", "<F12>" },
    { "n", "<leader>aa" },
    { "n", "<F1>" },
    { "x", "<leader>ae" },
  }

  local missing = {}
  for _, pair in ipairs(keys) do
    local lhs = vim.fn.maparg(pair[2], pair[1])
    if lhs == "" then
      table.insert(missing, pair[1] .. " (" .. pair[2] .. ")")
    end
  end
  if #missing > 0 then
    error("not bound: " .. table.concat(missing, ", "))
  end
end)

-- ---------------------------------------------------------------------------
-- 7. Look and feel
-- ---------------------------------------------------------------------------
check("a colourscheme is active", function()
  assert_true(vim.g.colors_name ~= nil and vim.g.colors_name ~= "", "no colorscheme")
end)

check("mouse is enabled", function()
  assert_true(vim.o.mouse:find("a") ~= nil, "mouse is off")
end)

-- A GUI app launched from Finder gets a minimal PATH. If the config did not
-- repair it, ripgrep/fd/opencode and every language server would be missing.
check("PATH contains the tool directories", function()
  local P = require("config.platform")
  local path = vim.env.PATH or ""
  local needed = {}

  if P.is_mac then
    table.insert(needed, "/opt/homebrew/bin")
    table.insert(needed, vim.fs.joinpath(vim.uv.os_homedir(), "Library", "pnpm", "bin"))
  elseif not P.is_windows then
    table.insert(needed, "/usr/local/bin")
    table.insert(needed, vim.fs.joinpath(vim.uv.os_homedir(), ".local", "bin"))
  end
  table.insert(needed, vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin"))

  local missing = {}
  for _, dir in ipairs(needed) do
    if vim.fn.isdirectory(dir) == 1 and not path:find(dir, 1, true) then
      table.insert(missing, dir)
    end
  end

  if #missing > 0 then
    error("not on PATH: " .. table.concat(missing, ", "))
  end
end)

check("clipboard is integrated", function()
  assert_true(vim.o.clipboard:find("unnamedplus") ~= nil or vim.o.clipboard:find("unnamed") ~= nil)
end)

-- ---------------------------------------------------------------------------
-- 8. Language tooling config (installed by Mason, not by this check)
-- ---------------------------------------------------------------------------
check("language servers are configured", function()
  -- nvim-lspconfig is lazy-loaded (event = "VeryLazy"), and VeryLazy has not
  -- fired yet in a headless run. Loading it explicitly is exactly what would
  -- happen when you open a file.
  pcall(function()
    require("lazy").load({ plugins = { "nvim-lspconfig" } })
  end)

  local servers = { "vtsls", "basedpyright", "lua_ls", "bashls", "terraformls", "jsonls" }
  local missing = {}
  for _, name in ipairs(servers) do
    -- Neovim 0.12: vim.lsp.config("name") is the *setter*. The resolved
    -- definition is read through the table itself, vim.lsp.config["name"].
    local ok, cfg = pcall(function()
      return vim.lsp.config[name]
    end)
    if not ok or type(cfg) ~= "table" then
      table.insert(missing, name)
    end
  end
  if #missing > 0 then
    error("no definition for: " .. table.concat(missing, ", "))
  end
end)

check("formatters are mapped per filetype", function()
  local ok, conform = pcall(require, "conform")
  if not ok then
    error("conform.nvim is not loaded")
  end
  local by_ft = conform.formatters_by_ft or {}
  for _, ft in ipairs({ "lua", "typescript", "cs", "python", "terraform", "sh" }) do
    assert_true(by_ft[ft] ~= nil, "no formatter for " .. ft)
  end
end)

-- ---------------------------------------------------------------------------
-- 9. Optional integrations report honestly instead of failing
-- ---------------------------------------------------------------------------
check("opencode.nvim is installed", function()
  local ok = pcall(require, "opencode")
  assert_true(ok, "opencode.nvim is missing")
  if vim.fn.executable("opencode") == 0 then
    print("NOTE  the 'opencode' CLI is not on PATH — AI commands will explain how to install it")
  end
end)

check("debug adapters are registered", function()
  local ok, dap = pcall(require, "dap")
  assert_true(ok, "nvim-dap is missing")
  assert_true(dap.adapters.coreclr ~= nil, "no C# adapter")
  assert_true(dap.adapters["pwa-node"] ~= nil, "no JS/TS adapter")
end)

-- ---------------------------------------------------------------------------
-- 10. VS Code-like surfaces: mouse, start screen, panels
-- ---------------------------------------------------------------------------
check("one click opens a row in lists", function()
  assert_true(
    vim.fn.exists("#UserMouse#FileType") == 1,
    "lua/ui/mouse.lua did not install its FileType autocmd"
  )
end)

check("the start screen is clickable", function()
  require("snacks").dashboard()
  local dashboard = require("ui.dashboard")
  assert_true(dashboard.instance() ~= nil, "the dashboard click layer did not attach")
  assert_true(vim.fn.maparg("<LeftMouse>", "n") ~= "", "no click mapping on the start screen")
end)

check("folder and panel commands exist", function()
  for _, name in ipairs({ "OpenFolder", "NewFile", "Explorer", "GitChanges", "AIPanel" }) do
    assert_true(vim.fn.exists(":" .. name) == 2, ":" .. name .. " is not defined")
  end
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passes, failures))

if failures > 0 then
  vim.cmd("cq 1")
else
  vim.cmd("qa!")
end
