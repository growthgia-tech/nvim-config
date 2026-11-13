-- lua/keys/nav.lua
--
-- Navigation shortcuts: quick open, search, the file explorer, terminals, the
-- problems list and a right-click menu that behaves like VS Code's.
--
-- Every shortcut is declared once with R.map / R.cmd so that :HelpMe,
-- which-key and KEYBINDINGS.md all stay up to date automatically.

local M = {}

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

---Return the snacks module, or nil when it is not loaded yet.
local function snacks()
  local ok, mod = pcall(require, "snacks")
  if ok and mod and mod.picker then
    return mod
  end
  return nil
end

---Open one of the snacks pickers by name, e.g. pick("files").
local function pick(what, opts)
  local S = snacks()
  if not S then
    vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
    return
  end
  local fn = S.picker[what]
  if type(fn) ~= "function" then
    vim.notify("Snacks.picker." .. what .. " is not available", vim.log.levels.WARN)
    return
  end

  local picker = fn(opts)

  -- VS Code: typing ">" in Quick Open switches to the command palette.
  if what == "files" or what == "recent" then
    pcall(function()
      require("ui.quickopen").watch(picker)
    end)
  end
  return picker
end

---Turn a value that may be a string or a list of keys into one readable line.
-- ---------------------------------------------------------------------------
-- Command palette (Cmd+Shift+P)
--
-- One search box that lists BOTH Vim commands (":write") and keybindings
-- ("Cmd+S  Save file"). Picking a command runs it; picking a keybinding presses
-- the key for you, so you see exactly what it does.
--
-- The list is built from the registry plus Neovim's command table, rather than
-- from snacks' own vim_commands/vim_keymaps sources: those two expect per-source
-- options that a combined finder does not pass, which made the palette throw.
-- Building the items ourselves is also what makes the descriptions match
-- :HelpMe word for word.
-- ---------------------------------------------------------------------------
local function command_palette()
  local S = snacks()
  if not S then
    vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
    return
  end

  local ok_help, help = pcall(require, "help")
  local pretty = ok_help and help.pretty_key or function(k)
    return k
  end

  local items = {}
  local seen_cmd = {}

  -- 1. Everything declared in lua/config/registry.lua.
  local ok_registry, R = pcall(require, "config.registry")
  if ok_registry then
    for _, row in ipairs(R.help_rows()) do
      if row.kind == "cmd" then
        local name = row.key:gsub("^:", "")
        seen_cmd[name] = true
        table.insert(items, {
          -- The leading ">" is invisible (stripped in format); it exists so
          -- that typing ">" in the palette matches commands and not keymaps,
          -- exactly like VS Code. This survives fuzzy matching where a
          -- filter-transform would fight the next keystroke.
          text = ">" .. row.key .. "  " .. (row.desc or ""),
          cmd = name,
          desc = row.desc,
          cat = row.cat,
          kind = "command",
        })
      else
        table.insert(items, {
          text = pretty(row.key) .. "  " .. (row.desc or ""),
          key = row.key,
          desc = row.desc,
          cat = row.cat,
          modes = row.mode,
          kind = "key",
        })
      end
    end
  end

  -- 2. Commands Neovim or plugins define outside the registry, so the palette
  -- is still a complete ":command" list.
  for name, def in pairs(vim.api.nvim_get_commands({})) do
    if not seen_cmd[name] then
      table.insert(items, {
        text = ">" .. ":" .. name .. "  " .. (def.definition or ""),
        cmd = name,
        desc = def.definition or name,
        cat = "Commands",
        kind = "command",
      })
    end
  end

  table.sort(items, function(a, b)
    if a.cat ~= b.cat then
      return a.cat < b.cat
    end
    return a.text < b.text
  end)

  S.picker.pick({
    title = "Command Palette",
    -- A static finder: no re-scanning, and nothing to misconfigure.
    finder = function()
      return items
    end,

    format = function(item)
      local mode = item.modes and item.modes ~= "" and ("[" .. item.modes .. "] ") or ""
      local label = item.kind == "command" and " › " or (mode .. "› ")
      -- Strip the invisible ">" prefix that gives commands their own search
      -- space (see where the items are built).
      return {
        { label, "SnacksPickerComment" },
        { (item.text or ""):gsub("^>", ""), "SnacksPickerFile" },
      }
    end,

    confirm = function(picker, item)
      if not item then
        return
      end
      pcall(function()
        picker:close()
      end)
      -- Schedule: never run a command or press keys while the picker is busy.
      vim.schedule(function()
        if item.cmd then
          pcall(vim.cmd, item.cmd)
        elseif item.key then
          pcall(vim.api.nvim_input, item.key)
        end
      end)
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Explorer / terminal / problems
-- ---------------------------------------------------------------------------
local function toggle_sidebar()
  require("ui.panels").explorer()
end

local function toggle_terminal()
  local S = snacks()
  if S and S.terminal then
    S.terminal() -- snacks remembers the terminal and toggles it for you
  else
    vim.cmd("botright split | terminal")
  end
end

---Toggle a trouble.nvim panel. Returns true when trouble handled it.
local function trouble_toggle(opts)
  local ok, trouble = pcall(require, "trouble")
  if ok and type(trouble.toggle) == "function" then
    if pcall(trouble.toggle, opts) then
      return true
    end
  end
  return false
end

---The problems panel, with a picker fallback when trouble is not installed.
local function problems()
  if not trouble_toggle({ mode = "diagnostics", focus = true }) then
    pick("diagnostics")
  end
end

local function symbols_panel()
  if not trouble_toggle({ mode = "symbols", focus = true }) then
    pick("lsp_symbols")
  end
end

-- ---------------------------------------------------------------------------
-- Right-click context menu (hand-rolled, no plugin)
--
-- A small floating list appears where you clicked. <CR> runs the highlighted
-- action, q or Esc closes it, a click selects a line and a double click runs.
-- ---------------------------------------------------------------------------
local function context_menu()
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 then
    return -- the click was on a statusline, a border or empty space
  end

  -- Move to where the user actually clicked before offering the actions.
  pcall(vim.api.nvim_set_current_win, mouse.winid)
  pcall(vim.api.nvim_win_set_cursor, 0, { mouse.line, math.max(mouse.column - 1, 0) })

  local items = {
    {
      name = "Go to Definition",
      run = function()
        vim.lsp.buf.definition()
      end,
    },
    {
      name = "Find References",
      run = function()
        vim.lsp.buf.references()
      end,
    },
    {
      name = "Rename Symbol",
      run = function()
        vim.lsp.buf.rename()
      end,
    },
    {
      name = "Code Action",
      run = function()
        vim.lsp.buf.code_action()
      end,
    },
    {
      name = "Format Document",
      run = function()
        pcall(vim.cmd, "Format")
      end,
    },
    {
      name = "Find in Files",
      run = function()
        pick("grep_word")
      end,
    },
    {
      name = "Ask OpenCode about this",
      run = function()
        local ok, oc = pcall(require, "opencode")
        if ok and type(oc.ask) == "function" then
          oc.ask("@this: ")
        else
          vim.notify("OpenCode is not loaded (try :Ask)", vim.log.levels.WARN)
        end
      end,
    },
    {
      name = "Copy",
      run = function()
        vim.api.nvim_input('"+yy')
      end,
    },
    {
      name = "Paste",
      run = function()
        vim.api.nvim_input('"+p')
      end,
    },
    {
      name = "Split Right",
      run = function()
        vim.cmd("vsplit")
      end,
    },
    {
      name = "Close Tab",
      run = function()
        require("config.util").close_buffer()
      end,
    },
  }

  local lines = {}
  for _, item in ipairs(items) do
    lines[#lines + 1] = " " .. item.name
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Put the menu where the click happened; nvim expects 0-based coordinates.
  -- Clamp it so a click near the screen edge does not push the menu off-screen.
  local row = math.min(math.max(mouse.screenrow - 1, 0), math.max(vim.o.lines - #items - 3, 0))
  local col = math.min(math.max(mouse.screencol - 1, 0), math.max(vim.o.columns - 36, 0))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = 34,
    height = #items,
    style = "minimal",
    border = "rounded",
    title = " Actions ",
    title_pos = "left",
    zindex = 250,
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  local function run_current()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local item = items[lnum]
    close()
    if item then
      vim.schedule(item.run)
    end
  end

  local function select_line()
    local m = vim.fn.getmousepos()
    if m.winid == win and m.line >= 1 and m.line <= #items then
      pcall(vim.api.nvim_win_set_cursor, win, { m.line, 0 })
    end
  end

  -- These keymaps are buffer-local: they only live inside the menu.
  vim.keymap.set("n", "<CR>", run_current, { buffer = buf, desc = "Run action" })
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Close menu" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Close menu" })
  -- One click runs the action, like a native menu (double click still works).
  vim.keymap.set("n", "<LeftMouse>", function()
    select_line()
    run_current()
  end, { buffer = buf, desc = "Run clicked action" })
  vim.keymap.set("n", "<2-LeftMouse>", function()
    select_line()
    run_current()
  end, { buffer = buf, desc = "Run clicked action" })

  -- Clicking somewhere else simply closes the menu.
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = close,
    desc = "Close the context menu when it loses focus",
  })
end

-- ---------------------------------------------------------------------------
-- Setup: declare everything through the registry
-- ---------------------------------------------------------------------------
function M.setup(R)
  -- Group labels for which-key, so pressing Space f shows a named menu.
  R.group("<leader>f", "Find")
  R.group("<leader>x", "Problems")
  R.group("<leader>q", "Session")
  R.group("<leader>g", "Git")

  -- -------------------------------------------------------------------------
  -- Search and quick open
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<D-p>",
    rhs = function()
      pick("files")
    end,
    desc = "Quick open file",
    cat = "Search",
    modes = { "n", "i" },
    term = "<C-p>",
    -- In insert mode Ctrl+P must stay "previous completion".
    term_modes = { "n" },
  })

  R.map({
    lhs = "<D-S-p>",
    rhs = command_palette,
    desc = "Command palette (commands and keys)",
    cat = "Search",
    modes = { "n", "i", "c" },
    -- The single most important shortcut, so it needs a portable binding too.
    term = "<C-S-p>",
    term_modes = { "n", "i" },
  })

  R.map({
    lhs = "<D-S-f>",
    rhs = function()
      pick("grep")
    end,
    desc = "Search in all files",
    cat = "Search",
    modes = { "n", "i" },
    term = "<C-S-f>",
  })

  R.map({
    lhs = "<D-f>",
    rhs = function()
      -- Open Vim's "/" search, as if the key had been typed.
      vim.api.nvim_feedkeys("/", "n", false)
    end,
    desc = "Find in file",
    cat = "Search",
    modes = { "n" },
  })

  R.map({
    lhs = "<D-h>",
    rhs = function()
      -- Start a search-and-replace in this file; the cursor lands after :%s/
      vim.api.nvim_feedkeys(":%s/", "n", false)
    end,
    desc = "Replace in file",
    cat = "Search",
    modes = { "n" },
  })

  R.map({
    lhs = "<leader>fb",
    rhs = function()
      pick("buffers")
    end,
    desc = "Find an open file (buffers)",
    cat = "Files",
  })

  R.map({
    lhs = "<leader>fr",
    rhs = function()
      pick("recent")
    end,
    desc = "Recent files",
    cat = "Files",
  })

  R.map({
    lhs = "<leader>fh",
    rhs = function()
      pick("help")
    end,
    desc = "Search Vim help",
    cat = "Search",
  })

  R.map({
    lhs = "<leader>fk",
    rhs = function()
      pick("keymaps")
    end,
    desc = "Search all keybindings",
    cat = "Search",
  })

  R.map({
    lhs = "<leader>fd",
    rhs = function()
      pick("diagnostics")
    end,
    desc = "All problems in the project",
    cat = "Diagnostics",
  })

  R.map({
    lhs = "<leader>fs",
    rhs = function()
      pick("lsp_symbols")
    end,
    desc = "Symbols in this file",
    cat = "Search",
  })

  R.map({
    lhs = "<leader>fS",
    rhs = function()
      pick("lsp_workspace_symbols")
    end,
    desc = "Symbols in the whole project",
    cat = "Search",
  })

  R.map({
    lhs = "<leader>fg",
    rhs = function()
      pick("git_status")
    end,
    desc = "Changed files (git status)",
    cat = "Git",
  })

  R.map({
    lhs = "<leader>fc",
    rhs = function()
      pick("commands")
    end,
    desc = "Search Vim commands",
    cat = "Search",
  })

  R.map({
    lhs = "<leader>fw",
    rhs = function()
      pick("grep_word")
    end,
    desc = "Search for the word under the cursor",
    cat = "Search",
  })

  R.map({
    lhs = "<leader>fp",
    rhs = function()
      pick("projects")
    end,
    desc = "Switch project",
    cat = "Files",
  })

  R.map({
    lhs = "<leader>gg",
    rhs = function()
      local S = snacks()
      if S and S.lazygit then
        S.lazygit()
      else
        vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
      end
    end,
    desc = "Open lazygit (git app)",
    cat = "Git",
  })

  R.map({
    lhs = "<leader>gs",
    rhs = function()
      local S = snacks()
      if S and S.picker then
        S.picker.git_status()
      else
        vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
      end
    end,
    desc = "Git status: changed files",
    cat = "Git",
  })

  -- -------------------------------------------------------------------------
  -- Sidebar, terminal, panels
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<D-b>",
    rhs = toggle_sidebar,
    desc = "Toggle the file explorer",
    cat = "Windows",
    modes = { "n", "i" },
    -- Ctrl+B is "page back" in Vim, so the portable shortcut is Ctrl+Shift+B.
    term = "<C-S-b>",
  })

  R.map({
    lhs = "<leader>e",
    rhs = toggle_sidebar,
    desc = "Toggle the file explorer",
    cat = "Windows",
  })

  R.map({
    lhs = "<leader>gc",
    rhs = function()
      require("ui.source").changes()
    end,
    desc = "Toggle the git changes panel",
    cat = "Git",
  })

  R.map({
    lhs = "<leader>gk",
    rhs = function()
      require("ui.source").commit()
    end,
    desc = "Commit changes (asks for a message, never pushes)",
    cat = "Git",
  })

  R.map({
    lhs = "<leader>gl",
    rhs = function()
      require("ui.source").graph()
    end,
    desc = "Git history graph",
    cat = "Git",
  })

  R.map({
    lhs = "<leader>gb",
    rhs = function()
      require("ui.source").branches()
    end,
    desc = "Switch branch",
    cat = "Git",
  })

  R.map({
    lhs = "<leader>H",
    rhs = function()
      local ok, S = pcall(require, "snacks")
      if ok and S.dashboard then
        S.dashboard()
      else
        vim.notify("snacks.nvim is not ready yet (try :Lazy)", vim.log.levels.WARN)
      end
    end,
    desc = "Home screen (start screen)",
    cat = "Windows",
  })

  -- VS Code: double-clicking the empty part of the tab bar opens a new file.
  -- The mapping is global because the tabline is not a buffer; anywhere else we
  -- replay the normal double-click (word selection, picker confirm, ...).
  R.map({
    lhs = "<2-LeftMouse>",
    rhs = function()
      local pos = vim.fn.getmousepos()
      if pos.winid == 0 and pos.screenrow <= 1 then
        vim.cmd("enew")
        return
      end
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<2-LeftMouse>", true, false, true),
        "n",
        false
      )
    end,
    desc = "New file (double-click the empty tab bar)",
    cat = "Mouse",
    modes = { "n" },
  })

  R.map({
    lhs = "<C-`>",
    rhs = toggle_terminal,
    desc = "Toggle terminal (press again to hide)",
    cat = "Terminal",
    modes = { "n", "t" },
  })

  R.map({
    lhs = "<D-S-m>",
    rhs = problems,
    desc = "Problems panel (errors and warnings)",
    cat = "Diagnostics",
    modes = { "n", "i" },
  })

  -- NOTE: <D-t> is also on the reserved list owned by another agent; declared
  -- here because the nav brief assigns it. The registry reports the dupe.
  R.map({
    lhs = "<D-t>",
    rhs = symbols_panel,
    desc = "Outline (symbols in this file)",
    cat = "Diagnostics",
    modes = { "n", "i" },
  })

  R.map({
    lhs = "<leader>xx",
    rhs = function()
      trouble_toggle({ mode = "diagnostics", focus = true })
    end,
    desc = "Problems panel (trouble)",
    cat = "Diagnostics",
  })

  R.map({
    lhs = "<leader>xX",
    rhs = function()
      trouble_toggle({ mode = "diagnostics", filter = { buf = 0 }, focus = true })
    end,
    desc = "Problems in this file only",
    cat = "Diagnostics",
  })

  R.map({
    lhs = "<leader>xq",
    rhs = function()
      trouble_toggle({ mode = "qflist", focus = true })
    end,
    desc = "Quickfix list (search results)",
    cat = "Diagnostics",
  })

  R.map({
    lhs = "<leader>xl",
    rhs = function()
      trouble_toggle({ mode = "loclist", focus = true })
    end,
    desc = "Location list (window results)",
    cat = "Diagnostics",
  })

  -- -------------------------------------------------------------------------
  -- Sessions: pick up where you left off
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<leader>qs",
    rhs = function()
      local ok, persistence = pcall(require, "persistence")
      if ok then
        persistence.load()
      else
        vim.notify("persistence.nvim is not installed yet (run :Lazy)", vim.log.levels.WARN)
      end
    end,
    desc = "Restore session for this folder",
    cat = "Session",
  })

  R.map({
    lhs = "<leader>ql",
    rhs = function()
      local ok, persistence = pcall(require, "persistence")
      if ok then
        persistence.load({ last = true })
      else
        vim.notify("persistence.nvim is not installed yet (run :Lazy)", vim.log.levels.WARN)
      end
    end,
    desc = "Restore the last session",
    cat = "Session",
  })

  R.map({
    lhs = "<leader>qd",
    rhs = function()
      local ok, persistence = pcall(require, "persistence")
      if ok then
        persistence.stop()
        vim.notify("Session saving stopped for this window", vim.log.levels.INFO)
      else
        vim.notify("persistence.nvim is not installed yet (run :Lazy)", vim.log.levels.WARN)
      end
    end,
    desc = "Stop saving this session",
    cat = "Session",
  })

  -- -------------------------------------------------------------------------
  -- Right-click menu
  -- -------------------------------------------------------------------------
  R.map({
    lhs = "<RightMouse>",
    rhs = context_menu,
    desc = "Context menu (right click)",
    cat = "Mouse",
    modes = { "n", "i" },
  })

  -- -------------------------------------------------------------------------
  -- Commands (they show up in :HelpMe too)
  -- -------------------------------------------------------------------------
  R.cmd("Problems", problems, { desc = "Open the problems panel", cat = "Diagnostics" })

  R.cmd("Palette", command_palette, {
    desc = "Open the command palette",
    cat = "Search",
  })

  R.cmd("Proj", function()
    pick("projects")
  end, { desc = "Switch project", cat = "Files" })

  R.cmd("Explorer", toggle_sidebar, {
    desc = "Show or hide the file explorer",
    cat = "Windows",
  })

  R.cmd("GitChanges", function()
    require("ui.source").changes()
  end, { desc = "Show or hide the git changes panel", cat = "Git" })

  R.cmd("GitCommit", function()
    require("ui.source").commit()
  end, { desc = "Commit changes (asks for a message, never pushes)", cat = "Git" })

  R.cmd("GitGraph", function()
    require("ui.source").graph()
  end, { desc = "Git history graph", cat = "Git" })

  R.cmd("GitBranches", function()
    require("ui.source").branches()
  end, { desc = "Switch branch", cat = "Git" })

  R.cmd("DebugPanel", function()
    require("ui.panels").debug_panel()
  end, { desc = "Show or hide the debugger panels", cat = "Debug" })

  R.cmd("OpenFolder", function(args)
    require("ui.dashboard").open_folder(args.args)
  end, {
    desc = "Open a folder as the project",
    cat = "Files",
    nargs = "?",
    complete = "dir",
  })

  R.cmd("NewFile", function(args)
    require("ui.dashboard").new_file(args.args)
  end, {
    desc = "Create a new file by name",
    cat = "Files",
    nargs = "?",
    complete = "file",
  })

  R.cmd("Preview", function(args)
    local path = args.args ~= "" and args.args or vim.api.nvim_buf_get_name(0)
    if path == "" then
      vim.notify("Open an image, or run :Preview <file>", vim.log.levels.WARN)
      return
    end
    local ok, image = pcall(require, "ui.image")
    if not ok then
      vim.notify("The image preview module is missing", vim.log.levels.WARN)
      return
    end
    image.preview(path)
  end, {
    desc = "Preview an image (png, jpg, webp, gif, svg)",
    cat = "Files",
    nargs = "?",
    complete = "file",
  })

  R.cmd("SessionRestore", function()
    local ok, persistence = pcall(require, "persistence")
    if ok then
      persistence.load()
    else
      vim.notify("persistence.nvim is not installed yet (run :Lazy)", vim.log.levels.WARN)
    end
  end, { desc = "Restore the session for this folder", cat = "Session" })

  R.cmd("SessionSave", function()
    local ok, persistence = pcall(require, "persistence")
    if ok then
      persistence.save()
      vim.notify("Session saved", vim.log.levels.INFO)
    else
      vim.notify("persistence.nvim is not installed yet (run :Lazy)", vim.log.levels.WARN)
    end
  end, { desc = "Save the current session", cat = "Session" })

  R.cmd("SessionStop", function()
    local ok, persistence = pcall(require, "persistence")
    if ok then
      persistence.stop()
      vim.notify("Session saving stopped", vim.log.levels.INFO)
    else
      vim.notify("persistence.nvim is not installed yet (run :Lazy)", vim.log.levels.WARN)
    end
  end, { desc = "Stop saving the current session", cat = "Session" })
end

return M
