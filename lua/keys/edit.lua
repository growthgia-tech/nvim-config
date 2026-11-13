-- lua/keys/edit.lua
--
-- Everyday editing shortcuts, declared through the registry so they show up in
-- which-key, :HelpMe and KEYBINDINGS.md automatically.
--
-- The multicursor keys and the tree-sitter text objects are NOT here: they are
-- plugin-specific (layers, operator-pending modes) and live in
-- lua/plugins/edit.lua. Everything below is a plain global mapping.

local M = {}

function M.setup(R)
  -- -------------------------------------------------------------------------
  -- Move / duplicate the current line with Option+Arrow, like VS Code.
  --
  -- Both helpers work in normal, visual and insert mode. In visual mode they
  -- act on the whole selection, in insert mode you stay in insert mode, so
  -- nothing about your typing is interrupted.
  -- -------------------------------------------------------------------------

  -- Feed a key sequence as if you had typed it (termcodes turn "<CR>" into a
  -- real Enter key). "n" = do not remap, so our own maps cannot recurse.
  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
  end

  local function move_lines(up)
    return function()
      local mode = vim.api.nvim_get_mode().mode
      if mode:match("^[vV\22]") then
        -- Visual: move the selection, then keep it selected (gv) and re-indent.
        feed(up and ":m '<-2<CR>gv=gv" or ":m '>+1<CR>gv=gv")
      elseif mode == "i" then
        -- Insert: <C-o> runs exactly one normal command, then you are typing
        -- again. No leaving insert mode, no lost keystrokes.
        feed(up and "<C-o>:m .-2<CR>" or "<C-o>:m .+1<CR>")
      else
        -- Normal: ":m" is Vim's built-in "cut this line, paste it there".
        feed(up and ":m .-2<CR>==" or ":m .+1<CR>==")
      end
    end
  end

  R.map({
    lhs = "<M-Up>",
    rhs = move_lines(true),
    desc = "Move line (or selection) up",
    cat = "Editing",
    modes = { "n", "i", "v" },
  })

  R.map({
    lhs = "<M-Down>",
    rhs = move_lines(false),
    desc = "Move line (or selection) down",
    cat = "Editing",
    modes = { "n", "i", "v" },
  })

  -- Duplicate = copy the line/selection and leave the cursor on the copy, so
  -- you can keep typing the next variant straight away.
  local function duplicate_lines(up)
    return function()
      local mode = vim.api.nvim_get_mode().mode
      if mode:match("^[vV\22]") then
        -- Visual: copy the block, then select the fresh copy. `[ and `] are
        -- the marks Vim sets around the text it just copied.
        feed(up and ":t '<-1<CR>`[V`]" or ":t '><CR>`[V`]")
      elseif mode == "i" then
        feed(up and "<C-o>:t .-1<CR>" or "<C-o>:t .<CR>")
      else
        feed(up and ":t .-1<CR>==" or ":t .<CR>==")
      end
    end
  end

  R.map({
    lhs = "<M-S-Up>",
    rhs = duplicate_lines(true),
    desc = "Duplicate line (or selection) up",
    cat = "Editing",
    modes = { "n", "i", "v" },
  })

  R.map({
    lhs = "<M-S-Down>",
    rhs = duplicate_lines(false),
    desc = "Duplicate line (or selection) down",
    cat = "Editing",
    modes = { "n", "i", "v" },
  })

  -- -------------------------------------------------------------------------
  -- <leader>u = "toggles". Muscle memory from VS Code: turn a view on/off
  -- without hunting through a menu. These are window options, so the change
  -- applies to the split you are in right now.
  -- -------------------------------------------------------------------------

  -- Only claim the which-key group label if nobody else already did, so this
  -- file cannot stomp on another module's group name.
  if R.wk_groups["<leader>u"] == nil then
    R.group("<leader>u", "Toggle")
  end

  R.map({
    lhs = "<leader>uz",
    rhs = function()
      vim.wo.wrap = not vim.wo.wrap
      vim.notify("Soft wrap: " .. (vim.wo.wrap and "on" or "off"), vim.log.levels.INFO)
    end,
    desc = "Toggle soft wrap",
    cat = "Toggle",
  })

  R.map({
    lhs = "<leader>us",
    rhs = function()
      vim.wo.spell = not vim.wo.spell
      if vim.wo.spell then
        vim.opt.spelllang = "en_us"
      end
      vim.notify("Spell check: " .. (vim.wo.spell and "on" or "off"), vim.log.levels.INFO)
    end,
    desc = "Toggle spell check",
    cat = "Toggle",
  })

  R.map({
    lhs = "<leader>ui",
    rhs = function()
      -- mini.nvim draws the indent guides; if that plugin is missing (or still
      -- installing) say so instead of throwing an error.
      local ok, _ = pcall(require, "mini.indentscope")
      if not ok then
        vim.notify("Indent guides need mini.nvim", vim.log.levels.WARN)
        return
      end
      vim.g.miniindentscope_disable = not vim.g.miniindentscope_disable
      vim.notify(
        "Indent guides: " .. (vim.g.miniindentscope_disable and "off" or "on"),
        vim.log.levels.INFO
      )
    end,
    desc = "Toggle indent guides",
    cat = "Toggle",
  })

  R.map({
    lhs = "<leader>uc",
    rhs = function()
      -- conceallevel 0 = show everything, 2 = hide the markup (markdown links,
      -- JSON quotes...). Beginners get confused by invisible characters, so
      -- toggling is explicit rather than automatic.
      vim.wo.conceallevel = vim.wo.conceallevel == 0 and 2 or 0
      vim.notify("Conceal: level " .. vim.wo.conceallevel, vim.log.levels.INFO)
    end,
    desc = "Toggle concealed markup",
    cat = "Toggle",
  })
end

return M
