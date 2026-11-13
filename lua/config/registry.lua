-- lua/config/registry.lua
--
-- THE SINGLE SOURCE OF TRUTH for keymaps and user commands.
--
-- Why this exists: a help window that is written by hand goes stale within a
-- week. Here every mapping is declared once, and five things are derived from
-- that one declaration:
--
--   1. the actual keymap            (M.apply)
--   2. the which-key group labels    (M.which_key_spec)
--   3. the :HelpMe searchable list   (M.help_rows)
--   4. KEYBINDINGS.md                (scripts/gen-docs.lua)
--   5. a duplicate-key report        (M.dupes)
--
-- Entry shape (all fields except lhs/rhs are optional):
--
--   R.map({
--     lhs   = "<D-s>",              -- what you press
--     rhs   = function() end,       -- what happens (function or string)
--     desc  = "Save file",          -- human sentence, shown everywhere
--     cat   = "Files",              -- help category
--     modes = { "n", "i", "v" },    -- default { "n" }
--     term  = "<C-s>",              -- fallback for terminals that can't send Cmd
--     expr  = false,                -- pass through to vim.keymap.set
--   })
--
-- Commands:
--
--   R.cmd("Format", fn, { desc = "Format buffer", cat = "Editing", nargs = 0 })

local M = {}

M.entries = {}
M.commands = {}
M.dupes = {}
M.wk_groups = {}

local applied = {}

---Label a leader prefix for which-key, e.g. R.group("<leader>f", "Find")
function M.group(prefix, name)
  M.wk_groups[prefix] = name
end

---Declare a keymap. Called from lua/keys/*.lua.
function M.map(spec)
  if type(spec) ~= "table" or not spec.lhs or not spec.rhs then
    vim.notify("registry.map() needs { lhs, rhs }", vim.log.levels.WARN)
    return
  end
  spec.desc = spec.desc or spec.lhs
  spec.cat = spec.cat or "General"
  spec.modes = spec.modes or { "n" }
  table.insert(M.entries, spec)
  return spec
end

---Declare a user command. It shows up in :HelpMe automatically.
function M.cmd(name, fn, spec)
  spec = spec or {}
  local opts = {
    desc = spec.desc or name,
    force = true, -- re-defining is fine: agents and core may both declare
    nargs = spec.nargs or 0,
  }
  if spec.bang then
    opts.bang = true
  end
  if spec.range then
    opts.range = spec.range
  end
  if spec.complete then
    opts.complete = spec.complete
  end

  local ok, err = pcall(vim.api.nvim_create_user_command, name, fn, opts)
  if not ok then
    vim.notify(("Command :%s failed: %s"):format(name, err), vim.log.levels.WARN)
  end

  table.insert(M.commands, {
    name = name,
    desc = opts.desc,
    cat = spec.cat or "Commands",
    nargs = opts.nargs,
  })
  return ok
end

local function set_one(mode, lhs, rhs, opts)
  local key = mode .. "\0" .. lhs
  if applied[key] then
    table.insert(M.dupes, { mode = mode, lhs = lhs, desc = opts.desc })
    return false
  end
  applied[key] = true

  local ok = pcall(vim.keymap.set, mode, lhs, rhs, opts)
  if not ok then
    vim.notify(("Invalid keymap [%s] %s"):format(mode, lhs), vim.log.levels.WARN)
  end
  return ok
end

---Apply every declared mapping exactly once.
---
---Two platform rules live here, so no other file has to think about it:
---
---  1. On macOS the Cmd key exists, so <D-...> is bound. Everywhere else a
---     Cmd/Super keymap would never fire, so only the portable `term =`
---     fallback is bound (see lua/config/platform.lua).
---  2. `term_modes` limits the fallback to some modes. Example: Ctrl+P opens
---     the file finder in normal mode, but must stay "previous completion"
---     in insert mode on Linux/Windows.
function M.apply()
  local P = require("config.platform")

  for _, e in ipairs(M.entries) do
    local opts = vim.tbl_extend("force", {
      desc = e.desc,
      silent = true,
      noremap = true,
      nowait = e.nowait or false,
    }, e.opts or {})
    if e.expr then
      opts.expr = true
    end

    local cmd_only = P.is_cmd_key(e.lhs)

    local function term_ok(mode)
      if not e.term_modes then
        return true
      end
      return vim.tbl_contains(e.term_modes, mode)
    end

    for _, mode in ipairs(e.modes) do
      -- The Cmd keymap itself.
      if P.is_mac or not cmd_only then
        set_one(mode, e.lhs, e.rhs, opts)
      end

      -- The portable shortcut. On macOS this is the terminal fallback; on
      -- Linux/Windows it is the real shortcut.
      if e.term and term_ok(mode) then
        local desc = e.desc or ""
        if P.is_mac then
          desc = desc .. "  [terminal fallback]"
        end
        set_one(mode, e.term, e.rhs, vim.tbl_extend("force", opts, { desc = desc }))
      end
    end
  end
end

---which-key group spec, derived from M.group() calls.
function M.which_key_spec()
  local spec = {}
  for prefix, name in pairs(M.wk_groups) do
    table.insert(spec, { prefix, group = name })
  end
  return spec
end

---Flat rows for :HelpMe and for the docs generator.
function M.help_rows()
  local rows = {}

  for _, e in ipairs(M.entries) do
    rows[#rows + 1] = {
      kind = "map",
      key = e.lhs,
      alt = e.term,
      mode = table.concat(e.modes, ","),
      desc = e.desc,
      cat = e.cat,
    }
  end

  for _, c in ipairs(M.commands) do
    rows[#rows + 1] = {
      kind = "cmd",
      key = ":" .. c.name,
      mode = "",
      desc = c.desc,
      cat = c.cat,
    }
  end

  table.sort(rows, function(a, b)
    if a.cat ~= b.cat then
      return a.cat < b.cat
    end
    return a.key < b.key
  end)

  return rows
end

return M
