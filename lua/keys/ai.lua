-- lua/keys/ai.lua
--
-- The AI keys. Two ideas, borrowed from what people actually use in VS Code:
--
--   Cmd+K        "do something with this" on the line/selection under the cursor
--   Cmd+Shift+K  "show me the menu of AI actions" (explain, review, tests, ...)
--   Cmd+I        open/close the chat panel (like Copilot Chat)
--
-- The AI runs as a real `opencode` process in a terminal buffer. It edits files
-- on disk; Neovim reloads them (see lua/config/autocmds.lua). Nothing is
-- written without your approval: proposed edits arrive as a diff you accept
-- with `da` or reject with `dr`.

local M = {}

function M.setup(R)
  local U = require("config.util")
  local WARN = vim.log.levels.WARN

  ---------------------------------------------------------------------------
  -- Guards. Every AI action goes through these, so a missing plugin or a
  -- missing CLI gives a readable sentence instead of a Lua stack trace.
  ---------------------------------------------------------------------------

  -- The panel is always a right-hand terminal of this shape.
  local function panel_opts(enter)
    return {
      win = {
        position = "right",
        width = 0.38,
        enter = enter,
        border = "rounded",
      },
    }
  end

  local function oc()
    if vim.fn.executable("opencode") == 0 then
      U.notify(
        "The 'opencode' CLI is not installed. Run: brew install opencode",
        WARN
      )
      return nil
    end
    local ok, mod = pcall(require, "opencode")
    if not ok then
      U.notify("opencode.nvim is not loaded yet (try :Lazy sync)", WARN)
      return nil
    end
    return mod
  end

  local function ask(default)
    local mod = oc()
    if mod then
      mod.ask(default)
    end
  end

  local function prompt(text)
    local mod = oc()
    if mod then
      mod.prompt(text)
    end
  end

  ---------------------------------------------------------------------------
  -- Open / close the chat panel.
  -- `enter` decides whether the cursor jumps into the chat (true) or stays in
  -- your code so you can keep typing while the answer streams in (false).
  ---------------------------------------------------------------------------
  local function toggle_chat(enter)
    if vim.fn.executable("opencode") == 0 then
      U.notify("The 'opencode' CLI is not installed. Run: brew install opencode", WARN)
      return
    end

    local ok, Snacks = pcall(require, "snacks")
    if not ok or not Snacks.terminal then
      U.notify("The terminal panel needs snacks.nvim (try :Lazy sync)", WARN)
      return
    end

    Snacks.terminal.toggle("opencode", panel_opts(enter))
  end

  ---------------------------------------------------------------------------
  -- Git diffs, for :AIDiff and :AICommit.
  -- opencode.nvim has no "@diff" context, so we read `git diff` ourselves and
  -- hand the text over. That is also why it works in any repo, staged or not.
  ---------------------------------------------------------------------------
  local MAX_DIFF = 60 * 1000 -- characters; keep the AI's context sane

  local function git_diff(staged)
    local args = { "git", "-C", U.root(), "diff", "--no-color", "-U3" }
    if staged then
      table.insert(args, "--cached")
    end

    local ok, res = pcall(function()
      return vim.system(args, { text = true }):wait()
    end)

    if not ok or res.code ~= 0 then
      return nil, "not a git repository (or git is not installed)"
    end

    local diff = res.stdout or ""
    if diff == "" then
      return nil, staged and "nothing staged" or "no changes since the last commit"
    end

    if #diff > MAX_DIFF then
      diff = diff:sub(1, MAX_DIFF)
        .. "\n\n[diff truncated — ask about a single file for the full picture]"
      U.notify("Diff was large: truncated to keep the AI focused", vim.log.levels.WARN)
    end

    return diff
  end

  local function send_diff(request, staged)
    local diff, err = git_diff(staged)
    if not diff then
      U.notify(err, WARN)
      return
    end
    prompt(request .. "\n\n```diff\n" .. diff .. "\n```")
  end

  ---------------------------------------------------------------------------
  -- Keymaps
  ---------------------------------------------------------------------------

  -- Open the chat and put the cursor in it. Same slot as Copilot Chat.
  R.map({
    lhs = "<D-i>",
    rhs = function()
      toggle_chat(true)
    end,
    desc = "Open the AI chat",
    cat = "AI",
    modes = { "n" },
  })

  -- "Do something with this line / selection". Pre-filled, so you just type
  -- what you want and press Enter.
  R.map({
    lhs = "<D-k>",
    rhs = function()
      ask("@this: ")
    end,
    desc = "Ask AI about this line or selection",
    cat = "AI",
    modes = { "n", "x" },
  })

  -- The menu of canned prompts: explain, review, tests, refactor, commit...
  R.map({
    lhs = "<D-S-k>",
    rhs = function()
      local mod = oc()
      if mod then
        mod.select()
      end
    end,
    desc = "AI actions menu (explain, review, tests…)",
    cat = "AI",
    modes = { "n", "x" },
  })

  -- Cmd+. is the editor's quick fix; Cmd+Shift+. is the AI's.
  R.map({
    lhs = "<D-S-.>",
    rhs = function()
      prompt("Fix @diagnostics")
    end,
    desc = "AI: fix the problem under the cursor",
    cat = "AI",
    modes = { "n" },
  })

  -- Works from anywhere, including inside the AI terminal, so it doubles as
  -- "hide the panel now". Ctrl+. because Cmd+. is taken and terminals never
  -- need that chord.
  R.map({
    lhs = "<C-.>",
    rhs = function()
      toggle_chat(false)
    end,
    desc = "Show/hide the AI panel",
    cat = "AI",
    modes = { "n", "t" },
  })

  -- Leader alternatives: discoverable, and safe on keyboards where the Cmd
  -- layer is awkward.
  R.group("<leader>a", "AI")

  R.map({
    lhs = "<leader>aa",
    rhs = function()
      ask("@this: ")
    end,
    desc = "Ask AI about this",
    cat = "AI",
    modes = { "n", "x" },
  })

  R.map({
    lhs = "<leader>ap",
    rhs = function()
      local mod = oc()
      if mod then
        mod.select()
      end
    end,
    desc = "AI prompt picker",
    cat = "AI",
    modes = { "n", "x" },
  })

  R.map({
    lhs = "<leader>ae",
    rhs = function()
      prompt("Explain @this and its context")
    end,
    desc = "AI: explain this code",
    cat = "AI",
    modes = { "n", "x" },
  })

  R.map({
    lhs = "<leader>af",
    rhs = function()
      prompt("Fix @diagnostics")
    end,
    desc = "AI: fix the diagnostics",
    cat = "AI",
  })

  R.map({
    lhs = "<leader>ar",
    rhs = function()
      prompt("Review @this for correctness and readability")
    end,
    desc = "AI: review this code",
    cat = "AI",
  })

  R.map({
    lhs = "<leader>at",
    rhs = function()
      prompt("Add tests for @this")
    end,
    desc = "AI: add tests",
    cat = "AI",
  })

  R.map({
    lhs = "<leader>ag",
    rhs = function()
      toggle_chat(true)
    end,
    desc = "AI: go to the chat panel",
    cat = "AI",
  })

  ---------------------------------------------------------------------------
  -- Commands
  ---------------------------------------------------------------------------

  -- :Ask             -> asks about the cursor/selection
  -- :Ask why is this slow   -> asks a question you typed
  R.cmd("Ask", function(args)
    local question = args.args or ""
    if question == "" then
      ask("@this: ")
    else
      ask(question .. " ")
    end
  end, { desc = "Ask the AI (optionally with a question)", cat = "AI", nargs = "*" })

  R.cmd("AIExplain", function()
    prompt("Explain @this and its context")
  end, { desc = "Explain the code under the cursor", cat = "AI" })

  R.cmd("AIFix", function()
    prompt("Fix @diagnostics")
  end, { desc = "Fix the diagnostics in this buffer", cat = "AI" })

  R.cmd("AIReview", function()
    prompt("Review @this for correctness and readability")
  end, { desc = "Review the code under the cursor", cat = "AI" })

  R.cmd("AITests", function()
    prompt("Add tests for @this")
  end, { desc = "Write tests for the code under the cursor", cat = "AI" })

  R.cmd("AIChat", function()
    toggle_chat(true)
  end, { desc = "Open the AI chat panel", cat = "AI" })

  -- Review the working-tree diff (everything not yet committed).
  R.cmd("AIDiff", function()
    send_diff(
      "Review this diff for bugs and risky changes. Be specific: name the file and line, and say what you would change.",
      false
    )
  end, { desc = "AI: review the uncommitted diff", cat = "AI" })

  -- Write a commit message from the staged diff, falling back to everything
  -- uncommitted when nothing is staged. We do not run git commit for you.
  R.cmd("AICommit", function()
    local staged = git_diff(true)
    if staged then
      prompt(
        "Write a Conventional Commits message for this staged diff. "
          .. "One subject line of at most 72 characters, then an optional body "
          .. "explaining the why. Output only the message.\n\n```diff\n"
          .. staged
          .. "\n```"
      )
      return
    end

    local unstaged, err = git_diff(false)
    if not unstaged then
      U.notify(err, WARN)
      return
    end
    prompt(
      "Nothing is staged. Here is the uncommitted diff — write a Conventional "
        .. "Commits message for it, and remind me to stage the files first.\n\n```diff\n"
        .. unstaged
        .. "\n```"
    )
  end, { desc = "AI: write a commit message from the diff", cat = "AI" })
end

return M
