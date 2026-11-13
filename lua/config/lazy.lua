-- lua/config/lazy.lua
--
-- Bootstraps lazy.nvim (the plugin manager) and loads every file in
-- lua/plugins/. On the very first launch this clones lazy.nvim from GitHub,
-- then installs all plugins automatically. No manual step.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Check for the *module*, not just the folder: an interrupted clone leaves an
-- empty directory behind, and a plain fs_stat() check would then skip the
-- clone forever and fail with "module 'lazy' not found".
--
-- A shallow clone (--depth 1) is used deliberately: it is roughly ten times
-- smaller than the full history and far less likely to hit a flaky network.
local function bootstrap()
  if vim.fn.filereadable(lazypath .. "/lua/lazy/init.lua") == 1 then
    return true
  end

  if vim.fn.isdirectory(lazypath) == 1 then
    vim.fn.delete(lazypath, "rf")
  end

  local repo = "https://github.com/folke/lazy.nvim.git"
  for attempt = 1, 3 do
    -- HTTP/1.1 is deliberate: HTTP/2 multiplexing regularly dies with
    -- "unexpected disconnect while reading sideband packet" on flaky
    -- connections, and a plugin manager that cannot download itself is a
    -- confusing first impression.
    vim.fn.system({
      "git",
      "-c",
      "http.version=HTTP/1.1",
      "clone",
      "--depth",
      "1",
      "--branch",
      "stable",
      repo,
      lazypath,
    })

    if vim.fn.filereadable(lazypath .. "/lua/lazy/init.lua") == 1 then
      -- `--branch stable` checks out a *tag*, which leaves a detached HEAD.
      -- lazy.nvim manages itself as a plugin and writes its commit/branch to
      -- lazy-lock.json, which asserts on a missing branch name. Give it a real
      -- local branch so the first ":Lazy sync" cannot fail on that assertion.
      vim.fn.system({ "git", "-C", lazypath, "checkout", "-B", "stable" })
      return true
    end

    vim.fn.delete(lazypath, "rf")
    vim.api.nvim_echo(
      { { ("lazy.nvim download failed (attempt %d of 3), retrying…\n"):format(attempt), "WarningMsg" } },
      true,
      {}
    )
  end

  return false
end

if not bootstrap() then
  vim.api.nvim_echo({
    { "Could not download lazy.nvim.\n", "ErrorMsg" },
    { "Check your network, then run this to install it by hand:\n", "Normal" },
    { "  git clone --depth 1 --branch stable https://github.com/folke/lazy.nvim.git " .. lazypath .. "\n", "Comment" },
  }, true, {})
  return
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  defaults = {
    lazy = false, -- load plugins at startup: simpler and fast enough
    version = false, -- always use the latest commit unless a plugin pins one
  },
  install = {
    -- Try the configured colourscheme first, fall back to the built-in one.
    colorscheme = { "tokyonight", "habamax" },
  },
  checker = { enabled = false }, -- no surprise update popups
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
