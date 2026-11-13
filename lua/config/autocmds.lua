-- lua/config/autocmds.lua
-- Small background behaviours. No keymaps here (those live in lua/keys/).

local aug = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- ---------------------------------------------------------------------------
-- Reload files that changed on disk.
-- This is the magic that lets OpenCode edit a file and have your buffer update
-- while you watch. Without it you would be looking at stale text.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  group = aug,
  callback = function()
    -- Not while the user is typing a command line: reloading mid-command is
    -- confusing. (:help 'autoread' for the very similar built-in behaviour.)
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
  desc = "Reload buffers changed by external tools",
})

-- ---------------------------------------------------------------------------
-- Flash the yanked text so you can see what you copied.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
  desc = "Highlight yanked text",
})

-- ---------------------------------------------------------------------------
-- Reopen a file where you left the cursor.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufReadPost", {
  group = aug,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Restore last cursor position",
})

-- ---------------------------------------------------------------------------
-- Keep splits even when the window is resized.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("VimResized", {
  group = aug,
  command = "tabdo wincmd =",
  desc = "Equalise splits on resize",
})

-- ---------------------------------------------------------------------------
-- Markdown and git commits read better wrapped.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = { "markdown", "gitcommit", "text" },
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
  end,
  desc = "Soft-wrap prose filetypes",
})

-- ---------------------------------------------------------------------------
-- Filetype detection for the HashiCorp family.
-- Neovim already knows .tf/.tfvars; these fill the gaps.
-- ---------------------------------------------------------------------------
vim.filetype.add({
  extension = {
    tf = "terraform",
    tfvars = "terraform",
    nomad = "hcl",
    pkr = "hcl",
  },
  filename = {
    ["terragrunt.hcl"] = "hcl",
    [".terraformrc"] = "hcl",
    ["terraform.rc"] = "hcl",
  },
  pattern = {
    [".*%.pkr%.hcl"] = "hcl",
    [".*%.nomad"] = "hcl",
    [".*%.tf"] = "terraform",
  },
})

-- ---------------------------------------------------------------------------
-- Don't let Neovim open gigantic files with all the decorations on: it would
-- freeze for seconds and feel broken.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufReadPre", {
  group = aug,
  callback = function(args)
    local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
    if ok and stat and stat.size > 1024 * 1024 * 2 then
      vim.b[args.buf].bigfile = true
      vim.opt_local.syntax = "off"
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.spell = false
      vim.notify("Large file: decorations disabled", vim.log.levels.WARN)
    end
  end,
  desc = "Disable heavy features in >2MB files",
})
