-- lua/plugins/nav.lua
--
-- Plugins that power moving around: the file explorer on the left, a nicer
-- "problems" list, a project-wide search-and-replace screen, and sessions
-- (reopen the files you had open last time).
--
-- The keybindings for all of these live in lua/keys/nav.lua, declared in the
-- registry so they also show up in :HelpMe and KEYBINDINGS.md.

return {
  -- -------------------------------------------------------------------------
  -- neo-tree: the VS Code-style file explorer on the left.
  -- Press Cmd+B (or :Neotree toggle) to show/hide it.
  -- -------------------------------------------------------------------------
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false, -- the explorer should be ready the moment Neovim opens
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      -- If the explorer is the only window left, close Neovim instead of
      -- leaving an empty shell behind.
      close_if_last_window = true,
      enable_git_status = true, -- show modified/added markers next to files
      enable_diagnostics = true, -- show error/warning icons in the tree

      filesystem = {
        -- Move the highlight to whatever file you are editing.
        follow_current_file = { enabled = true },
        -- Pick up files created by other tools (OpenCode!) without restarting.
        use_libuv_file_watcher = true,
        -- Let neo-tree be the default netrw (the built-in :Explore).
        hijack_netrw_behavior = "open_default",
      },

      window = {
        position = "left",
        width = 38,
        mappings = {
          -- One-key habits, plus mouse clicks, so it feels like VS Code's tree.
          ["q"] = "close_window", -- quit the sidebar without quitting Neovim
          ["<CR>"] = "open", -- Enter opens the file or folder
          ["<2-LeftMouse>"] = "open", -- double click also opens, like a file manager
          -- Single click is handled by lua/ui/mouse.lua: it moves the tree
          -- cursor to the clicked node *before* running "open", otherwise a
          -- click on "backend" toggles whichever folder was selected before.
        },
      },
    },
    config = function(_, opts)
      require("neo-tree").setup(opts)

      -- VS Code's explorer toolbar (new file / new folder / refresh / collapse)
      -- and its right-click menu, in lua/ui/.
      require("ui.neotree_bar").setup()
      require("ui.explorer_menu").setup()
    end,
  },

  -- -------------------------------------------------------------------------
  -- trouble: the "problems" and "outline" panels from VS Code.
  -- :Trouble diagnostics / :Trouble symbols, or Cmd+Shift+M.
  -- -------------------------------------------------------------------------
  {
    "folke/trouble.nvim",
    opts = {},
  },

  -- -------------------------------------------------------------------------
  -- grug-far: project-wide find & replace with a preview before you commit.
  -- :GrugFar opens it.
  -- -------------------------------------------------------------------------
  {
    "MagicDuck/grug-far.nvim",
    opts = {},
  },

  -- -------------------------------------------------------------------------
  -- persistence: remember which files and tabs were open, and reopen them.
  -- Commands: :SessionSave, :SessionRestore, :SessionStop
  -- Keys: <leader>qs (restore), <leader>ql (last session), <leader>qd (stop)
  -- -------------------------------------------------------------------------
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
  },
}
