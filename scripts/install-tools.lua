-- scripts/install-tools.lua
--
-- Installs every Mason package this config declares: language servers,
-- formatters, linters and debug adapters.
--
-- Why this exists instead of just calling :MasonToolsInstallSync:
--   * it reads the package lists from the plugin specs, so there is no second
--     list to keep in sync;
--   * it waits for the installs to actually finish (the "sync" command waits
--     for its own queue, which can hang on a flaky connection);
--   * it reports exactly what is missing at the end instead of exiting 0.
--
-- Run it with:
--   nvim --headless -c "lua dofile('scripts/install-tools.lua')" -c qa
-- install.sh and install.ps1 call it for you.

local LOG_EVERY = 5 -- seconds between progress lines
local TIMEOUT = 60 * 20 -- give up after 20 minutes of no progress at all

local Lazy = require("lazy")
Lazy.load({ plugins = { "mason.nvim" } })

local ok_registry, registry = pcall(require, "mason-registry")
if not ok_registry then
  io.stderr:write("mason.nvim is not installed; run :Lazy sync first\n")
  vim.cmd("cq 1")
  return
end

registry.refresh(function() end)

-- Pull the lists out of the specs that own them.
local servers, tools = {}, {}
for _, spec in ipairs(Lazy.plugins()) do
  if spec.name == "mason-lspconfig.nvim" and spec.opts and spec.opts.ensure_installed then
    servers = spec.opts.ensure_installed
  end
  if spec.name == "mason-tool-installer.nvim" and spec.opts and spec.opts.ensure_installed then
    tools = spec.opts.ensure_installed
  end
end

-- Mason's package names are not always the lspconfig server names.
local SERVER_PACKAGE = {
  eslint = "eslint-lsp",
  tailwindcss = "tailwindcss-language-server",
  emmet_language_server = "emmet-language-server",
  terraformls = "terraform-ls",
  yamlls = "yaml-language-server",
  jsonls = "json-ls",
  html = "html-lsp",
  cssls = "css-lsp",
  bashls = "bash-language-server",
}

local wanted, seen = {}, {}
local function want(name)
  if name and not seen[name] then
    seen[name] = true
    table.insert(wanted, name)
  end
end

for _, server in ipairs(servers) do
  if server ~= "roslyn" and server ~= "roslyn_ls" then
    want(SERVER_PACKAGE[server] or server)
  end
end
for _, tool in ipairs(tools) do
  want(tool)
end

-- Filter down to what is actually missing.
local missing = {}
for _, name in ipairs(wanted) do
  local ok, pkg = pcall(registry.get_package, name)
  if ok and not pkg:is_installed() then
    table.insert(missing, name)
  elseif not ok then
    print(("  ?  %s is not in the registry (skipped)"):format(name))
  end
end

if #missing == 0 then
  print(("All %d language tools are already installed."):format(#wanted))
  vim.cmd("qa!")
  return
end

print(
  ("Installing %d of %d language tools: %s"):format(#missing, #wanted, table.concat(missing, ", "))
)
print("This is the slow part (Mason downloads real binaries). Please wait…")

vim.cmd("MasonInstall " .. table.concat(missing, " "))

local elapsed = 0
local last_report = 0
local done = vim.wait(TIMEOUT, function()
  elapsed = elapsed + 1
  local remaining = 0
  for _, name in ipairs(missing) do
    local ok, pkg = pcall(registry.get_package, name)
    if not ok or not pkg:is_installed() then
      remaining = remaining + 1
    end
  end

  if remaining == 0 then
    return true
  end

  if elapsed - last_report >= LOG_EVERY then
    last_report = elapsed
    print(("  … %d remaining"):format(remaining))
  end
  return false
end, 1000)

local still_missing = {}
for _, name in ipairs(missing) do
  local ok, pkg = pcall(registry.get_package, name)
  if not ok or not pkg:is_installed() then
    table.insert(still_missing, name)
  end
end

if done and #still_missing == 0 then
  print(("All %d language tools installed."):format(#wanted))
  vim.cmd("qa!")
else
  print(("Could not install: %s"):format(table.concat(still_missing, ", ")))
  print("Neovim still works. Open it and run :Mason to retry, or :MasonLog for the reason.")
  -- Do not fail the installer: a missing formatter is not a broken editor.
  vim.cmd("qa!")
end
