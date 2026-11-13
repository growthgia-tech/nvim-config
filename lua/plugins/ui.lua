-- lua/plugins/ui.lua
--
-- Everything that makes the editor look and feel like a modern IDE:
--   * snacks.nvim   -> picker (file/text search), file explorer, dashboard,
--                      terminal, notifications, statuscolumn, indent guides
--   * bufferline    -> the row of open file "tabs" at the top
--   * lualine       -> the single status bar at the bottom
--   * which-key     -> the menu that appears after you press Space
--   * dropbar       -> breadcrumb bar inside each window (like VS Code)
--   * mini.nvim     -> icons, auto-pairs, comments, surround, indent scope
--   * three themes  -> tokyonight (default), catppuccin, vscode
--
-- Keymaps for all of these live in lua/keys/ui.lua (one registry only).
-- This file owns the *plugin specs*: no other file may configure snacks.

-- Ask the AI about the current buffer. Guarded: opencode.nvim is optional,
-- and a missing plugin must never take the whole startup down with it.
local function ask_ai()
  local ok, opencode = pcall(require, "opencode")
  if ok and type(opencode.ask) == "function" then
    opencode.ask("@this: ")
  else
    vim.notify("opencode.nvim is not installed", vim.log.levels.WARN)
  end
end

-- The status bar shows the mode in WORDS ("INSERT"), not the single letter
-- Neovim normally uses. vim.fn.mode() can return many codes, so we only look
-- at the first character and let anything unknown fall through.
local function mode_text()
  local code = vim.fn.mode()
  local first = code:sub(1, 1)
  local names = {
    n = "NORMAL",
    i = "INSERT",
    v = "VISUAL",
    V = "VISUAL",
    ["\22"] = "VISUAL BLOCK",
    s = "SELECT",
    S = "SELECT",
    ["\19"] = "SELECT BLOCK",
    c = "COMMAND",
    t = "TERMINAL",
    R = "REPLACE",
    r = "REPLACE",
    ["!"] = "SHELL",
  }
  return " " .. (names[first] or code:upper()) .. " "
end

-- Which language servers are attached to this buffer, e.g. "lua,ts_ls".
local function lsp_status()
  local ok, clients = pcall(vim.lsp.get_clients, { bufnr = 0 })
  if not ok or #clients == 0 then
    return ""
  end
  local names = {}
  for _, client in ipairs(clients) do
    names[#names + 1] = client.name
  end
  return " " .. table.concat(names, ",")
end

-- opencode.nvim's statusline component is optional: pcall means a missing or
-- broken plugin shows an empty string instead of breaking the status bar.
local function opencode_status()
  local ok, opencode = pcall(require, "opencode")
  if not ok or type(opencode.statusline) ~= "function" then
    return ""
  end
  local ok_call, value = pcall(opencode.statusline)
  if not ok_call or type(value) ~= "string" then
    return ""
  end
  return value
end

-- Restore the saved colourscheme once every plugin is available. VimEnter
-- fires after lazy.nvim has loaded all eager plugins, so "catppuccin" and
-- "vscode" exist even though tokyonight is painted first.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local ok, theme = pcall(require, "theme")
    if ok then
      pcall(theme.load)
    end
  end,
})

