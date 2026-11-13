# Keybindings

Every keymap and command in this config, generated from the live registry.

```
Regenerate with:  :ConfigDocs
              or  nvim --headless -c "lua dofile('scripts/gen-docs.lua')" -c qa
```

## How the Cmd key reaches Neovim

This is the one thing that is genuinely different from VS Code, so it is
worth two minutes:

| Where you run Neovim | Do Cmd shortcuts work? |
|---|---|
| **Neovide** (recommended) | **Yes.** It is a native macOS app, so Cmd+S, Cmd+P, Cmd+Z arrive as `<D-s>`, `<D-p>`, `<D-z>`. |
| Ghostty / iTerm / Terminal.app | **No.** The terminal and macOS consume Cmd first; a program inside a terminal cannot see it. Use the *Terminal* column. |
| tmux + `ide` layout | Same as the terminal above, plus tmux's own prefix (`Ctrl+B`). |

Every Cmd shortcut therefore has a terminal fallback bound as well, shown in
the right-hand column below. Learn one column or the other, whichever you use.

Also worth knowing: `mousemoveevent` is on, so hover tooltips work; the mouse
is enabled everywhere; right-click opens a context menu.

## Files

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+Shift+S` | `Ctrl+Shift+S` | Save all files |
| `Cmd+O` | `Ctrl+Shift+O` | Open another file (browse) |
| `Cmd+S` | `Ctrl+S` | Save file |
| `Cmd+W` | `Ctrl+Shift+W` | Close tab (asks to save) |
| `Space fb` |  | Find an open file (buffers) |
| `Space fp` |  | Switch project |
| `Space fr` |  | Recent files |

## Editing

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+/` | `Ctrl+/` | Toggle comment |
| `Cmd+Shift+Z` | `Ctrl+Shift+Z` | Redo |
| `Cmd+Z` | `Ctrl+Z` | Undo (while typing) |
| `Cmd+Z` | `Ctrl+Z` | Undo |
| `Esc` |  | Clear search highlight |
| `Alt+Down` |  | Move line (or selection) down |
| `Alt+Shift+Down` |  | Duplicate line (or selection) down |
| `Alt+Shift+Up` |  | Duplicate line (or selection) up |
| `Alt+Up` |  | Move line (or selection) up |

## Clipboard

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+A` | `Ctrl+Shift+A` | Select all |
| `Cmd+C` | `Ctrl+C` | Copy selection |
| `Cmd+C` | `Ctrl+C` | Copy current line |
| `Cmd+V` | `Ctrl+V` | Paste from system clipboard |
| `Cmd+X` | `Ctrl+Shift+X` | Cut current line |
| `Cmd+X` | `Ctrl+Shift+X` | Cut selection |

## Search

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+Shift+F` | `Ctrl+Shift+F` | Search in all files |
| `Cmd+Shift+P` | `Ctrl+Shift+P` | Command palette (commands and keys) |
| `Cmd+F` |  | Find in file |
| `Cmd+H` |  | Replace in file |
| `Cmd+P` | `Ctrl+P` | Quick open file |
| `Space fS` |  | Symbols in the whole project |
| `Space fc` |  | Search Vim commands |
| `Space fh` |  | Search Vim help |
| `Space fk` |  | Search all keybindings |
| `Space fs` |  | Symbols in this file |
| `Space fw` |  | Search for the word under the cursor |

## AI

| Key | Terminal | What it does |
|---|---|---|
| `Ctrl+.` |  | Show/hide the AI panel |
| `Cmd+Shift+.` |  | AI: fix the problem under the cursor |
| `Cmd+Shift+K` |  | AI actions menu (explain, review, tests…) |
| `Cmd+I` |  | Open the AI chat |
| `Cmd+K` |  | Ask AI about this line or selection |
| `Space aa` |  | Ask AI about this |
| `Space ae` |  | AI: explain this code |
| `Space af` |  | AI: fix the diagnostics |
| `Space ag` |  | AI: go to the chat panel |
| `Space ap` |  | AI prompt picker |
| `Space ar` |  | AI: review this code |
| `Space at` |  | AI: add tests |

