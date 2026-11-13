# Tutorial: from VS Code to this Neovim

You do not have to learn Vim to use this setup. Everything you do in VS Code
has a shortcut here, and the shortcuts are the same Cmd ones you already know.
This tutorial is a path, not a reference: read it once, top to bottom, typing
the examples. Twenty minutes and you will be comfortable.

The complete list of keys is in [`KEYBINDINGS.md`](../KEYBINDINGS.md), and
`:HelpMe` shows the same list inside the editor, generated live.

---

## 1. The three things that are actually different

Everything else is a detail.

**Modes.** VS Code has one mode: you type and characters appear. Vim has
several. You start in **Normal** mode, where keys are commands (`d` deletes,
`u` undoes) instead of text. Press `i` to get **Insert** mode and type like
normal. Press `Esc` to go back to Normal.

That is the whole idea. When something "doesn't type", you are in Normal mode.
Press `i`.

**The editor is the window.** There is no sidebar tree, no tab bar you have to
click. Buffers (open files) exist whether or not you can see them. You switch
by name with `Cmd+P`, which is faster than clicking and is what you already do
in VS Code anyway.

**Nothing is a menu until you ask.** The screen is quiet because the chrome is
hidden. Press `Space` and wait and the menu appears — that is which-key, and it
is the answer to "how was I supposed to know that".

---

## 2. Saving, quitting, and not panicking

Open a terminal and run `neovide`. You get the dashboard.

| You want | Press |
|---|---|
| Save | `Cmd+S` |
| Save all | `Cmd+Shift+S` |
| Close this file | `Cmd+W` |
| Undo / redo | `Cmd+Z` / `Cmd+Shift+Z` |
| Quit the editor | `Cmd+Q` |

If you are in a terminal instead of Neovide, use `:w`, `:q`, `:wq` and
`:q!` — and read the *Terminal* column of `KEYBINDINGS.md` for the Ctrl
fallbacks. This is not a limitation of the config; a terminal literally cannot
see the Cmd key.

If the screen ends up somewhere strange and you do not know why: `:Panic`. It
puts the six escape routes in the middle of the screen.

---

## 3. Moving around without hjkl

The arrow keys work. They will keep working. `:Beginner` turns on absolute line
numbers and arrows; `:VimMode` turns arrows off and relative numbers on, when
you want to push yourself.

The four motions worth learning early, because they are where the speed is:

- `w` — jump forward a word, `b` — back a word
- `0` — start of line, `$` — end of line
- `gg` — top of file, `G` — bottom
- `Ctrl+d` / `Ctrl+u` — half page down/up

And the one that will feel like magic: `ciw`.

Put the cursor on a variable, type `ciw`, type the new name, press `Esc`.
That is "change inner word": delete the word and put me in insert mode, which
in VS Code takes a double-click, a drag, or triple-click.

Other verbs work the same way: `d` (delete), `y` (copy), `c` (change),
followed by a motion or a text object. `d$` deletes to end of line. `yy` copies
the line. `p` pastes.

You do not need this on day one. You need `i`, `Esc`, and `u`.

---

## 4. Files: the picker is your sidebar

| Key | What it does |
|---|---|
| `Cmd+P` | find a file by name, anywhere in the project |
| `Cmd+Shift+F` | search the text of the whole project |
| `Cmd+F` | find in this file |
| `Cmd+H` | replace in this file |
| `Cmd+B` | toggle the file tree on the left |
| `Cmd+Shift+O` | jump to a symbol (function, class) in this file |
| `Cmd+T` | jump to a symbol anywhere (outline) |

Inside any picker: type to filter, `Ctrl+n`/`Ctrl+p` or the arrow keys to move,
`Enter` to open, `Esc` to close. It is fuzzy, so `usrh` finds
`user_repository_helpers.cs`.

`Cmd+Shift+P` is the **command palette**. It lists every Neovim command *and*
every keymap, so it doubles as "how do I do X, and what is the key for it".
This is the single most useful key in the whole config.

The file tree (`Cmd+B`) is a normal tree: single click selects, double click
opens, right-click gives you a context menu. It follows the file you are
editing, which is what VS Code's explorer does.

---

## 5. Tabs and splits

Open files appear in the tab strip at the top, exactly like VS Code. Click the
`x` or use `Cmd+W` to close one.

