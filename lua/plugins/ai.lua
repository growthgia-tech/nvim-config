-- lua/plugins/ai.lua
--
-- OpenCode, wired into the editor.
--
-- The mental model, if you come from VS Code + Copilot:
--   * the AI lives in its own panel on the right (like Copilot Chat)
--   * you can send the current line, the selection, the whole buffer, or the
--     diagnostics to it with one key
--   * it edits files on disk and Neovim reloads them instantly (see
--     lua/config/autocmds.lua, which watches for changes on disk)
--
-- All the intelligence is in the `opencode` CLI, which must be on your PATH
-- (install.sh installs it). This plugin only builds the bridge.

return {
  {
    "nickjvandyke/opencode.nvim",
    -- Loaded at startup because the statusline shows the connection state and
    -- the picker needs `require("opencode").select` to exist.
    lazy = false,
    config = function()
      ---------------------------------------------------------------------
      -- Where the AI panel opens.
      -- Right-hand side, 38% wide, and focus stays in the editor so you can
      -- keep typing while the answer streams in.
      ---------------------------------------------------------------------
      local function start_opencode()
        local ok, Snacks = pcall(require, "snacks")
        if ok and Snacks.terminal then
          Snacks.terminal.open("opencode", {
            win = {
              position = "right",
              width = 0.38,
              enter = false,
              -- A border makes the panel look like a VS Code sidebar.
              border = "rounded",
            },
          })
          return
        end

        -- Fallback if snacks ever fails to load: still works, just uglier.
        vim.cmd("vsplit term://opencode | wincmd p")
      end

      ---------------------------------------------------------------------
      -- The configuration. opencode.nvim reads this global on first use.
      -- Anything not mentioned here keeps the plugin's sensible default.
      ---------------------------------------------------------------------
      vim.g.opencode_opts = {
        server = {
          -- If you already have `opencode` running in a terminal somewhere,
          -- the plugin finds it and connects instead of starting a second one.
          connect = true,
          start = start_opencode,
        },

        select = {
          -- Extra one-click prompts, on top of the built-in ones (explain,
          -- fix, review, test, document, implement, optimize).
          -- They appear in the :AI menu and in the "custom prompt" list.
          prompts = {
            commit = "Write a Conventional Commits message for @buffers",
            refactor = "Refactor @this for clarity without changing behaviour",
            simplify = "Simplify @this, keeping every behaviour identical",
            typescript = "Add precise TypeScript types to @this",
            csharp = "Review @this as a C#/.NET reviewer would",
            explain_error = "Explain this error and how to fix it: @diagnostics",
            docs = "Write user-facing documentation for @this",
          },
          snacks = {
            -- Preview the code an item refers to, like VS Code's quick pick.
            preview = "preview",
            layout = { preset = "vscode" },
          },
        },

        events = {
          enabled = true,
          reload = { enabled = true },

          -- When OpenCode proposes an edit, the plugin opens a diff and asks
          -- you to accept or reject it (da / dr / q). That is the approval
          -- step: nothing is written until you say so.
          permissions = {
            enabled = true,
            edits = { enabled = true },
          },
        },
      }

      ---------------------------------------------------------------------
      -- A tiny bit of feedback so the AI never feels like a black box.
      ---------------------------------------------------------------------
      vim.api.nvim_create_autocmd("User", {
        pattern = "OpencodeEvent:session.execution.started",
        callback = function()
          -- Only reveal the panel if it is hidden: no stealing of focus.
          local ok, Snacks = pcall(require, "snacks")
          if not ok or not Snacks.terminal then
            return
          end
          local win = Snacks.terminal.get("opencode", { create = false })
          if win then
            pcall(function()
              win:show()
            end)
          end
        end,
        desc = "Reveal the AI panel when OpenCode starts working",
      })
    end,
  },
}