## LSP

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+.` |  | Quick fix / code action |
| `F12` |  | Go to definition |
| `F2` |  | Rename symbol everywhere |
| `Shift+F12` |  | Find all references (usages) |
| `Space ca` |  | Code action (quick fix, refactor) |
| `Space cd` |  | Show the problem on this line |
| `Space cf` |  | Format this buffer |
| `Space ch` |  | Hover documentation (bordered) |
| `Space ci` |  | Go to implementation |
| `Space cl` |  | Toggle code lens |
| `Space co` |  | Organise imports |
| `Space cr` |  | Rename symbol |
| `Space ct` |  | Go to type definition |

## Windows

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+\` | `Alt+\` | Split the editor vertically |
| `Cmd+B` | `Ctrl+Shift+B` | Toggle the file explorer |
| `Space e` |  | Toggle the file explorer |
| `Space wh` |  | Horizontal split  (resize: <C-w>+ / <C-w>-) |
| `Space wq` |  | Close this window  (not the file) |
| `Space wv` |  | Vertical split  (resize: <C-w>> / <C-w><) |

## Diagnostics

| Key | Terminal | What it does |
|---|---|---|
| `Cmd+Shift+M` |  | Problems panel (errors and warnings) |
| `Cmd+T` |  | Outline (symbols in this file) |
| `Space fd` |  | All problems in the project |
| `Space xX` |  | Problems in this file only |
| `Space xl` |  | Location list (window results) |
| `Space xq` |  | Quickfix list (search results) |
| `Space xx` |  | Problems panel (trouble) |
| `[d` |  | Previous problem |
| `]d` |  | Next problem |

## Debug

| Key | Terminal | What it does |
|---|---|---|
| `F10` |  | Debug: step over |
| `F11` |  | Debug: step into |
| `F5` |  | Debug: start / continue |
| `F9` |  | Debug: toggle breakpoint |
| `Shift+F11` |  | Debug: step out |
| `Shift+F5` |  | Debug: stop the session |
| `Space db` |  | Debug: toggle breakpoint |
| `Space dc` |  | Debug: start / continue |
| `Space de` |  | Debug: evaluate under cursor / selection |
| `Space di` |  | Debug: step into |
| `Space dn` |  | Debug: step over |
| `Space do` |  | Debug: step out |
| `Space dr` |  | Debug: toggle the REPL |
| `Space du` |  | Debug: toggle the debugger panels |

## Git

| Key | Terminal | What it does |
|---|---|---|
| `Space fg` |  | Changed files (git status) |
| `Space gc` |  | Toggle the git changes panel |
| `Space gg` |  | Open lazygit (git app) |
| `Space gs` |  | Git status: changed files |

## Terminal

| Key | Terminal | What it does |
|---|---|---|
| `Ctrl+`` |  | Toggle terminal (press again to hide) |
| `Esc Esc` |  | Leave terminal mode (press Esc twice) |

## Session

| Key | Terminal | What it does |
|---|---|---|
| `Space qd` |  | Stop saving this session |
| `Space ql` |  | Restore the last session |
| `Space qs` |  | Restore session for this folder |

## Terraform

| Key | Terminal | What it does |
|---|---|---|
| `Space ta` |  | Terraform: apply (asks to confirm) |
| `Space tf` |  | Terraform: format every file |
| `Space ti` |  | Terraform: init (download providers) |
| `Space tp` |  | Terraform: plan (preview changes) |
| `Space tv` |  | Terraform: validate the configuration |

## Mouse

| Key | Terminal | What it does |
|---|---|---|
| `RightMouse` |  | Context menu (right click) |

## UI

| Key | Terminal | What it does |
|---|---|---|
| `Space ;` |  | Pick a symbol from the breadcrumbs |
| `Space ul` |  | Toggle relative line numbers |
| `Space up` |  | Preview the image in this buffer |
| `Space ut` |  | Pick a theme |
| `Space uw` |  | Toggle line wrapping |
| `[;` |  | Go to the start of this code block |
| `];` |  | Go to the next code block |

## Help

| Key | Terminal | What it does |
|---|---|---|
| `F1` |  | Every key and command (this is the manual) |
| `Space hc` |  | Search all commands |
| `Space hh` |  | Cheat sheet of every key |
| `Space hk` |  | Search all keymaps |
| `Space hp` |  | What to press when stuck |
| `Space ht` |  | Beginner tutorial |

## Toggle

| Key | Terminal | What it does |
|---|---|---|
| `Space uc` |  | Toggle concealed markup |
| `Space ui` |  | Toggle indent guides |
| `Space us` |  | Toggle spell check |
| `Space uz` |  | Toggle soft wrap |

## Buffers

