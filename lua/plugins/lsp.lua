-- lua/plugins/lsp.lua
--
-- Language support, end to end. Five jobs, five plugins:
--
--   mason.nvim                installs the tools (servers, formatters, linters)
--   mason-lspconfig.nvim      keeps language servers installed + enabled
--   mason-tool-installer      keeps formatters/linters/debuggers installed
--   blink.cmp                 completes as you type
--   conform.nvim              formats on save
--   nvim-lint                 shows linter warnings in the gutter
--
-- Important for Neovim 0.12: `require("lspconfig").server.setup{}` is gone.
-- Neovim itself starts servers through vim.lsp.config() + vim.lsp.enable().
-- nvim-lspconfig is still needed because it ships the lsp/<name>.lua files.

-- Every language server we want. Keep this list in one place: mason installs
-- it, and Neovim enables exactly the same list below.
-- Note: "roslyn" (C#) is NOT here. seblyng/roslyn.nvim in lua/plugins/lang.lua
-- owns it, and it installs its own up-to-date server.
local servers = {
  "basedpyright", -- Python types / imports
  "ruff", -- Python lint + quick fixes
  "vtsls", -- TypeScript / JavaScript
  "eslint", -- JS/TS lint as you type
  "html",
  "cssls",
  "emmet_language_server", -- HTML/CSS abbreviations
  "tailwindcss",
  "bashls", -- shell scripts
  "terraformls",
  "jsonls",
  "yamlls",
  "lua_ls", -- this config itself
  "marksman", -- Markdown
}

-- ---------------------------------------------------------------------------
-- The LSP wiring. Runs once, when nvim-lspconfig loads.
-- ---------------------------------------------------------------------------

-- blink gives the server extra completion abilities (snippets, "isIncomplete"
-- handling...). If blink is not loaded yet we use plain Neovim capabilities.
local function capabilities()
  local ok, blink = pcall(require, "blink.cmp")
  if ok and type(blink.get_lsp_capabilities) == "function" then
    local ok2, caps = pcall(blink.get_lsp_capabilities)
    if ok2 and caps then
      return caps
    end
  end
  return vim.lsp.protocol.make_client_capabilities()
end

-- Runs for every server that attaches to a buffer.
local function on_attach(client, bufnr)
  -- Highlight the other places the symbol under the cursor appears.
  if client:supports_method("textDocument/documentHighlight") then
    pcall(function()
      vim.lsp.document_highlight.enable(true, { bufnr = bufnr })
    end)
  end

  -- Small grey hints inside the code ("arg: string", "3 references", ...).
  if client:supports_method("textDocument/inlayHint") then
    pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
  end
end

---Configure + start every server. Called from nvim-lspconfig's config.
local function setup_lsp()
  -- PATH was already repaired at startup (lua/config/platform.lua), which is
  -- what puts Mason's bin/ directory in front of an old system python3 and
  -- makes a Finder-launched Neovide able to find ripgrep at all.
  -- "*" = settings shared by every language server.
  vim.lsp.config("*", {
    capabilities = capabilities(),
    on_attach = on_attach,
  })

  -- Per-server tweaks. Only the few that matter on day one.
  vim.lsp.config("vtsls", {
    settings = {
      typescript = {
        -- Moving a file updates the imports that point at it (VS Code does).
        updateImportsOnFileMove = { enabled = "always" },
      },
    },
  })

  vim.lsp.config("yamlls", {
    settings = {
      yaml = {
        -- Known-files schemas: GitHub Actions, docker-compose, k8s, ...
        schemaStore = {
          enable = true,
          url = "https://www.schemastore.org/api/json/catalog.json",
        },
      },
    },
  })

  vim.lsp.config("tailwindcss", {
    settings = { tailwindCSS = { validate = true } },
  })

  vim.lsp.config("basedpyright", {
    settings = {
      basedpyright = {
        analysis = { typeCheckingMode = "basic" },
      },
    },
  })

  -- Start them all. vim.lsp.enable is idempotent: mason-lspconfig also calls
  -- it for installed servers, and that is fine.
  pcall(vim.lsp.enable, servers)
end

return {
  -- -------------------------------------------------------------------------
  -- Mason: the tool installer. :Mason opens the UI.
  -- -------------------------------------------------------------------------
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonLog" },
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        -- Community registry: has a current `roslyn` for lua/plugins/lang.lua.
        "github:Crashdummyy/mason-registry",
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- Mason <-> LSP bridge. Version 2: `ensure_installed` is REQUIRED, because
  -- nothing installs automatically any more.
  -- -------------------------------------------------------------------------
  {
    "mason-org/mason-lspconfig.nvim",
    event = "VeryLazy",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = servers,
      -- Start servers automatically, except roslyn (roslyn.nvim owns it).
      automatic_enable = { exclude = { "roslyn", "roslyn_ls" } },
    },
  },

  -- -------------------------------------------------------------------------
  -- nvim-lspconfig: ships the lsp/*.lua server definitions, and hosts the
  -- wiring above in its config function.
  -- -------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    -- BufReadPre, not VeryLazy: the server definitions must exist by the time
    -- the first file is read, or the first buffer opens without completion
    -- until you wipe it and reopen.
    event = { "BufReadPre", "BufNewFile" },
    -- blink must be loaded first: its completion capabilities are handed to
    -- every server. If it is not there, setup_lsp() falls back safely.
    dependencies = { "saghen/blink.cmp" },
    config = setup_lsp,
  },

  -- -------------------------------------------------------------------------
  -- Non-LSP tools: formatters, linters, debug adapters.
  -- -------------------------------------------------------------------------
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        -- Roslyn itself: the community registry ships a current build, and
        -- roslyn.nvim refuses anything older. Installing it here means C# is a
        -- one-command setup instead of "go read the roslyn.nvim README".
        "roslyn",
        "csharpier", -- C# formatter (roslyn.nvim also formats, this is a backup)
        "netcoredbg", -- C# debugger
        "debugpy", -- Python debugger
        "js-debug-adapter", -- JS/TS debugger
        "stylua", -- Lua formatter
        "shellcheck", -- shell linter
        "shfmt", -- shell formatter
        "tflint", -- Terraform linter
        "prettier", -- web formatter
      },
      auto_update = false,
      run_on_start = true,
    },
  },

  -- -------------------------------------------------------------------------
  -- Completion. blink.cmp v1 is the stable line: v2 changes the API.
  -- Keys: Tab jumps between snippet fields, Enter accepts, Ctrl+Space opens.
  -- -------------------------------------------------------------------------
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "enter" },
      completion = {
        -- Do not pop the docs panel on every keystroke, do not pre-select.
        documentation = { auto_show = false },
        list = { selection = { preselect = false } },
      },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },

  -- -------------------------------------------------------------------------
  -- Format on save (and <leader>cf / :Format on demand).
  -- -------------------------------------------------------------------------
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        python = { "ruff_fix", "ruff_format" }, -- fix imports, then format
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
        terraform = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
        lua = { "stylua" },
      },
      -- Returning nil means "do not format this time".
      format_on_save = function(bufnr)
        -- :FormatToggle turns this off for one buffer.
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 500, lsp_format = "fallback" }
      end,
    },
  },

  -- -------------------------------------------------------------------------
  -- Linting in the background (no server needed: runs the CLI tools).
  -- -------------------------------------------------------------------------
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        javascript = { "eslint" },
        javascriptreact = { "eslint" },
        typescript = { "eslint" },
        typescriptreact = { "eslint" },
        python = { "ruff" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        zsh = { "shellcheck" },
        terraform = { "tflint" },
      }

      local group = vim.api.nvim_create_augroup("user_nvim_lint", { clear = true })

      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = group,
        callback = function()
          -- Never lint scratch/help/terminal buffers, and only real files.
          if vim.bo.buftype ~= "" then
            return
          end
          local name = vim.api.nvim_buf_get_name(0)
          if name == "" or vim.fn.filereadable(name) == 0 then
            return
          end

          -- pcall: a missing linter binary must never throw an error popup.
          pcall(function()
            lint.try_lint()
          end)
        end,
      })
    end,
  },
}
