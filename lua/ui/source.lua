-- lua/ui/source.lua
--
-- VS Code's Source Control, in the pieces Neo-tree does not provide: changed
-- files, a commit box, a history graph and a branch picker (per-file staging
-- is already built into neo-tree's git_status view). Every entry point ends in
-- a notification, never in an error: keymaps call these, so a missing plugin
-- or a folder that is not a repository must not throw.

local M = {}

local U = require("config.util")
local LEVELS = vim.log.levels

local function notify(msg, level)
  pcall(vim.notify, msg, level or LEVELS.INFO, { title = "Git" })
end

---First line of a command's error output, for one-line messages.
local function err_text(text)
  local line = type(text) == "string" and vim.trim(text:match("[^\r\n]*") or "") or ""
  return line ~= "" and line or "unknown error"
end

---Run git inside `dir`. `code` is nil when git could not even start.
local function git(args, dir)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  -- vim.system raises when git is missing, so pcall separates "not installed"
  -- from a broken editor.
  local ok, res = pcall(function()
    return vim.system(cmd, { text = true }):wait()
  end)
  if not ok or type(res) ~= "table" then
    return nil, "", "git is not available"
  end
  return res.code, res.stdout or "", res.stderr or ""
end

---Repository root, or nil outside a repository. `git rev-parse` is asked
---because `U.root()` falls back to the current folder, even in /tmp.
local function repo_root()
  local ok, start = pcall(U.root)
  start = ok and type(start) == "string" and start ~= "" and start or vim.uv.cwd()
  local code, out = git({ "rev-parse", "--show-toplevel" }, start)
  return code == 0 and vim.trim(out) ~= "" and vim.trim(out) or nil
end

---Run `fn(root)` inside the repository. The pcall keeps a broken git call
---from escaping into the caller's keymap.
local function with_repo(fn)
  local root = repo_root()
  if not root then
    notify("not a git repository", LEVELS.WARN)
    return
  end
  local ok, res = pcall(fn, root)
  if not ok then
    notify("Git action failed: " .. tostring(res), LEVELS.ERROR)
    return
  end
  return res
end

---Snacks picker API, or nil when snacks is missing.
local function picker()
  local ok, snacks = pcall(require, "snacks")
  if ok and type(snacks) == "table" and type(snacks.picker) == "table" then
    return snacks.picker
  end
  return nil
end

---Changed files: neo-tree's git_status view when present, else snacks.
function M.changes()
  with_repo(function()
    if vim.fn.exists(":Neotree") == 2 and pcall(vim.cmd, "Neotree git_status toggle left") then
      return
    end
    local P = picker()
    if P and type(P.git_status) == "function" and pcall(P.git_status) then
      return
    end
    notify("No changes view: install neo-tree or snacks.nvim", LEVELS.WARN)
  end)
end

---Second half of M.commit, split out so the message callback can defer it.
local function commit_with(root, message)
  -- 0 = nothing staged, 1 = staged changes exist, anything else = real error.
  local code, _, diff_err = git({ "diff", "--cached", "--quiet" }, root)
  if code ~= 0 and code ~= 1 then
    return notify("git diff failed: " .. err_text(diff_err), LEVELS.ERROR)
  end

  -- Safety by default: an empty staging area is never committed silently.
  if code == 0 then
    local answer = vim.fn.confirm(
      "Nothing is staged. Stage every modified file and commit?",
      "&Stage all\n&Cancel"
    )
    if answer ~= 1 then
      return notify("Commit cancelled — nothing staged")
    end
    local add_code, _, add_err = git({ "add", "-A" }, root)
    if add_code ~= 0 then
      return notify("git add failed: " .. err_text(add_err), LEVELS.ERROR)
    end
  end

  local done, out, stderr = git({ "commit", "-m", message }, root)
  if done ~= 0 then
    return notify(
      "Commit failed: " .. err_text(vim.trim(stderr) ~= "" and stderr or out),
      LEVELS.ERROR
    )
  end
  local _, hash = git({ "rev-parse", "--short", "HEAD" }, root)
  local short = vim.trim(hash)
  -- No `git push` anywhere in this file: pushing is separate, like "Sync".
  notify(short ~= "" and ("Committed " .. short .. " (not pushed)") or "Committed (not pushed)")
end

---Show the changes, ask for a message, commit. Stages everything only with
---explicit confirmation. Never pushes.
function M.commit()
  with_repo(function(root)
    local code, out, stderr = git({ "status", "--short" }, root)
    if code ~= 0 then
      return notify("git status failed: " .. err_text(stderr), LEVELS.ERROR)
    end
    if vim.trim(out) == "" then
      return notify("Nothing to commit — the working tree is clean")
    end

    -- Show the list first, so the box sits in front of what it will include.
    notify(out)

    vim.ui.input({ prompt = "Commit message: " }, function(message)
      if type(message) ~= "string" or vim.trim(message) == "" then
        return notify("Commit cancelled")
      end
      -- snacks' input runs its callback in a fast event; git belongs on the
      -- main loop.
      vim.schedule(function()
        local ok, failure = pcall(commit_with, root, vim.trim(message))
        if not ok then
          notify("Commit failed: " .. tostring(failure), LEVELS.ERROR)
        end
      end)
    end)
  end)
end

---Open a read-only `git log --graph` float. `q`/`<Esc>` closes it.
---@return integer? win window handle, for callers and tests
function M.graph()
  return with_repo(function(root)
    local args = { "log", "--graph", "--decorate", "--oneline", "--all", "-n", "200" }
    local code, out, stderr = git(args, root)
    if code ~= 0 then
      return notify("git log failed: " .. err_text(stderr), LEVELS.ERROR)
    end

    local lines = vim.split(out, "\n", { plain = true })
    while #lines > 0 and lines[#lines] == "" do
      table.remove(lines)
    end
    if #lines == 0 then
      return notify("This repository has no commits yet")
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "git"
    vim.bo[buf].modifiable = false

    -- 80% x 70% of the editor, centred: wide enough for graph characters,
    -- never full-screen so the code behind stays visible.
    local width = math.max(20, math.floor(vim.o.columns * 0.8))
    local height = math.max(5, math.floor(vim.o.lines * 0.7))
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
      col = math.max(math.floor((vim.o.columns - width) / 2), 0),
      style = "minimal",
      border = "rounded",
      title = " Git graph ",
      title_pos = "center",
    })
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = true

    -- Make HEAD findable at a glance; a missing highlight must not stop us.
    for i, line in ipairs(lines) do
      if line:find("HEAD", 1, true) then
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, "Search", i - 1, 0, -1)
        break
      end
    end

    for _, lhs in ipairs({ "q", "<Esc>" }) do
      vim.keymap.set("n", lhs, function()
        pcall(vim.api.nvim_win_close, win, true)
      end, { buffer = buf, nowait = true, silent = true, desc = "Close git graph" })
    end
    return win
  end)