| Key | Terminal | What it does |
|---|---|---|
| `Ctrl+Tab` |  | Next tab |
| `Cmd+1` |  | Go to tab 1 |
| `Cmd+2` |  | Go to tab 2 |
| `Cmd+3` |  | Go to tab 3 |
| `Cmd+4` |  | Go to tab 4 |
| `Cmd+5` |  | Go to tab 5 |
| `Cmd+6` |  | Go to tab 6 |
| `Cmd+7` |  | Go to tab 7 |
| `Cmd+8` |  | Go to tab 8 |
| `Cmd+9` |  | Go to tab 9 |
| `Cmd+Shift+[` |  | Previous tab |
| `Cmd+Shift+]` |  | Next tab |
| `Space b1` |  | Go to buffer 1 |
| `Space b2` |  | Go to buffer 2 |
| `Space b3` |  | Go to buffer 3 |
| `Space b4` |  | Go to buffer 4 |
| `Space b5` |  | Go to buffer 5 |
| `Space b6` |  | Go to buffer 6 |
| `Space b7` |  | Go to buffer 7 |
| `Space b8` |  | Go to buffer 8 |
| `Space b9` |  | Go to buffer 9 |
| `Space bd` |  | Close buffer (pick its letter) |
| `Space bn` |  | Next buffer (like Ctrl+Tab) |
| `Space bo` |  | Close all other buffers (keeps unsaved ones) |
| `Space bp` |  | Previous buffer |

## Commands

Type `:` then the name. Tab completes. They are grouped by purpose.

### Files

| Command | What it does |
|---|---|
| `:NewFile` | Create a new file by name |
| `:OpenFolder` | Open a folder as the project |
| `:Preview` | Preview an image (png, jpg, webp, gif, svg) |
| `:Proj` | Switch project |

### Editing

| Command | What it does |
|---|---|
| `:Format` | Format the current buffer |
| `:FormatToggle` | Toggle format on save for this buffer |

### Search

| Command | What it does |
|---|---|
| `:Palette` | Open the command palette |

### AI

| Command | What it does |
|---|---|
| `:AIChat` | Open the AI chat panel |
| `:AICommit` | AI: write a commit message from the diff |
| `:AIDiff` | AI: review the uncommitted diff |
| `:AIExplain` | Explain the code under the cursor |
| `:AIFix` | Fix the diagnostics in this buffer |
| `:AIPanel` | Show or hide the AI chat panel |
| `:AIReview` | Review the code under the cursor |
| `:AITests` | Write tests for the code under the cursor |
| `:Ask` | Ask the AI (optionally with a question) |

### LSP

| Command | What it does |
|---|---|
| `:LspInfo` | Show language server status |

### Windows

| Command | What it does |
|---|---|
| `:Explorer` | Show or hide the file explorer |

### Diagnostics

| Command | What it does |
|---|---|
| `:Problems` | Open the problems panel |

### Git

| Command | What it does |
|---|---|
| `:GitChanges` | Show or hide the git changes panel |

### Session

| Command | What it does |
|---|---|
| `:SessionRestore` | Restore the session for this folder |
| `:SessionSave` | Save the current session |
| `:SessionStop` | Stop saving the current session |

### Terraform

| Command | What it does |
|---|---|
| `:Tf` | Run a Terraform command in the project root |

### .NET

| Command | What it does |
|---|---|
| `:DotnetBuild` | Build the .NET solution |
| `:DotnetRun` | Run the .NET project |
| `:DotnetSolution` | Pick the .NET solution/project for Roslyn |
| `:DotnetTest` | Run the .NET tests |

### React Native

| Command | What it does |
|---|---|
| `:RN` | React Native: start the bundler / run on a device |

### UI

| Command | What it does |
|---|---|
| `:Theme` | Pick a colourscheme |

### Config

| Command | What it does |
|---|---|
| `:Beginner` | Beginner mode (arrows on) |
| `:ConfigDocs` | Regenerate KEYBINDINGS.md |
| `:ConfigEdit` | Open this config for editing |
| `:ConfigUpdate` | Update plugins and Mason tools |
| `:Health` | Run :checkhealth |
| `:Home` | Open the start screen |
| `:Reload` | Reload the Neovim config |
| `:VimMode` | Vim mode (arrows off) |

### Help

| Command | What it does |
|---|---|
| `:HelpMe` | Show every key and command |
| `:HelpTutorial` | Open the beginner tutorial |
| `:Panic` | What to press when stuck |

## Vim motions worth learning first

You do not need these on day one — arrows work, and every Cmd shortcut is
bound. But these five give you the most speed for the least effort:

| Keys | Meaning |
|---|---|
| `h j k l` | left, down, up, right |
| `w` / `b` | next word / previous word |
| `ciw` | change the word under the cursor |
| `gg` / `G` | top of file / bottom of file |
| `dd` / `yy` / `p` | delete line / copy line / paste |

