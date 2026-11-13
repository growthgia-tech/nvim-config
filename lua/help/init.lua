-- lua/help/init.lua
--
-- The in-editor help. Three entry points:
--
--   :HelpMe        a printable cheat sheet built from the REAL keymaps
--   :HelpTutorial  the step-by-step beginner tutorial (docs/TUTORIAL.md)
--   :Panic         "I am stuck, what do I press" card
--
-- The cheat sheet is generated from lua/config/registry.lua at the moment you
-- open it. That is the whole trick: there is no second list to maintain, so it
-- cannot go out of date when a keymap changes.

local M = {}

local function scratch(name, lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = filetype or "helpme"
  vim.api.nvim_buf_set_name(buf, name)
  return buf
end

-- Turn "<D-S-s>" into "Cmd+Shift+S" and "<leader>fb" into "Space f b", so the
-- sheet is readable by someone who does not speak Vim notation yet.
local MODS = {
  D = "Cmd",
  C = "Ctrl",
  S = "Shift",
  M = "Alt",
  A = "Alt",
}

local NAMES = {
  esc = "Esc",
  cr = "Enter",
  crlf = "Enter",
  tab = "Tab",
  space = "Space",
  bs = "Backspace",
  up = "Up",
  down = "Down",
  left = "Left",
  right = "Right",
  del = "Delete",
  home = "Home",
  ["end"] = "End",
  pageup = "PageUp",
  pagedown = "PageDown",
  leader = "Space",
  ["return"] = "Enter",
  backspace = "Backspace",
  insert = "Insert",
}

local function pretty_token(content)
  -- "leader" is its own thing.
  if content:lower() == "leader" then
    return "Space"
  end

  local parts = vim.split(content, "-", { plain = true })
  local mods = {}
  local i = 1

  while i < #parts do
    local mod = MODS[parts[i]:upper()]
    if not mod then
      break
    end
    table.insert(mods, mod)
    i = i + 1
  end

  local rest = table.concat(parts, "-", i)
  local name = NAMES[rest:lower()] or rest
  if #name == 1 then
    name = name:upper()
  elseif name:match("^f%d+$") then
    name = name:upper()
  end

  if #mods > 0 then
    return table.concat(mods, "+") .. "+" .. name
  end
  return name
end

function M.pretty_key(key)
  if not key or key == "" then
    return ""
  end

  local out = {}
  local i = 1
  while i <= #key do
    local s, e, inner = key:find("<([^<>]+)>", i)
    if s == i then
      table.insert(out, pretty_token(inner))
      i = e + 1
    else
      -- Literal characters between special keys: "ff" after <leader>.
      local stop = s and (s - 1) or #key
      local literal = key:sub(i, stop)
      table.insert(out, literal)
      i = stop + 1
    end
  end

  return vim.trim(table.concat(out, " "))
end

-- The cheat sheet text.
function M.cheat_sheet_lines()
  local R = require("config.registry")
  local rows = R.help_rows()

  -- Group by category, keeping a stable order that goes from "most needed" to
  -- "advanced" instead of alphabetical.
  local order = {
    "Files",
    "Editing",
    "Search",
    "Clipboard",
    "AI",
    "LSP",
    "Windows",
    "Diagnostics",
    "Debug",
    "Git",
    "Terminal",
    "Terraform",
    ".NET",
    "React Native",
    "Mouse",
    "Session",
    "UI",
    "Config",
    "Help",
    "Commands",
  }

  local by_cat = {}
  for _, row in ipairs(rows) do
    by_cat[row.cat] = by_cat[row.cat] or {}
    table.insert(by_cat[row.cat], row)
  end

  local lines = {
    "",
    "  NEOVIM — every key you can press",
    "  =================================",
    "",
    "  Press Space and wait: a menu appears. That is the fastest way to learn.",
    "  Everything below works in Neovide. In a terminal, use the Ctrl fallback",
    "  printed in the right column.",
    "",
    "  Move around:  h j k l      or the arrow keys (in Beginner mode)",
    "  Leave insert mode:  Esc    Save:  Cmd+S    Quit:  Cmd+W",
    "",
  }

  local function emit(title, list)
    if #list == 0 then
      return
    end
    table.insert(lines, "  " .. title)
    table.insert(lines, "  " .. string.rep("-", math.max(#title, 10)))
    for _, row in ipairs(list) do
      local key = M.pretty_key(row.key)
      local alt = row.alt and M.pretty_key(row.alt) or ""
      local desc = row.desc or ""
      -- Cap the key column so long multi-step sequences do not push the
      -- description off the screen.
      if #key > 26 then
        key = key:sub(1, 25) .. "…"
      end
      table.insert(
        lines,
        ("  %-26s %-58s %s"):format(key, desc, alt ~= "" and ("(" .. alt .. ")") or "")
      )
    end
    table.insert(lines, "")
  end

  local seen = {}
  for _, cat in ipairs(order) do
    seen[cat] = true
    emit(cat, by_cat[cat] or {})
  end

  -- Anything an agent added with a category we did not predict still shows up.
  for cat, list in pairs(by_cat) do
    if not seen[cat] then
      emit(cat, list)
    end
  end

  table.insert(lines, "  Tip: :HelpTutorial for a guided tour, :Panic when stuck.")
  table.insert(lines, "  This list is generated from your live keymaps — it is never stale.")
  table.insert(lines, "")

  return lines
end

function M.open()
  local lines = M.cheat_sheet_lines()
  local buf = scratch("HelpMe", lines, "helpme")

  vim.cmd("tabnew")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = true

  -- q / Esc close, and the usual search still works because this is a normal
  -- read-only buffer.
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, function()
      if #vim.api.nvim_list_wins() > 1 then
        vim.cmd("close")
      else
        vim.cmd("bdelete!")
      end
    end, { buffer = buf, desc = "Close help" })
  end

  vim.keymap.set("n", "g?", function()
    vim.cmd("close")
    M.open()
  end, { buffer = buf, desc = "Regenerate this list" })

  return buf
end

-- Re-generate the cheat sheet while it is open (used after :Reload).
function M.refresh()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf):match("HelpMe$") then
      local lines = M.cheat_sheet_lines()
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].modifiable = false
    end
  end
end

return M
