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
--   * three themes  -> vscode (default, VS Code Dark), catppuccin, tokyonight
--
-- Keymaps for all of these live in lua/keys/ui.lua (one registry only).
-- This file owns the *plugin specs*: no other file may configure snacks.

-- Close a tab, then show the start screen when the last file is gone. Without
-- this, closing the only tab deletes the buffer and Neovim immediately creates
-- an identical empty [No Name] one, so the X looks like it did nothing.
local function close_tab(bufnr)
  local ok, Snacks = pcall(require, "snacks")
  if ok and Snacks.bufdelete then
    Snacks.bufdelete({ buf = bufnr })
  else
    pcall(vim.cmd, "bdelete " .. bufnr)
  end

  vim.schedule(function()
    local listed, named = 0, 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted then
        listed = listed + 1
        if vim.api.nvim_buf_get_name(buf) ~= "" then
          named = named + 1
        end
      end
    end
    if listed <= 1 and named == 0 then
      pcall(function()
        require("snacks").dashboard({ buf = 0, win = 0 })
      end)
    end
  end)
end

-- Clickable statusline icons: the always-visible version of a VS Code
-- activity bar. They live to the left of the filetype, and each one toggles a
-- panel, so nothing is hidden behind a command or a leader menu.
local function panel_icon(icon, label, fn)
  return {
    function()
      return icon .. " " .. label
    end,
    on_click = function()
      pcall(fn)
    end,
    -- A visible, theme-coloured label: an icon alone is unreadable at
    -- statusline size, and Neovim has no mouse-hover event for tooltips.
    color = "Title",
    padding = { left = 1, right = 0 },
  }
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
-- "vscode" exist even though tokyonight is painted first by the priority spec.
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

      -- The file tree is neo-tree (lua/plugins/nav.lua): it has VS Code's file
      -- operations (a = new file, A = new folder, r = rename, d = delete) and a
      -- git_status view. Leaving snacks' explorer on as well gives you two
      -- trees fighting over netrw, so it stays off.
      explorer = {
        enabled = false,
      },

      -- The start screen: big logo, clickable shortcut buttons, recents.
      --
      -- `tooltip` is not a snacks field: lua/ui/dashboard.lua reads it to draw
      -- the hover window, so every option explains itself without a manual.
      -- Icons are Font Awesome code points: \u{f115} folder-open, \u{f15b}
      -- file, ... and they exist in every Nerd Font.
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            {
              icon = "\u{f115}",
              key = "o",
              desc = "Open folder",
              action = function()
                require("ui.dashboard").open_folder()
              end,
              tooltip = "Browse to a project folder (or type a path with Tab completion) and open it, like File > Open Folder in VS Code.",
            },
            {
              icon = "\u{f15b}",
              key = "n",
              desc = "New file",
              action = function()
                require("ui.dashboard").new_file()
              end,
              tooltip = "Type a file name (Tab completes the path) and start editing it, like File > New File in VS Code.",
            },
            {
              icon = "\u{f002}",
              key = "f",
              desc = "Find file",
              action = ":lua Snacks.picker.files()",
              tooltip = "Search file names in the current project (Cmd+P).",
            },
            {
              icon = "\u{f002}",
              key = "g",
              desc = "Find text",
              action = ":lua Snacks.picker.grep()",
              tooltip = "Search inside every file in the project with ripgrep (Cmd+Shift+F).",
            },
            {
              icon = "\u{f07b}",
              key = "p",
              desc = "Projects",
              action = ":lua Snacks.picker.projects()",
              tooltip = "Switch to another repository in ~/Dev. The working folder changes with it.",
            },
            {
              icon = "\u{f0db}",
              key = "e",
              desc = "Explorer sidebar",
              action = function()
                require("ui.panels").explorer()
              end,
              tooltip = "Show or hide the file tree on the left (Cmd+B). Inside it: a = new file, A = new folder, r = rename, d = delete.",
            },
            {
              icon = "\u{f1d3}",
              key = "t",
              desc = "Git changes",
              action = function()
                require("ui.panels").git_changes()
              end,
              tooltip = "The working-tree changes panel (VS Code's Source Control): modified, added and deleted files.",
            },
            {
              icon = "\u{f086}",
              key = "i",
              desc = "AI panel",
              action = function()
                require("ui.panels").ai_chat(true)
              end,
              tooltip = "Show or hide the AI chat on the right (Cmd+I, or Ctrl+. inside a file).",
            },
            {
              icon = "\u{f013}",
              key = "c",
              desc = "Config",
              action = ":ConfigEdit",
              tooltip = "Edit this Neovim config. It is all Lua and commented.",
            },
            {
              icon = "\u{f059}",
              key = "h",
              desc = "Help",
              action = ":HelpMe",
              tooltip = "Every key and command, generated from what is actually mapped.",
            },
            {
              icon = "\u{f011}",
              key = "q",
              desc = "Quit",
              action = ":qa",
              tooltip = "Close the editor. Unsaved files are never thrown away silently.",
            },
          },
        },
        -- A help circle after every option name. Hovering the name is just
        -- navigation now; only the icon opens the explanation (and clicking it
        -- works too). This is deliberately not a tooltip on the whole row:
        -- that fired constantly while moving the mouse.
        formats = {
          desc = function(item)
            if item.tooltip then
              return {
                { item.desc or "", hl = "desc" },
                { "  ", hl = "comment" },
                { "\u{f059}", hl = "key" },
              }
            end
            return { item.desc or "", hl = "desc" }
          end,
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 0, padding = 1 },
          {
            icon = "\u{f1d3}",
            title = "Git Changes",
            section = "git_changes",
            indent = 2,
            padding = 1,
          },
          {
            icon = "\u{f07b}",
            title = "Recent Files",
            section = "recent_files",
            limit = 3,
            indent = 2,
            padding = 1,
          },
          {
            icon = "\u{f07b}",
            title = "Projects",
            section = "projects",
            limit = 3,
            indent = 2,
            padding = 1,
          },
          {
            align = "center",
            padding = 1,
            text = {
              {
                "Click an item or press Enter  ·  click the  help icon for details  ·  Cmd+Shift+P for everything",
                hl = "footer",
              },
            },
          },
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
    config = function(_, opts)
      require("snacks").setup(opts)

      -- Single-click activation for every list (pickers, trouble, quickfix).
      require("ui.mouse").setup()

      -- Mouse clicks, hover tooltips and "Open folder" on the start screen.
      require("ui.dashboard").setup()

      -- Image files (png/jpg/webp/gif/svg) get a real preview instead of a
      -- buffer full of binary. Optional: the module may not exist yet.
      pcall(function()
        require("ui.image").setup()
      end)
    end,
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
        close_command = close_tab,
        right_mouse_command = close_tab,
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
        -- The mode is a button: click it to jump between NORMAL and INSERT.
        -- Beginner mode starts files in INSERT (lua/ui/mode.lua).
        lualine_a = { require("ui.mode").pill() },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          panel_icon("\u{f015}", "Home", function()
            require("snacks").dashboard()
          end),
          panel_icon("\u{f0db}", "Files", function()
            require("ui.panels").explorer()
          end),
          panel_icon("\u{f002}", "Find", function()
            require("snacks").picker.grep()
          end),
          panel_icon("\u{f1d3}", "Git", function()
            require("ui.source").changes()
          end),
          panel_icon("\u{f188}", "Debug", function()
            require("ui.panels").debug_panel()
          end),
          panel_icon("\u{f086}", "AI", function()
            require("ui.panels").ai_chat(true)
          end),
          lsp_status,
          "filetype",
        },
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
      -- "dark" is VS Code Dark Modern's palette (the one in the screenshots).
      style = "dark",
      transparent = false,
    },
    config = function(_, opts)
      require("vscode").setup(opts)
      -- Paint it immediately: it is the default. theme.load() still restores a
      -- saved choice on VimEnter, so nothing is lost.
      pcall(vim.cmd.colorscheme, "vscode")
    end,
  },
}
