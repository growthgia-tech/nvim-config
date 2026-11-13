-- lua/plugins/lang.lua
--
-- Language-specific tooling:
--   * C# / .NET  -> Roslyn language server (the one server we enable here)
--   * web        -> settings for eslint / html / cssls / emmet / tailwind
--   * JSON       -> SchemaStore catalogue, so json files validate themselves
--   * Python     -> virtualenv picker
--   * tests      -> neotest adapter for .NET
--
-- Rule of this file: we only *describe* servers with vim.lsp.config(). The
-- servers themselves are enabled in lua/plugins/lsp.lua. The single exception
-- is Roslyn: it needs its own plugin to discover the .sln/.csproj tree, so
-- lua/plugins/lsp.lua leaves C# to us.
--
-- Everything here is wrapped in pcall: a broken optional plugin must never
-- stop Neovim from starting.

-- ---------------------------------------------------------------------------
-- Shared server settings
-- ---------------------------------------------------------------------------

---Describe the web servers once, at startup.
---vim.lsp.config() only merges settings onto whatever lua/plugins/lsp.lua
---enables, so calling it for a disabled server costs nothing.
local function configure_web_servers()
  local ok, err = pcall(function()
    -- eslint: find the config file automatically, the way VS Code does.
    vim.lsp.config("eslint", {
      settings = {
        workingDirectory = { mode = "auto" },
      },
    })

    -- html: modern HTML5 completions.
    vim.lsp.config("html", {
      settings = {
        suggest = { html5 = true },
      },
    })

    -- cssls: validate css/scss/less only (no linting surprises elsewhere).
    vim.lsp.config("cssls", {
      settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
      },
    })

    -- Emmet: no settings needed yet; declaring the server here keeps it
    -- visible next to its siblings when this file is read.
    vim.lsp.config("emmet_language_server", {})

    -- tailwindcss: validate class names as you type.
    vim.lsp.config("tailwindcss", {
      settings = {
        tailwindCSS = { validate = true },
      },
    })
  end)

  if not ok then
    vim.notify(
      "lang.lua: could not configure web language servers: " .. tostring(err),
      vim.log.levels.WARN
    )
  end
end

-- ---------------------------------------------------------------------------
-- JSON schemas (SchemaStore)
-- ---------------------------------------------------------------------------

---Give jsonls every schema from the SchemaStore catalogue.
---Returns true when the catalogue could be loaded.
local function configure_json_schemas()
  local ok, schemastore = pcall(require, "schemastore")
  if not ok or type(schemastore) ~= "table" then
    return false
  end

  local ok2 = pcall(function()
    vim.lsp.config("jsonls", {
      settings = {
        json = { schemas = schemastore.json.schemas() },
      },
    })
  end)

  return ok2
end

-- yamlls is intentionally NOT configured here: lua/plugins/lsp.lua already
-- points it at the SchemaStore catalogue URL. Adding settings twice would
-- overwrite that list with an empty one.

-- ---------------------------------------------------------------------------
-- Plugin specs
-- ---------------------------------------------------------------------------

return {
  -- ---- C# / .NET ---------------------------------------------------------
  {
    "seblyng/roslyn.nvim",
    -- Only pay for this when a C# file is actually opened.
    ft = { "cs", "cshtml", "razor" },
    lazy = true,
    -- `auto`: watch the file tree, so adding a project updates the workspace
    -- without restarting Neovim. `broad_search = false`: only look for the
    -- solution near the file you opened.
    opts = { filewatching = "auto", broad_search = false },
    config = function(_, opts)
      -- Settings must exist before the server starts, otherwise the first
      -- attach ignores them.
      pcall(vim.lsp.config, "roslyn", {
        settings = {
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
          },
          ["csharp|code_lens"] = {
            dotnet_enable_tests_code_lens = true,
            dotnet_enable_references_code_lens = true,
          },
        },
      })

      local ok, roslyn = pcall(require, "roslyn")
      if not ok then
        vim.notify("lang.lua: roslyn.nvim failed to load", vim.log.levels.WARN)
        return
      end

      roslyn.setup(opts or {})
      vim.lsp.enable("roslyn")
    end,
  },

  -- ---- JSON SchemaStore ---------------------------------------------------
  {
    "b0o/SchemaStore.nvim",
    lazy = true,
    -- `init` always runs at startup, even though the plugin itself is lazy, so
    -- jsonls has its schema list before any JSON file is opened.
    init = function()
      configure_web_servers()
      configure_json_schemas()
    end,
    -- Second attempt: by the time this runs the plugin is definitely on disk.
    config = function()
      configure_json_schemas()
    end,
  },

  -- ---- Python virtualenv picker ------------------------------------------
  {
    "linux-cultist/venv-selector.nvim",
    -- Loaded the first time you ask for it: no cost on JS/C# days.
    cmd = "VenvSelect",
    opts = {
      settings = {
        -- Search poetry, pipenv, conda, pyenv, ... as well as .venv folders.
        search_venv_managers = true,
      },
    },
  },

  -- ---- Test runner (.NET) -------------------------------------------------
  {
    "nvim-neotest/neotest",
    dependencies = {
      -- The .NET adapter moved out of the nvim-neotest org; this is the
      -- maintained home.
      "Issafalcon/neotest-dotnet",
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
    },
    -- Resolve the adapter lazily (inside the function), so a first launch
    -- without the plugin installed cannot break startup.
    opts = function()
      local adapters = {}
      local ok, adapter = pcall(require, "neotest-dotnet")
      if ok then
        table.insert(adapters, adapter)
      else
        vim.notify("lang.lua: neotest-dotnet unavailable, tests are disabled", vim.log.levels.DEBUG)
      end
      return { adapters = adapters }
    end,
  },

  -- Markdown preview: deliberately omitted. iamcco/markdown-preview.nvim is
  -- stale and needs a manual `yarn install` build step, which breaks the
  -- "clone and go" promise of this config. Use `glow`, a browser, or the
  -- built-in `:terminal` instead.
}
