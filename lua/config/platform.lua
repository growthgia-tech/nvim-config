-- lua/config/platform.lua
--
-- One question, asked in a lot of places: which key is "the modifier that
-- means the same thing as Cmd on a Mac"?
--
--   macOS           Cmd   -> <D-...>
--   Linux/Windows   Ctrl  -> <C-...>
--
-- The config is written with Cmd in mind (this is a Mac-first setup), but the
-- *registry* needs to know whether to bind a <D-s> keymap at all. On Linux and
-- Windows a Super/Windows key either does nothing useful or is swallowed by the
-- window manager, so the Ctrl fallback becomes the real shortcut there.
--
-- Keeping this in one file means the rest of the config never asks
-- `vim.fn.has("mac")` again.

local M = {}

M.is_mac = vim.fn.has("mac") == 1
M.is_linux = vim.fn.has("linux") == 1
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
M.is_wsl = M.is_linux
  and vim.fn.readfile("/proc/version")[1] ~= nil
  and vim.fn.readfile("/proc/version")[1]:lower():find("microsoft") ~= nil

M.name = M.is_mac and "macOS" or (M.is_windows and "Windows" or (M.is_wsl and "WSL" or "Linux"))

---The modifier letter used in the docs: "Cmd" or "Ctrl".
M.mod_name = M.is_mac and "Cmd" or "Ctrl"

---Is this a keymap that depends on a macOS-only key?
function M.is_cmd_key(lhs)
  return type(lhs) == "string" and lhs:find("^<D%-") ~= nil
end

---Separator for PATH-like values.
M.pathsep = M.is_windows and ";" or ":"

-- ---------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------
---Where this config lives, in a form that works on every platform.
function M.config_dir()
  return vim.fn.stdpath("config")
end

---A directory that is safe to write user files into.
function M.data_dir()
  return vim.fn.stdpath("data")
end

---The folder a file explorer should default to. Windows and macOS both call it
---"home"; we do not assume a ~/Dev tree exists.
function M.projects_dir()
  local dev = vim.fs.joinpath(vim.env.HOME or vim.uv.os_homedir(), "Dev")
  if vim.fn.isdirectory(dev) == 1 then
    return dev
  end
  return vim.uv.os_homedir()
end

-- ---------------------------------------------------------------------------
-- Shell commands
-- ---------------------------------------------------------------------------
---How to run a shell command line through the OS shell, cross-platform.
---@param cmd string
---@return string[]
function M.shell(cmd)
  if M.is_windows then
    return { "cmd.exe", "/C", cmd }
  end
  return { vim.o.shell, "-lc", cmd }
end

---Does this machine have the given executable?
function M.has(bin)
  return vim.fn.executable(bin) == 1
end

-- ---------------------------------------------------------------------------
-- PATH
-- ---------------------------------------------------------------------------
---Directories that should always be visible to Neovim, in priority order.
---
---Why this is necessary: a GUI app launched from Finder or Spotlight (Neovide!)
---gets a minimal PATH — usually just /usr/bin:/bin:/usr/sbin:/sbin. Homebrew,
---~/.local/bin and Mason's bin are all missing, so ripgrep, fd, opencode and
---every language server would silently "not exist". It also fixes the common
---case where Homebrew is at the *end* of a shell's PATH, so an old system
---python3 shadows the current one.
local function wanted_dirs()
  local dirs = {}
  local home = vim.uv.os_homedir()

  if M.is_windows then
    table.insert(
      dirs,
      vim.fs.joinpath(vim.env.LOCALAPPDATA or home, "Microsoft", "WinGet", "Links")
    )
    table.insert(dirs, vim.fs.joinpath(vim.env.LOCALAPPDATA or home, "pnpm"))
    table.insert(dirs, vim.fs.joinpath(home, ".local", "bin"))
  else
    if M.is_mac then
      table.insert(dirs, "/opt/homebrew/bin")
      table.insert(dirs, "/opt/homebrew/sbin")
      -- pnpm's global binaries (one shared store, symlinked into projects).
      table.insert(dirs, vim.fs.joinpath(home, "Library", "pnpm", "bin"))
    end
    table.insert(dirs, "/usr/local/bin")
    table.insert(dirs, "/usr/local/sbin")
    table.insert(dirs, vim.fs.joinpath(home, ".local", "bin"))
    table.insert(dirs, vim.fs.joinpath(home, ".local", "share", "pnpm"))
    table.insert(dirs, vim.fs.joinpath(home, ".dotnet", "tools"))
  end

  -- Anything Mason installed (language servers, formatters, debug adapters).
  table.insert(dirs, vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin"))

  return dirs
end

---Put the important directories at the FRONT of PATH. Idempotent.
---
---Ordering matters, not just presence: Homebrew is often *last* in a shell's
---PATH, so `/usr/bin/python3` (3.9 on macOS) shadows the current Homebrew
---python, and Mason refuses to install debugpy because it needs 3.10+. Putting
---our directories first fixes that deterministically.
function M.ensure_path()
  local current = vim.env.PATH or ""

  local dirs = {}
  local priority = {}
  for _, dir in ipairs(wanted_dirs()) do
    if vim.fn.isdirectory(dir) == 1 then
      priority[dir] = true
      table.insert(dirs, dir)
    end
  end

  for _, dir in ipairs(vim.split(current, M.pathsep, { plain = true })) do
    if dir ~= "" and not priority[dir] then
      table.insert(dirs, dir)
    end
  end

  local new = table.concat(dirs, M.pathsep)
  if new ~= current then
    vim.env.PATH = new
  end
end

return M