return {
  -- -------------------------------------------------------------------------
  -- snacks.nvim: pickers, explorer, dashboard, terminal, notifier, ...
  -- priority = 1000 so it is ready before other plugins want its picker.
  -- -------------------------------------------------------------------------
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      -- The picker powers every "find" action in the config.
      picker = {
        enabled = true,
        sources = {
          -- `:lua Snacks.picker.projects()` sees every repo in ~/Dev.
          projects = {
            dev = { "~/Dev" },
          },
          -- The explorer opens as a VS Code style sidebar, without the
          -- preview pane stealing horizontal room from the code.
          explorer = {
            layout = {
              preset = "sidebar",
              preview = false,
            },
          },
        },
      },

      -- Use snacks' explorer as the file tree and stop netrw from opening.
      explorer = {
        enabled = true,
        replace_netrw = true,
      },

      -- The start screen: big logo, clickable shortcut buttons, recents.
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = " ", key = "n", desc = "New file", action = ":ene | startinsert" },
            {
              icon = " ",
              key = "r",
              desc = "Recent files",
              action = ":lua Snacks.picker.recent()",
            },
            { icon = " ", key = "f", desc = "Find file", action = ":lua Snacks.picker.files()" },
            { icon = " ", key = "g", desc = "Find text", action = ":lua Snacks.picker.grep()" },
            { icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
            { icon = " ", key = "a", desc = "Ask AI", action = ask_ai },
            { icon = " ", key = "c", desc = "Config", action = ":ConfigEdit" },
            { icon = " ", key = "h", desc = "Help", action = ":HelpMe" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
          { section = "startup" },
        },
      },

      -- A real terminal panel (the config uses it for build/test tasks).
      terminal = {
        enabled = true,
      },

      -- Notification toasts in the top-right corner.
      notifier = {
        enabled = true,
        timeout = 3000,
      },

      -- The left gutter (line numbers + decorations, like VS Code).
      statuscolumn = {
        enabled = true,
      },

      -- Vertical guide lines for each indentation level.
      indent = {
        enabled = true,
      },

      -- Smooth scrolling and cursor animation.
      scroll = {
        enabled = true,
      },

      -- Highlight the word under the cursor and its other occurrences.
      words = {
        enabled = true,
      },

      -- vim.ui.input / vim.ui.select become nice floating windows.
      input = {
        enabled = true,
      },

      -- Cmd+G style git UI (explorer, staging, commit).
      lazygit = {
        enabled = true,
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- bufferline.nvim: the "open tabs" strip across the top.
  -- -------------------------------------------------------------------------
  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    opts = {
      options = {
        -- Show LSP errors/warnings on each tab.
        diagnostics = "nvim_lsp",
        show_buffer_close_icons = true,
        show_close_icon = true,
        -- Closing with the mouse or the X really deletes the buffer, so the
        -- tab disappears instead of hiding an empty buffer.
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        modified_icon = "● ",
        indicator = {
          style = "icon",
          icon = "▎",
        },
        -- If the drawer-style explorer is open, label it in the tab strip.
        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            separator = true,
          },
        },
        always_show_bufferline = true,
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- lualine.nvim: the bottom status bar.
  -- -------------------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true, -- one bar for the whole editor
        section_separators = "",
        component_separators = "│",
        icons_enabled = true,
      },
      sections = {
        lualine_a = { mode_text },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { lsp_status, "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location", opencode_status },
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- which-key.nvim: press Space, wait 250ms, a menu explains every key.
  -- The group names come from the registry, so they can never go out of date.
  -- -------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 250,
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add(require("config.registry").which_key_spec())
    end,
  },

  -- -------------------------------------------------------------------------
  -- dropbar.nvim: breadcrumbs at the top of each window.
  -- Keys: <leader>;  pick a symbol,  [;  parent scope,  ];  next sibling.
  -- -------------------------------------------------------------------------
  {
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
    config = function(_, opts)
      require("dropbar").setup(opts)
    end,
  },

  -- -------------------------------------------------------------------------
  -- mini.nvim: one spec, because two files cannot own the same plugin.
  -- Provides: icons, auto-pairs, comments, surround and indent guides.
  --
  -- The editing keymaps (gc / gcc, sa / sd / sr) are provided by
  -- MiniComment and MiniSurround; lua/keys/edit.lua only documents them.
  -- -------------------------------------------------------------------------
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      -- Icons for filetypes, used by bufferline/lualine/snacks.
      require("mini.icons").setup()
      -- Make every plugin that asks for "nvim-web-devicons" use mini.icons.
      require("mini.icons").mock_nvim_web_devicons()

      -- Type `(` and get `()` with the cursor in the middle.
      require("mini.pairs").setup()

      -- gc / gcc to comment lines (works without any other plugin).
      require("mini.comment").setup()

      -- sa / sd / sr to add, delete and replace brackets/quotes.
      require("mini.surround").setup()

      -- Indentation guide lines. The `scope` shows the current block.
      require("mini.indentscope").setup({ symbol = "│" })
    end,
  },

  -- -------------------------------------------------------------------------
  -- Themes. All three are installed eagerly so :Theme can switch instantly;
  -- only tokyonight is applied at startup. The saved choice is restored by
  -- lua/theme.lua on VimEnter.
  -- -------------------------------------------------------------------------
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      style = "night",
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      -- Paint something immediately; theme.load() re-applies the saved theme
      -- once every plugin is available (on VimEnter).
      pcall(vim.cmd.colorscheme, "tokyonight")
    end,
  },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    opts = {
      flavour = "mocha",
    },
  },

  {
    "Mofiqul/vscode.nvim",
    name = "vscode",
    lazy = false,
    opts = {
      style = "dark",
      transparent = false,
    },
  },
}
