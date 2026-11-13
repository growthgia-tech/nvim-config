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
M.is_wsl = M.is_linux and vim.fn.readfile("/proc/version")[1] ~= nil
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

return M