end

---Pick a branch and switch to it: snacks' picker, else `git branch --all`.
function M.branches()
  with_repo(function(root)
    local P = picker()
    if P and type(P.git_branches) == "function" and pcall(P.git_branches) then
      return
    end

    local code, out, stderr = git({ "branch", "--all", "--no-color" }, root)
    if code ~= 0 then
      return notify("git branch failed: " .. err_text(stderr), LEVELS.ERROR)
    end

    local names = {}
    for line in out:gmatch("[^\r\n]+") do
      -- "* main" marks the current branch; the star is not part of the name.
      local name = vim.trim(line:gsub("^%*%s*", ""))
      if name ~= "" then
        names[#names + 1] = name
      end
    end
    if #names == 0 then
      return notify("This repository has no branches yet")
    end

    vim.ui.select(names, { prompt = "Switch branch: " }, function(choice)
      if type(choice) ~= "string" or choice == "" then
        return -- cancelled
      end
      -- "remotes/origin/main" is not local; `git switch main` guesses the
      -- remote and creates the tracking branch. Local names keep their slashes.
      local branch = choice
      if choice:match("^remotes/") then
        branch = choice:gsub("^remotes/[^/]+/", "", 1)
      end
      local switched, switch_out, switch_err = git({ "switch", branch }, root)
      if switched == 0 then
        return notify("Switched to " .. branch)
      end
      local reason = vim.trim(switch_err) ~= "" and switch_err or switch_out
      notify("Could not switch to " .. branch .. ": " .. err_text(reason), LEVELS.ERROR)
    end)
  end)
end

return M
