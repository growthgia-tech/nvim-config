-- lua/plugins/edit.lua
--
-- The power tools that make editing feel like VS Code but smarter:
--   * tree-sitter      -> real syntax awareness (colours + smart selection)
--   * textobjects      -> "select this whole function" instead of guessing
--   * multicursor      -> type once, change many places at once
--   * autotag          -> closing HTML/JSX tags write themselves
--
-- Nothing here touches global keymaps: those live in lua/keys/edit.lua and go
-- through the registry (R.map). The three plugins below need keymaps that the
-- registry cannot express (visual/operator-pending object maps, and keymaps
-- that only exist while several cursors are active), so they are declared in
-- their own config functions. That is the only permitted exception.

return {
  -- -------------------------------------------------------------------------
  -- 1. Tree-sitter: the parser engine behind syntax highlighting and the
  --    text objects. Branch "main" is the Neovim 0.12 rewrite: parsers are
  --    installed by calling install(), not through a config table.
  -- -------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- tree-sitter must be there from the first buffer
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")

      -- Empty table = sensible defaults (parsers land in stdpath("data")/site).
      ts.setup({})

      -- Every language this setup actually opens. "query" + "vimdoc" make
      -- Neovim's own help and query files highlight properly too.
      local parsers = {
        "lua",
        "vim",
        "vimdoc",
        "query",
        "bash",
        "c_sharp",
        "css",
        "html",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "yaml",
        "toml",
        "markdown",
        "markdown_inline",
        "python",
        "terraform",
        "hcl",
        "regex",
        "diff",
        "gitcommit",
      }

      -- install() downloads and compiles in the BACKGROUND. On the very first
      -- launch you will see no colours for a few seconds (or a minute on a
      -- slow connection) while the C parsers build. That is expected, not
      -- broken: reopen the file later and the colours are there.
      local ok, err = pcall(ts.install, parsers)
      if not ok then
        vim.notify(
          "Tree-sitter parsers could not be queued: " .. tostring(err),
          vim.log.levels.WARN
        )
      end

      -- Neovim 0.12 does not switch highlighting on by itself: you have to ask
      -- per buffer. Do it on FileType so every freshly opened file gets it.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
        callback = function(args)
          -- Huge files stay on the fast regex engine (see config/autocmds.lua).
          if vim.b[args.buf].bigfile then
            return
          end
          pcall(vim.treesitter.start, args.buf)
        end,
        desc = "Turn on tree-sitter highlighting for supported filetypes",
      })
    end,
  },

  -- -------------------------------------------------------------------------
  -- 2. Text objects: "af" = a function, "ac" = a class, "aa" = a parameter.
  --    Why the keymaps live here: these are visual-mode and operator-pending
  --    maps ("daf", "vif"). The registry (R.map) has no notion of
  --    operator-pending mode, so vim.keymap.set in this config is the correct
  --    -- and only -- place for them.
  -- -------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          -- Jump forward to the next object instead of failing when the
          -- cursor is just before it, like the targets.vim plugin.
          lookahead = true,
        },
        move = {
          -- ]f / [f should be remembered by <C-o>, like real jumps.
          set_jumps = true,
        },
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")

      -- A missing parser would otherwise throw a scary Lua error at you.
      -- Instead: say the object is not available in this file and carry on.
      local function guard(fn)
        return function()
          local ok, err = pcall(fn)
          if not ok then
            vim.notify(
              "Text object not available here: " .. tostring(err),
              vim.log.levels.WARN
            )
          end
        end
      end

      -- af / if  = around / inside a function
      vim.keymap.set({ "x", "o" }, "af", guard(function()
        select.select_textobject("@function.outer", "textobjects")
      end), { desc = "Select a whole function" })

      vim.keymap.set({ "x", "o" }, "if", guard(function()
        select.select_textobject("@function.inner", "textobjects")
      end), { desc = "Select the body of a function" })

      -- ac / ic  = around / inside a class
      vim.keymap.set({ "x", "o" }, "ac", guard(function()
        select.select_textobject("@class.outer", "textobjects")
      end), { desc = "Select a whole class" })

      vim.keymap.set({ "x", "o" }, "ic", guard(function()
        select.select_textobject("@class.inner", "textobjects")
      end), { desc = "Select the body of a class" })

      -- aa / ia  = around / inside a parameter (one argument of a call)
      vim.keymap.set({ "x", "o" }, "aa", guard(function()
        select.select_textobject("@parameter.outer", "textobjects")
      end), { desc = "Select a parameter" })

      vim.keymap.set({ "x", "o" }, "ia", guard(function()
        select.select_textobject("@parameter.inner", "textobjects")
      end), { desc = "Select the inside of a parameter" })

      -- Movement: ]f next function, [f previous function, ]c/[c for classes.
      vim.keymap.set({ "n", "x", "o" }, "]f", guard(function()
        move.goto_next_start("@function.outer", "textobjects")
      end), { desc = "Jump to the next function" })

      vim.keymap.set({ "n", "x", "o" }, "[f", guard(function()
        move.goto_previous_start("@function.outer", "textobjects")
      end), { desc = "Jump to the previous function" })

      vim.keymap.set({ "n", "x", "o" }, "]c", guard(function()
        move.goto_next_start("@class.outer", "textobjects")
      end), { desc = "Jump to the next class" })

      vim.keymap.set({ "n", "x", "o" }, "[c", guard(function()
        move.goto_previous_start("@class.outer", "textobjects")
      end), { desc = "Jump to the previous class" })
    end,
  },

  -- -------------------------------------------------------------------------
  -- 3. Multiple cursors, the VS Code way: Cmd+D selects the next copy of the
  --    word under the cursor, and everything you type lands in every copy.
  --    Why the keymaps live here: half of them only make sense while extra
  --    cursors exist, which is a plugin-specific "layer". The registry has no
  --    concept of conditional layers, so vim.keymap.set is used here.
  -- -------------------------------------------------------------------------
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      -- Cmd+D = "add a cursor on the next match", exactly like VS Code.
      -- Works in normal mode and while a word/selection is highlighted.
      set({ "n", "x" }, "<D-d>", function()
        mc.matchAddCursor(1)
      end, { desc = "Add cursor on next match" })

      -- Ctrl+D only in visual mode: there it does not steal half-page scroll.
      set("x", "<C-d>", function()
        mc.matchAddCursor(1)
      end, { desc = "Add cursor on next match (visual)" })

      -- Cmd+Shift+L = "a cursor on every match in the file" (VS Code's
      -- "select all occurrences"). Both spellings are declared because some
      -- terminals/Neovide report the capital letter as <D-L> instead of
      -- <D-S-l>.
      local function add_all_cursors()
        mc.matchAllAddCursors()
      end

      set({ "n", "x" }, "<D-S-l>", add_all_cursors, { desc = "Add a cursor on every match" })
      set({ "n", "x" }, "<D-L>", add_all_cursors, { desc = "Add a cursor on every match" })

      -- Ctrl+Q freezes the extra cursors so only the main one moves; press it
      -- again to wake them up. Great for checking what you are about to edit.
      set({ "n", "x" }, "<C-q>", mc.toggleCursor, { desc = "Pause / resume extra cursors" })

      -- Ctrl+click adds and removes cursors, like a mouse-driven VS Code.
      set("n", "<C-leftmouse>", mc.handleMouse, { desc = "Add a cursor with Ctrl+click" })
      set("n", "<C-leftdrag>", mc.handleMouseDrag, { desc = "Add cursors by Ctrl+dragging" })
      set("n", "<C-leftrelease>", mc.handleMouseRelease, { desc = "Finish Ctrl+drag selection" })

      -- The layer: these keys only apply while several cursors are alive, so
      -- they never shadow normal editing.
      mc.addKeymapLayer(function(layerSet)
        -- Esc collapses back to one cursor (the registry's Esc still clears
        -- the search highlight when you have only one cursor).
        layerSet("n", "<esc>", mc.clearCursors, { desc = "Back to a single cursor" })

        -- Left / right rotate which cursor is the "main" one.
        layerSet("n", "<left>", mc.prevCursor, { desc = "Previous cursor" })
        layerSet("n", "<right>", mc.nextCursor, { desc = "Next cursor" })

        -- Delete the main cursor only.
        layerSet("n", "<leader>x", mc.deleteCursor, { desc = "Delete this cursor" })
      end)

      -- Colours for the extra cursors, matched to a normal-looking editor.
      local hl = vim.api.nvim_set_hl
      hl(0, "MultiCursorCursor", { reverse = true })
      hl(0, "MultiCursorVisual", { link = "Visual" })
      hl(0, "MultiCursorSign", { link = "SignColumn" })
      hl(0, "MultiCursorMatchPreview", { link = "Search" })
      hl(0, "MultiCursorDisabledCursor", { reverse = true })
      hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
      hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
    end,
  },

  -- -------------------------------------------------------------------------
  -- 4. Auto-closing tags for HTML/JSX/XML: type </ and the tag name appears.
  -- -------------------------------------------------------------------------
  {
    "windwp/nvim-ts-autotag",
    opts = {},
  },
}
