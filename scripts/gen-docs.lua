-- scripts/gen-docs.lua
--
-- Generates KEYBINDINGS.md from the live keymap registry, so the docs and the
-- editor can never disagree.
--
-- Run it with:
--   nvim --headless -c "lua dofile('scripts/gen-docs.lua')" -c qa
-- or simply:
--   :ConfigDocs        (inside Neovim)
--   make docs
--
-- Exit code 1 when duplicate keymaps are found, so CI catches conflicts.

local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local R = require("config.registry")

-- If the config already ran (it does when this script is started from a normal
-- Neovim startup), the registry is populated. Only build it when it is empty,
-- otherwise every key would be declared twice.
if #R.entries == 0 then
  require("keys").setup()
end

local OUT = root .. "/KEYBINDINGS.md"

-- Categories in the order a beginner needs them.
local ORDER = {
  "Files",
  "Editing",
  "Clipboard",
  "Search",
  "AI",
  "LSP",
  "Windows",
  "Diagnostics",
  "Debug",
  "Git",
  "Terminal",
  "Session",
  "Terraform",
  ".NET",
  "React Native",
  "Mouse",
  "UI",
  "Config",
  "Help",
  "Commands",
  "General",
}

local pretty = require("help").pretty_key

local function esc(text)
  text = tostring(text or "")
  text = text:gsub("|", "\\|")
  text = text:gsub("\n", " ")
  return text
end

local rows = R.help_rows()
local maps, cmds = {}, {}
for _, row in ipairs(rows) do
  if row.kind == "cmd" then
    table.insert(cmds, row)
  else
    table.insert(maps, row)
  end
end

-- Group maps by category.
local by_cat = {}
for _, row in ipairs(maps) do
  by_cat[row.cat] = by_cat[row.cat] or {}
  table.insert(by_cat[row.cat], row)
end

local out = {}
local function w(line)
  out[#out + 1] = line or ""
end

w("# Keybindings")
w()
w("Every keymap and command in this config, generated from the live registry.")
w()
w("```")
w("Regenerate with:  :ConfigDocs")
w("              or  nvim --headless -c \"lua dofile('scripts/gen-docs.lua')\" -c qa")
w("```")
w()
w("## How the Cmd key reaches Neovim")
w()
w("This is the one thing that is genuinely different from VS Code, so it is")
w("worth two minutes:")
w()
w("| Where you run Neovim | Do Cmd shortcuts work? |")
w("|---|---|")
w(
  "| **Neovide** (recommended) | **Yes.** It is a native macOS app, so Cmd+S, Cmd+P, Cmd+Z arrive as `<D-s>`, `<D-p>`, `<D-z>`. |"
)
w(
  "| Ghostty / iTerm / Terminal.app | **No.** The terminal and macOS consume Cmd first; a program inside a terminal cannot see it. Use the *Terminal* column. |"
)
w("| tmux + `ide` layout | Same as the terminal above, plus tmux's own prefix (`Ctrl+B`). |")
w()
w("Every Cmd shortcut therefore has a terminal fallback bound as well, shown in")
w("the right-hand column below. Learn one column or the other, whichever you use.")
w()
w("Also worth knowing: `mousemoveevent` is on, so hover tooltips work; the mouse")
w("is enabled everywhere; right-click opens a context menu.")
w()

local seen = {}
local function section(cat, list)
  if not list or #list == 0 then
    return
  end
  w("## " .. cat)
  w()
  w("| Key | Terminal | What it does |")
  w("|---|---|---|")
  for _, row in ipairs(list) do
    local key = esc(pretty(row.key))
    local alt = row.alt and esc(pretty(row.alt)) or ""
    w(("| `%s` | %s | %s |"):format(key, alt ~= "" and ("`" .. alt .. "`") or "", esc(row.desc)))
  end
  w()
end

for _, cat in ipairs(ORDER) do
  seen[cat] = true
  section(cat, by_cat[cat])
end
for cat, list in pairs(by_cat) do
  if not seen[cat] then
    section(cat, list)
  end
end

-- Commands
if #cmds > 0 then
  w("## Commands")
  w()
  w("Type `:` then the name. Tab completes. They are grouped by purpose.")
  w()
  local cmd_by_cat = {}
  for _, row in ipairs(cmds) do
    cmd_by_cat[row.cat] = cmd_by_cat[row.cat] or {}
    table.insert(cmd_by_cat[row.cat], row)
  end
  for _, cat in ipairs(ORDER) do
    local list = cmd_by_cat[cat]
    if list and #list > 0 then
      w("### " .. cat)
      w()
      w("| Command | What it does |")
      w("|---|---|")
      for _, row in ipairs(list) do
        w(("| `%s` | %s |"):format(esc(row.key), esc(row.desc)))
      end
      w()
    end
  end
end

w("## Vim motions worth learning first")
w()
w("You do not need these on day one — arrows work, and every Cmd shortcut is")
w("bound. But these five give you the most speed for the least effort:")
w()
w("| Keys | Meaning |")
w("|---|---|")
w("| `h j k l` | left, down, up, right |")
w("| `w` / `b` | next word / previous word |")
w("| `ciw` | change the word under the cursor |")
w("| `gg` / `G` | top of file / bottom of file |")
w("| `dd` / `yy` / `p` | delete line / copy line / paste |")
w()

local fh = assert(io.open(OUT, "w"))
fh:write(table.concat(out, "\n"))
fh:write("\n")
fh:close()

print(("Wrote %s (%d keymaps, %d commands)"):format(OUT, #maps, #cmds))

-- Duplicate check: two keymaps on the same key in the same mode means one of
-- them silently loses. Treat it as an error.
if #R.dupes > 0 then
  print(("DUPLICATES (%d):"):format(#R.dupes))
  for _, d in ipairs(R.dupes) do
    print(("  [%s] %s  -> %s"):format(d.mode, d.lhs, d.desc))
  end
  vim.cmd("cq 1")
end

vim.cmd("qa!")
