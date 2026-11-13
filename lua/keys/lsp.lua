-- lua/keys/lsp.lua
--
-- The "smart editor" keys: jump to definition, find usages, rename, quick
-- fixes, format. They are only useful once a language server has attached, so
-- every action is wrapped in pcall: pressing a key in a plain text buffer
-- prints a friendly note instead of an error.
--
-- All mappings are declared with R.map() and all commands with R.cmd(), so
-- :HelpMe and KEYBINDINGS.md list them automatically.

local M = {}

function M.setup(R)
  local U = require("config.util")

  local function warn(msg)
    U.notify(msg, vim.log.levels.WARN)
  end

  -- -------------------------------------------------------------------------
  -- Small helpers. Each one keeps the "no language server here" case calm.
  -- -------------------------------------------------------------------------

  ---Jump to the next/previous diagnostic in this buffer and show it.
  ---These are the most-pressed keys when something is underlined in red, so
  ---they are plain bracket motions rather than leader keys.
  local function diagnostic_jump(forward)
    return function()
      local ok = pcall(function()
        vim.diagnostic.jump({ count = forward and 1 or -1, float = true })
      end)
      if not ok then
        -- Neovim < 0.11 fallback.
        vim.diagnostic.goto_next({ float = true })
      end
    end
  end

  R.map({
    lhs = "]d",
    rhs = diagnostic_jump(true),
    desc = "Next problem",
    cat = "Diagnostics",
  })

  R.map({
    lhs = "[d",
    rhs = diagnostic_jump(false),
    desc = "Previous problem",
    cat = "Diagnostics",
  })

  ---Jump to where the symbol under the cursor is defined.
  local function definition()
    if not pcall(vim.lsp.buf.definition) then
      warn("No language server for this file yet.")
    end
  end

  ---List every place the symbol is used (quickfix window).
  local function references()
    -- Some servers also return "call" entries, which is noise for a plain
    -- "find usages". Newer Neovim accepts a filter; older builds ignore the
    -- option, so we fall back to the plain command if the call fails.
    local ok = pcall(vim.lsp.buf.references, nil, {
      filter = function(item)
        return item ~= nil and item.kind ~= "call"
      end,
    })
    if not ok then
      if not pcall(vim.lsp.buf.references) then
        warn("No language server for this file yet.")
      end
    end
  end

  ---Rename the symbol everywhere. Neovim asks for the new name.
  local function rename()
    if not pcall(vim.lsp.buf.rename) then
      warn("Renaming is not available here.")
    end
  end

  ---Show the quick fixes / refactors for the cursor position.
  local function code_action()
    if not pcall(vim.lsp.buf.code_action) then
      warn("No code actions available here.")
    end
  end

  ---Format the buffer with conform, falling back to the language server.
  local function format_buffer()
    local ok, conform = pcall(require, "conform")

    -- conform loads on the first :write. If :Format is pressed before that,
    -- ask lazy.nvim to load it now and try once more.
    if not ok then
      pcall(function()
        require("lazy").load({ plugins = { "conform.nvim" } })
      end)
      ok, conform = pcall(require, "conform")
    end

    if ok and conform.format then
      conform.format({ async = true, lsp_format = "fallback" })
      return
    end

    if not pcall(vim.lsp.buf.format, { async = true }) then
      warn("No formatter for this file type yet.")
    end
  end

  ---Run the "organise imports" code action, when the server supports it.
  local function organize_imports()
    local ok = pcall(vim.lsp.buf.code_action, {
      context = { only = { "source.organizeImports" }, diagnostics = {} },
      apply = true,
    })
    if not ok then
      warn("This language server cannot organise imports.")
    end
  end

  ---Show/hide the little "3 references" lens above functions and types.
  local function toggle_codelens()
    local bufnr = vim.api.nvim_get_current_buf()

    if vim.b[bufnr].codelens_enabled then
      vim.b[bufnr].codelens_enabled = false
      pcall(vim.lsp.codelens.clear)
      U.notify("Code lens: off", vim.log.levels.INFO)
    else
      vim.b[bufnr].codelens_enabled = true
      local ok = pcall(vim.lsp.codelens.refresh, { bufnr = bufnr })
      if ok then
        U.notify("Code lens: on", vim.log.levels.INFO)
      else
        warn("This language server has no code lens.")
      end
    end
  end

  -- which-key label for the whole <leader>c family.
  R.group("<leader>c", "Code / LSP")

  -- -------------------------------------------------------------------------
  -- Jumping around (function keys = the VS Code muscle memory)
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<F12>",
    rhs = definition,
    desc = "Go to definition",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<S-F12>",
    rhs = references,
    desc = "Find all references (usages)",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<F2>",
    rhs = rename,
    desc = "Rename symbol everywhere",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<D-.>",
    rhs = code_action,
    desc = "Quick fix / code action",
    cat = "LSP",
    modes = { "n" },
  })

  -- -------------------------------------------------------------------------
  -- The <leader>c family (Space, then c, then one letter)
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<leader>ca",
    rhs = code_action,
    desc = "Code action (quick fix, refactor)",
    cat = "LSP",
    modes = { "n", "v" },
  })

  R.map({
    lhs = "<leader>cr",
    rhs = rename,
    desc = "Rename symbol",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>ci",
    rhs = function()
      if not pcall(vim.lsp.buf.implementation) then
        warn("Go to implementation is not available here.")
      end
    end,
    desc = "Go to implementation",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>ct",
    rhs = function()
      if not pcall(vim.lsp.buf.type_definition) then
        warn("Go to type definition is not available here.")
      end
    end,
    desc = "Go to type definition",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>cd",
    rhs = function()
      vim.diagnostic.open_float({ scope = "line", border = "rounded" })
    end,
    desc = "Show the problem on this line",
    cat = "LSP",
    modes = { "n" },
  })

  -- K already hovers; this is the "I want it in a bordered window" version.
  R.map({
    lhs = "<leader>ch",
    rhs = function()
      if not pcall(vim.lsp.buf.hover, { border = "rounded" }) then
        warn("No hover information here.")
      end
    end,
    desc = "Hover documentation (bordered)",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>cf",
    rhs = format_buffer,
    desc = "Format this buffer",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>co",
    rhs = organize_imports,
    desc = "Organise imports",
    cat = "LSP",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>cl",
    rhs = toggle_codelens,
    desc = "Toggle code lens",
    cat = "LSP",
    modes = { "n" },
  })

  -- -------------------------------------------------------------------------
  -- Commands
  -- -------------------------------------------------------------------------
  R.cmd("Format", function()
    format_buffer()
  end, { desc = "Format the current buffer", cat = "Editing" })

  -- Turn format-on-save off for one buffer (generated files, big JSON...).
  R.cmd("FormatToggle", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.b[bufnr].disable_autoformat = not vim.b[bufnr].disable_autoformat

    if vim.b[bufnr].disable_autoformat then
      U.notify("Format on save: OFF for this buffer", vim.log.levels.WARN)
    else
      U.notify("Format on save: ON for this buffer", vim.log.levels.INFO)
    end
  end, { desc = "Toggle format on save for this buffer", cat = "Editing" })

  R.cmd("LspInfo", function()
    vim.cmd("checkhealth vim.lsp")
  end, { desc = "Show language server status", cat = "LSP" })
end

return M