| Key | What it does |
|---|---|
| `Cmd+1` … `Cmd+9` | jump to that tab |
| `Ctrl+Tab` / `Cmd+Shift+]` | next tab |
| `Cmd+Shift+[` | previous tab |
| `Cmd+\` | split the editor vertically |

Splits: `Ctrl+w` then `h/j/k/l` moves between them, `Ctrl+w` then `=` evens them
out, and you can drag the divider with the mouse like any other window.

---

## 6. Editing conveniences you already rely on

| You are used to | Here |
|---|---|
| `Cmd+/` toggle comment | `Cmd+/` (also `gcc`, and `gc` in visual mode) |
| `Option+Up/Down` move line | `Option+Up/Down` |
| `Option+Shift+Up/Down` duplicate line | `Option+Shift+Up/Down` |
| `Cmd+D` select next occurrence | `Cmd+D` (adds a cursor) |
| `Cmd+Shift+L` select all occurrences | `Cmd+Shift+L` |
| Multi-cursor typing | just type; each cursor gets the text |
| `Esc` leaves multi-cursor | `Esc` |
| Surround with quotes/brackets | `sa` + motion + char, e.g. `saiw"` |

Auto-pairs are on: type `(` and you get `()`, type `"` and you get `""`.

Formatting happens on save. If you ever want to skip it for one file,
`:FormatToggle`.

---

## 7. Code intelligence

Language servers start automatically the first time you open a file of that
type. The first launch of a new language is slower because it downloads the
server (that is `:Mason` doing its thing, in the background).

| Key | What it does |
|---|---|
| `F12` | go to definition |
| `Shift+F12` | find all references |
| `F2` | rename a symbol everywhere |
| `Cmd+.` | code action / quick fix |
| `K` | hover documentation |
| `Cmd+Shift+M` | the problems panel |
| `[d` / `]d` | previous / next diagnostic |

The status bar shows which servers are attached to the current file. If it
shows nothing, the file's language is not one we support yet — see the
languages table in the README, and `:Mason` to add one.

---

## 8. The AI, which is why you are here

The AI is a real `opencode` process in a panel on the right. It edits files on
disk; Neovim reloads them instantly, so you watch the change happen.

| Key | What it does |
|---|---|
| `Cmd+I` | open/close the chat panel |
| `Cmd+K` | "do something with this" — pre-fills a prompt about the line or selection |
| `Cmd+Shift+K` | the menu of canned prompts (explain, review, tests, refactor, commit) |
| `Cmd+Shift+.` | fix the problem under the cursor |
| `Cmd+.` | (without Shift) the *editor's* quick fix, for comparison |
| `Ctrl+.` | show/hide the panel from anywhere, including inside the terminal |

The workflow that people actually use, in order of value:

1. **Explain.** Put the cursor on something confusing, `Cmd+K`, type
   "what does this do and when would it break?" then `Enter`.
2. **Fix.** Select the function, `Cmd+Shift+K`, choose `fix`. It reads the
   diagnostics for the selection, not the whole file — that is why the results
   are better than a chat window.
3. **Review before you commit.** `:AIDiff` sends your uncommitted diff and asks
   for bugs and risky changes. `:AICommit` writes the commit message.
4. **Tests.** Select a function, `Cmd+Shift+K`, `test`.

When OpenCode wants to write a file it shows you a diff and waits. `da` accepts
the whole edit, `dr` rejects it, `]c`/`[c` walk the hunks, `dp`/`do` accept or
reject a single hunk, `q` closes. Nothing lands on disk without that approval.

Two habits that make the answers much better:

- **Save first.** OpenCode reads files from disk, not from your unsaved buffer.
- **Select narrowly.** `@this` means "the selection, or the cursor position".
  A 30-line selection gets a better answer than a 900-line file.

Useful commands: `:Ask <question>`, `:AIExplain`, `:AIFix`, `:AIReview`,
`:AITests`, `:AIDiff`, `:AICommit`. For a bigger change, ask in the chat panel
and let it work — the panel is a full OpenCode session with its own plan/agent
mode.

---

## 9. Running things: .NET, React Native, Terraform

**C#/.NET** — open a `.cs` file and Roslyn attaches (solution-wide, real
IntelliSense, not the old OmniSharp).

