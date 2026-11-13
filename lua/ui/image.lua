-- lua/ui/image.lua
--
-- Image previews for Neovide (and for terminals that cannot use the kitty
-- graphics protocol).
--
-- Why this exists:
--   * Opening a .png in Neovim used to dump the binary into a buffer.
--   * snacks.nvim's image module only works on kitty / wezterm / ghostty.
--     Neovide is NOT a terminal emulator and does not implement the kitty
--     graphics protocol, so `Snacks.image` renders nothing there.
--
-- What we do instead:
--   * `M.setup()` turns image files into read-only scratch buffers and opens a
--     floating terminal running `chafa`. chafa's "symbols" format is plain
--     ANSI text, which Neovide draws like any other terminal output.
--   * Where the kitty protocol *is* available, snacks' renderer is used first,
--     because it gives real pixels.
--
-- Usage:
--   require("ui.image").setup()
--   vim.keymap.set("n", "<leader>ip", "<cmd>Preview<cr>")
--
-- The public API is `preview`, `is_image`, and `setup`. Everything else is
-- internal, but `build_command` is exposed so the chafa invocations can be
-- tested without a terminal.

local M = {}

---@type table<string, true>
local EXTENSIONS = {}
for _, ext in ipairs({ "png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "tiff", "avif" }) do
  EXTENSIONS[ext] = true
end

local config = {
  -- Upper bound for the floating window, clamped to the editor size.
  width = 80,
  height = 40,
  border = "rounded",
  -- chafa palette; 256 colours look fine and are supported everywhere.
  colors = 256,
}

local state = {
  win = nil, ---@type integer?
  buf = nil, ---@type integer?
  path = nil, ---@type string?
  src_buf = nil, ---@type integer?
  placement = nil, ---@type table?
}

local setup_done = false
local resize_seq = 0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---All image extensions, as buffer patterns.
---
---Uppercase patterns are only added on case-sensitive systems: with
---'fileignorecase' (default on macOS) `*.png` and `*.PNG` both match, and
---Neovim would run the BufReadCmd callback twice for the same file.
---@return string[]
local function patterns()
  local out = {}
  for ext in pairs(EXTENSIONS) do
    out[#out + 1] = "*." .. ext
  end
  if not vim.o.fileignorecase then
    for ext in pairs(EXTENSIONS) do
      out[#out + 1] = "*." .. ext:upper()
    end
  end
  table.sort(out)
  return out
end

---Absolute, normalised path. `~` is expanded; relative paths resolve against
---the cwd, which is what `:Preview foo.png` should mean.
---@param path string
---@return string
local function resolve(path)
  if path:sub(1, 1) == "~" then
    path = vim.fn.expand(path)
  end
  return vim.fn.fnamemodify(path, ":p")
end

---The install command for this OS, used in every "chafa is missing" message.
---@return string
local function install_hint()
  local sys = (vim.uv.os_uname().sysname or ""):lower()
  if sys:find("darwin") then
    return "brew install chafa imagemagick"
  end
  if sys:find("windows") then
    return "winget install ImageMagick.ImageMagick  (and: scoop install chafa)"
  end
  if vim.fn.executable("apt") == 1 then
    return "sudo apt install chafa imagemagick"
  end
  if vim.fn.executable("dnf") == 1 then
    return "sudo dnf install chafa ImageMagick"
  end
  if vim.fn.executable("pacman") == 1 then
    return "sudo pacman -S chafa imagemagick"
  end
  if vim.fn.executable("zypper") == 1 then
    return "sudo zypper install chafa ImageMagick"
  end
  return "install chafa + ImageMagick with your package manager"
end

---@param path string
---@return string
local function basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

---@param bytes integer
---@return string
local function human_size(bytes)
  if not bytes or bytes < 0 then
    return "unknown size"
  end
  local units = { "B", "KB", "MB", "GB" }
  local n = bytes
  local i = 1
  while n >= 1024 and i < #units do
    n = n / 1024
    i = i + 1
  end
  if i == 1 then
    return ("%d %s"):format(n, units[i])
  end
  return ("%.1f %s"):format(n, units[i])
end

---File size in bytes, or nil.
---@param path string
---@return integer?
local function file_size(path)
  local size = vim.fn.getfsize(path)
  if size < 0 then
    return nil
  end
  return size
end

---Cached ImageMagick dimensions, keyed by path. `false` means "asked, not
---available" so a missing ImageMagick does not spawn a process per render.
---@type table<string, string|false>
local dims_cache = {}

---`WxH` from ImageMagick, or nil when magick/identify is not installed.
---@param path string
---@return string?
local function image_dimensions(path)
  local cached = dims_cache[path]
  if cached ~= nil then
    return cached or nil
  end

  local cmd
  if vim.fn.executable("magick") == 1 then
    cmd = { "magick", "identify", "-format", "%wx%h\n", path }
  elseif vim.fn.executable("identify") == 1 then
    cmd = { "identify", "-format", "%wx%h\n", path }
  else
    -- Not cached: ImageMagick may be installed later in the same session.
    return nil
  end

  local ok, out = pcall(vim.fn.system, cmd)
  if not ok or type(out) ~= "string" then
    dims_cache[path] = false
    return nil
  end
  -- ImageMagick can print warnings (e.g. a missing font for SVG text) and
  -- still report the geometry, so the exit code is not checked here.
  local dims = out:match("(%d+x%d+)")
  dims_cache[path] = dims or false
  return dims
end

---@param path string
---@return integer? bytes
---@return string? dimensions
local function image_info(path)
  return file_size(path), image_dimensions(path)
end

---One-line description used in notifications and buffer messages.
---@param path string
---@return string
local function describe(path)
  local size, dims = image_info(path)
  local parts = { basename(path) }
  parts[#parts + 1] = human_size(size)
  if dims then
    parts[#parts + 1] = dims:gsub("x", " x ") .. " px"
  end
  return table.concat(parts, "  ·  ")
end

---@return boolean
function M.has_chafa()
  return vim.fn.executable("chafa") == 1
end

---The argv used to render an image. Exposed for tests.
---@param path string
---@param cols integer
---@param rows integer
---@return string[]
function M.build_command(path, cols, rows)
  return {
    "chafa",
    "--format",
    "symbols",
    "--colors",
    tostring(config.colors),
    "--size",
    ("%dx%d"):format(cols, rows),
    -- Single-width block/border/space glyphs only: present in every coding
    -- font, and no double-width characters to desynchronise the grid.
    "--symbols",
    "block+border+space",
    "--stretch",
    "--animate",
    "off",
    -- Never query the terminal: Neovim's terminal buffer does not answer
    -- chafa's capability probes, which would stall the preview for seconds.
    "--probe",
    "off",
    "--polite",
    "off",
    "--",
    path,
  }
end

-- ---------------------------------------------------------------------------
-- Public helpers
-- ---------------------------------------------------------------------------

---True when `path` has one of the supported image extensions.
---@param path string?
---@return boolean
function M.is_image(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  local ext = path:match("%.([%w]+)$")
  return ext ~= nil and EXTENSIONS[ext:lower()] == true
end

-- ---------------------------------------------------------------------------
-- Floating window
-- ---------------------------------------------------------------------------

---Close the preview float (and stop snacks' placement, if that is what we used).
function M.close()
  if state.placement then
    pcall(function()
      state.placement:close()
    end)
    state.placement = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
  -- bufhidden=wipe normally takes care of the buffer; force it for the cases
  -- where the window was already gone.
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.buf = nil
  state.path = nil
  state.src_buf = nil
end

---Window geometry that keeps the image's aspect ratio. Terminal cells are
---roughly twice as tall as they are wide, hence the `2 *` factors.
---@param dims string? e.g. "320x200"
---@return integer cols
---@return integer rows
local function pick_size(dims)
  local max_cols = math.max(10, math.min(config.width, vim.o.columns - 4))
  -- Leave room for the border and the spare terminal row used below.
  local max_rows = math.max(4, math.min(config.height, vim.o.lines - 6))
  local cols, rows = max_cols, max_rows

  local w, h = (dims or ""):match("(%d+)x(%d+)")
  w, h = tonumber(w), tonumber(h)
  if w and h and w > 0 and h > 0 then
    -- width / (2 * height) == w / h
    rows = math.floor((cols * h) / (2 * w) + 0.5)
    if rows > max_rows then
      rows = max_rows
      cols = math.floor((rows * 2 * w) / h + 0.5)
    end
    cols = math.max(12, math.min(cols, max_cols))
    rows = math.max(4, math.min(rows, max_rows))
  end
  return cols, rows
end

---@param path string
---@param cols integer
---@param rows integer
---@param enter boolean
---@return integer buf
---@return integer win
local function open_float(path, cols, rows, enter)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  -- NB: 'buftype' is intentionally left alone. render_chafa() needs termopen()
  -- to turn this into a real terminal buffer (ANSI colours, pty sizing);
  -- try_snacks() sets buftype=nofile itself.

  local title = " " .. basename(path) .. " "
  if vim.fn.strdisplaywidth(title) > cols - 4 then
    title = " " .. vim.fn.strcharpart(basename(path), 0, math.max(1, cols - 8)) .. "… "
  end

  local win = vim.api.nvim_open_win(buf, enter, {
    relative = "editor",
    width = cols,
    height = rows,
    row = math.max(0, math.floor((vim.o.lines - rows) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - cols) / 2)),
    style = "minimal",
    border = config.border,
    title = title,
    title_pos = "center",
    focusable = true,
    zindex = 60,
  })

  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:Title"
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].cursorline = false
  vim.wo[win].spell = false

  -- q / <Esc> close. Mapped in normal *and* terminal mode: chafa is a job, not
  -- a shell, but the buffer is still a terminal buffer while it runs.
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set({ "n", "t" }, lhs, function()
      M.close()
    end, { buffer = buf, silent = true, nowait = true, desc = "Close image preview" })
  end

  return buf, win
end

---Use snacks' kitty renderer when the host terminal really supports it.
---Returns false when snacks is absent or the protocol is unavailable, in which
---case we fall back to chafa.
---@return boolean
local function snacks_supported()
  -- Neovide never implements the kitty graphics protocol, even if someone sets
  -- `force = true` in snacks' config.
  if vim.g.neovide then
    return false
  end
  local ok, snacks = pcall(require, "snacks.image")
  if not ok or type(snacks.supports_terminal) ~= "function" then
    return false
  end
  local supported = false
  pcall(function()
    supported = snacks.supports_terminal()
  end)
  return supported
end

---@param path string
---@param cols integer
---@param rows integer
---@param enter boolean
---@return boolean ok
local function try_snacks(path, cols, rows, enter)
  if not snacks_supported() then
    return false
  end
  local snacks = require("snacks.image")

  local buf, win = open_float(path, cols, rows, enter)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " " })
  vim.bo[buf].modifiable = false

  local placed, placement = pcall(snacks.placement.new, buf, path, {
    pos = { 1, 0 },
    width = cols,
    height = rows,
    inline = false,
    auto_resize = true,
  })
  if not placed or not placement then
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return false
  end

  state.win, state.buf = win, buf
  state.placement = placement
  return true
end

---Render with chafa in a floating terminal. This is the Neovide path.
---@param path string
---@param cols integer
---@param rows integer
---@param enter boolean
local function render_chafa(path, cols, rows, enter)
  -- chafa terminates the last row with a newline; in a terminal exactly `rows`
  -- high that scrolls the top row out of view. One spare row absorbs it.
  local buf, win = open_float(path, cols, rows + 1, enter)

  local cmd = M.build_command(path, cols, rows)
  local job = vim.fn.termopen(cmd, {
    env = { TERM = "xterm-256color" },
    on_exit = function(_, code)
      if code == 0 or state.buf ~= buf then
        return
      end
      local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
      local msg = ok and vim.trim(table.concat(lines, " "):gsub("%s+", " ")) or ""
      vim.notify(
        ("chafa failed for %s (exit %d)%s"):format(
          basename(path),
          code,
          msg ~= "" and (": " .. msg:sub(1, 240)) or ""
        ),
        vim.log.levels.ERROR,
        { title = "ui.image" }
      )
    end,
  })

  if job <= 0 then
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    vim.notify(
      "Could not start chafa for " .. basename(path),
      vim.log.levels.ERROR,
      { title = "ui.image" }
    )
    return
  end

  -- termopen() owns 'buftype' now; keep the buffer from lingering when hidden.
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  state.win, state.buf = win, buf
end

---@param path string
---@param opts table?
---@return boolean opened
local function open(path, opts)
  opts = opts or {}
  local dims = image_dimensions(path)
  local cols, rows = pick_size(dims)
  local enter = opts.focus ~= false

  M.close()

  if try_snacks(path, cols, rows, enter) then
    state.path = path
    state.src_buf = opts.src
    return true
  end

  if not M.has_chafa() then
    return false
  end

  render_chafa(path, cols, rows, enter)
  state.path = path
  state.src_buf = opts.src
  return true
end

---Open a floating preview for `path` (defaults to the current buffer's file).
---Never raises: a missing file or a missing chafa produces a notification.
---@param path string?
---@param opts? { focus?: boolean, src?: integer }
function M.preview(path, opts)
  opts = opts or {}
  path = path and path ~= "" and path or vim.api.nvim_buf_get_name(0)
  if not path or path == "" then
    vim.notify("Preview: no file to show", vim.log.levels.WARN, { title = "ui.image" })
    return
  end

  path = resolve(path)

  if vim.fn.filereadable(path) == 0 then
    vim.notify(
      ("Preview: file not found: %s"):format(path),
      vim.log.levels.ERROR,
      { title = "ui.image" }
    )
    return
  end

  if not M.is_image(path) then
    vim.notify(
      ("Preview: not an image: %s"):format(basename(path)),
      vim.log.levels.WARN,
      { title = "ui.image" }
    )
    return
  end

  if not snacks_supported() and not M.has_chafa() then
    -- Keep the exact Homebrew hint: it is what the user has to type.
    vim.notify(
      ("chafa is not installed — image preview needs it.\nInstall with: %s\n%s"):format(
        install_hint(),
        describe(path)
      ),
      vim.log.levels.WARN,
      { title = "ui.image" }
    )
    return
  end

  local ok, opened = pcall(open, path, opts)
  if not ok then
    vim.notify(("Preview failed for %s: %s"):format(basename(path), opened), vim.log.levels.ERROR, {
      title = "ui.image",
    })
  elseif not opened then
    vim.notify(
      ("Preview failed for %s: no image renderer available (try: %s)"):format(
        basename(path),
        install_hint()
      ),
      vim.log.levels.ERROR,
      { title = "ui.image" }
    )
  end
end

-- ---------------------------------------------------------------------------
-- Scratch buffer used instead of the binary file
-- ---------------------------------------------------------------------------

---@param buf integer
---@param path string
local function render_message(buf, path)
  local size, dims = image_info(path)
  local lines = {
    "",
    "  " .. basename(path),
    "",
    "  " .. human_size(size) .. (dims and ("  ·  " .. dims:gsub("x", " x ") .. " px") or ""),
    "  " .. vim.fn.fnamemodify(path, ":~:h"),
    "",
  }

  if M.has_chafa() or snacks_supported() then
    lines[#lines + 1] = "  The preview opens in a floating terminal."
    lines[#lines + 1] = "  q or <Esc> closes it  ·  :Preview reopens it"
  else
    lines[#lines + 1] = "  Preview needs chafa + ImageMagick:"
    lines[#lines + 1] = "    " .. install_hint()
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

---Turn `buf` into a nofile scratch buffer for the image at `path`.
---@param buf integer
---@param path string
---@param opts? { preview?: boolean, src?: integer }
local function attach(buf, path, opts)
  opts = opts or {}

  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].undolevels = -1
  vim.bo[buf].modeline = false
  vim.bo[buf].filetype = "image"
  vim.b[buf].ui_image = path
  dims_cache[path] = nil -- the file may have changed since the last look

  render_message(buf, path)

  if opts.preview ~= false then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        M.preview(path, { src = buf })
      end
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

---Install the BufReadCmd handlers. Safe to call more than once.
---@param opts? { width?: integer, height?: integer, border?: string, colors?: integer }
function M.setup(opts)
  if opts then
    config = vim.tbl_deep_extend("force", config, opts)
  end
  if setup_done then
    return
  end
  setup_done = true

  local group = vim.api.nvim_create_augroup("ui.image", { clear = true })
  local pats = patterns()

  -- Never let Neovim read the binary: the buffer is replaced before the read.
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = pats,
    callback = function(ev)
      attach(ev.buf, vim.api.nvim_buf_get_name(ev.buf))
    end,
  })

  -- Buffers that were read before setup() ran (session restore, `:e` before
  -- lazy-loading) still hold binary data. Repair them lazily on entry, but do
  -- not steal the screen by reopening a float every time the user comes back.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = pats,
    callback = function(ev)
      if vim.b[ev.buf].ui_image then
        return
      end
      if vim.bo[ev.buf].buftype ~= "" then
        return
      end
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if name == "" then
        return
      end
      attach(ev.buf, name, { preview = false })
    end,
  })

  -- Writing the scratch buffer would overwrite the image with text.
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = group,
    pattern = pats,
    callback = function(ev)
      vim.bo[ev.buf].modified = false
      vim.notify(
        "Image buffers are read-only; refusing to write",
        vim.log.levels.WARN,
        { title = "ui.image" }
      )
    end,
  })

  -- Closing the underlying image buffer closes its float.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    pattern = pats,
    callback = function(ev)
      if state.src_buf == ev.buf then
        M.close()
      end
    end,
  })

  -- Re-render on resize (debounced). The float is rebuilt at the new size, so
  -- the art stays sharp instead of being clipped.
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if not state.path or not state.win or not vim.api.nvim_win_is_valid(state.win) then
        return
      end
      local path, src = state.path, state.src_buf
      local focus = vim.api.nvim_get_current_win() == state.win
      resize_seq = resize_seq + 1
      local seq = resize_seq
      vim.defer_fn(function()
        if seq ~= resize_seq or state.path ~= path then
          return
        end
        -- snacks re-places itself via auto_resize; only chafa needs a rebuild.
        if state.placement or not M.has_chafa() then
          return
        end
        if not open(path, { focus = focus, src = src }) then
          M.close()
        end
      end, 150)
    end,
  })
end

return M