| Command | What it does |
|---|---|
| `:DotnetBuild` | `dotnet build` in the project root |
| `:DotnetRun` | `dotnet run` |
| `:DotnetTest` | `dotnet test` |
| `:DotnetSolution` | pick the solution file for Roslyn |

Output appears in a terminal panel at the bottom; `Ctrl+\`` toggles it.

**React Native** — `:RN start`, `:RN ios`, `:RN android`. It detects Expo
projects and uses `npx expo start` when appropriate.

**Terraform** — `:Tf init`, `:Tf validate`, `:Tf plan`, `:Tf apply`, `:Tf fmt`.
`:Tf apply` always asks for confirmation first. `terraform fmt` also runs on
save, and `tflint` reports problems as you type. `terraform-ls` gives you
completion and hover for resources and variables.

---

## 10. Debugging

Debuggers are installed for C#, Node/TypeScript, and Python.

| Key | What it does |
|---|---|
| `F5` | start / continue |
| `Shift+F5` | stop |
| `F9` | toggle breakpoint |
| `F10` | step over |
| `F11` | step into |
| `Shift+F11` | step out |

On a Mac laptop the function keys need `Fn` (or "Use F1, F2 as standard
function keys" in System Settings → Keyboard). That is why every one of them
also has a leader alternative:

| Key | What it does |
|---|---|
| `Space d c` | continue |
| `Space d b` | toggle breakpoint |
| `Space d n` | step over |
| `Space d i` | step into |
| `Space d o` | step out |
| `Space d u` | show/hide the debugger panes |

Breakpoints show in the gutter and survive restarts. The debugger panes
(scopes, watches, call stack, REPL) open automatically when a session starts.

---

## 11. Git

`Space g g` opens **lazygit** in a floating window: stage with `Space`, commit
with `c`, push with `P`, quit with `q`. It is the same tool people use outside
Neovim, so nothing you learn here is wasted.

For quick looks without leaving the editor:

| Key | What it does |
|---|---|
| `Space g s` | git status: the changed files, ready to open |
| `]c` / `[c` | next / previous changed hunk (in a diff) |
| `Space f g` | the same status picker, if you think in terms of "find" |

The gutter shows added/changed/deleted markers per line once a file is in a
repository.

---

## 12. The terminal, and the "IDE layout"

`Ctrl+\`` toggles a terminal panel at the bottom. `Esc Esc` gets you out of
terminal mode and back into the editor (one `Esc` still reaches the program, so
`vim` inside a terminal still works).

If you want Neovim and the AI side by side and surviving a window close, use
the tmux layout instead:

```sh
ide            # in the current directory
ide ~/Dev/api  # or a specific project
ide kill       # end it
```

That gives you Neovim on the left and `opencode` on the right, in one tmux
session. Detach with `Ctrl+B d`, reattach with `ide`.

---

## 13. Making it yours

- **Theme:** `:Theme` (or `Space u t`). The choice is remembered.
- **Anything else:** put it in `~/.config/nvim/lua/local.lua`. That file is
  git-ignored and loaded last, so your settings win. It starts with examples.
- **Change a key:** edit the matching file in `~/.config/nvim/lua/keys/`. Each
  key is declared once, with a description; the help window, the which-key
  menu and `KEYBINDINGS.md` all update from that one line.
- **Add a language:** `:Mason`, install the server, then add its name to the
  `servers` list in `lua/plugins/lsp.lua`.
- **Update everything:** `:ConfigUpdate`.

---

## 14. When something is wrong

| Symptom | Fix |
|---|---|
| Typing does nothing | you are in Normal mode: press `i` |
| A red error appeared | `:messages` |
| A plugin broke after an update | `:Lazy restore`, then restart |
| No completion in a file | `:LspInfo`; the filetype may be unsupported |
| A server never installs | `:Mason`, look for the error, `:MasonLog` |
| Colours look wrong | `:Theme`, pick another |
| Everything is on fire | `Cmd+Q`, reopen; undo history is on disk |
| You want a full diagnosis | `:Health` |

Nothing here is precious: the config is a git repository, so
`git -C ~/.config/nvim log` shows every change and
`git -C ~/.config/nvim checkout .` undoes your last experiment.
