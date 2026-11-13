<#
.SYNOPSIS
    One-shot, idempotent setup of this Neovim config on Windows.

.DESCRIPTION
    The Windows counterpart of install.sh. It installs the tools Neovim needs
    with winget, copies this config to %LOCALAPPDATA%\nvim (backing up anything
    already there), and then runs Neovim once, headless, to install plugins and
    language tools.

    Safe to run again: every step checks before acting, and the only
    destructive action is MOVING an old config to a timestamped backup folder.

.PARAMETER Yes
    Do not ask questions. Good for re-runs and for dotfile automation.

.PARAMETER SkipGui
    Do not install Neovide.

.PARAMETER DryRun
    Print what would happen and change nothing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
    .\install.ps1 -Yes

.NOTES
    Requires Windows 10 1809 or newer and winget (App Installer). If winget is
    missing, install "App Installer" from the Microsoft Store first.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$SkipGui,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Bookkeeping
# ---------------------------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NvimDest  = Join-Path $env:LOCALAPPDATA 'nvim'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$Log       = Join-Path $ScriptDir 'install.log'

$Step = 0
function Step($msg) {
    $script:Step++
    Write-Host ""
    Write-Host "[$script:Step/8] $msg" -ForegroundColor Cyan
    Add-Content -Path $Log -Value "[$script:Step/8] $msg"
}
function Ok($msg)   { Write-Host "  OK   $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  !    $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  FAIL $msg" -ForegroundColor Red }
function Note($msg) { Write-Host "       $msg" -ForegroundColor DarkGray }

function Have($exe) {
    return [bool](Get-Command $exe -ErrorAction SilentlyContinue)
}

function Ask($prompt) {
    if ($Yes -or $DryRun) { return $true }
    $answer = Read-Host "  $prompt [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $true }
    return $answer -match '^[Yy]'
}

# Run a command, honouring -DryRun, and always log its output.
function Run([string]$exe, [string[]]$arguments) {
    $pretty = "$exe $($arguments -join ' ')"
    if ($DryRun) {
        Write-Host "       [dry-run] $pretty" -ForegroundColor DarkGray
        return $true
    }
    Add-Content -Path $Log -Value "`$ $pretty"
    try {
        & $exe @arguments *>> $Log
        return ($LASTEXITCODE -eq 0)
    } catch {
        Add-Content -Path $Log -Value $_.Exception.Message
        return $false
    }
}

Set-Content -Path $Log -Value "install.ps1 $(Get-Date -Format s)"
Write-Host "Log: $Log"
Write-Host "Neovim config installer  (Windows, Neovim 0.11+)" -ForegroundColor White
if ($DryRun) { Write-Host "DRY RUN - nothing will be installed." -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------
Step 'Checking this machine'

if (-not ($PSVersionTable.PSVersion.Major -ge 5)) {
    Fail 'PowerShell 5.1 or newer is required.'
    exit 1
}
Ok "PowerShell $($PSVersionTable.PSVersion)"

if (-not (Have 'winget')) {
    Fail 'winget is missing. Install "App Installer" from the Microsoft Store, then re-run.'
    Note 'Alternatively install Neovim, ripgrep, fd, git, node and Neovide by hand,'
    Note 'then run this script again with -SkipGui: it will copy the config and bootstrap plugins.'
    exit 1
}
Ok 'winget available'

# ---------------------------------------------------------------------------
# 2. Command-line tools
# ---------------------------------------------------------------------------
Step 'Installing command-line tools'

# logical tool -> winget package id
$Packages = [ordered]@{
    'nvim'     = 'Neovim.Neovim'
    'rg'       = 'BurntSushi.ripgrep.MSVC'
    'fd'       = 'sharkdp.fd'
    'git'      = 'Git.Git'
    'node'     = 'OpenJS.NodeJS.LTS'
    'lazygit'  = 'JesseDuffield.lazygit'
}
$GuiPackages = [ordered]@{
    'neovide'  = 'Neovide.Neovide'
}

foreach ($pair in $Packages.GetEnumerator()) {
    $exe = $pair.Key
    $id  = $pair.Value

    if (Have $exe) {
        Ok "$exe"
        continue
    }

    Note "installing $id"
    if (Ask "Install $id with winget?") {
        $args = @('install', '--id', $id, '--exact', '--silent',
                  '--accept-package-agreements', '--accept-source-agreements')
        if (Run 'winget' $args) {
            Ok "$id"
        } else {
            Warn "$id failed to install (see $Log)"
        }
    }
}

# Packages that are useful but not available through a package manager.
if (-not (Have 'tree-sitter')) {
    if (Have 'npm') {
        if (Ask 'Install tree-sitter-cli with npm (needed for syntax highlighting)?') {
            if (Run 'npm' @('install', '-g', 'tree-sitter-cli')) { Ok 'tree-sitter-cli' }
            else { Warn 'tree-sitter-cli failed; highlighting still works, just slower' }
        }
    } else {
        Warn 'npm not found yet - open a new terminal after this script and run:'
        Note '  npm install -g tree-sitter-cli'
    }
}

if (-not (Have 'opencode')) {
    Warn "the 'opencode' CLI is not on PATH"
    if (Ask 'Install the opencode CLI with npm?') {
        if (Run 'npm' @('install', '-g', 'opencode-ai')) { Ok 'opencode' }
        else { Note 'See https://opencode.ai/docs for the Windows install command.' }
    }
} else {
    Ok 'opencode'
}

if (Have 'dotnet') {
    Ok "dotnet $((& dotnet --version) 2>$null) (left untouched)"
} else {
    Note 'no .NET SDK: C# support stays inactive until you install one'
}

# ---------------------------------------------------------------------------
# 3. GUI
# ---------------------------------------------------------------------------
Step 'Installing the GUI'

if ($SkipGui) {
    Warn 'skipped (-SkipGui)'
} else {
    foreach ($pair in $GuiPackages.GetEnumerator()) {
        if (Have $pair.Key) { Ok $pair.Key; continue }
        Note "installing $($pair.Value)"
        if (Ask "Install $($pair.Value) with winget?") {
            $args = @('install', '--id', $pair.Value, '--exact', '--silent',
                      '--accept-package-agreements', '--accept-source-agreements')
            if (Run 'winget' $args) { Ok $pair.Value } else { Warn "$($pair.Value) failed" }
        }
    }

    Note 'Font: install "JetBrainsMono Nerd Font" from https://www.nerdfonts.com/font-downloads'
    Note '(download, unzip, right-click the .ttf files, "Install for all users").'
    Note 'Without it, icons show as empty boxes; everything else still works.'
}

$NeovideCfgDir = Join-Path $env:LOCALAPPDATA 'neovide'
if (-not $SkipGui -and (Have 'neovide')) {
    if (-not (Test-Path $NeovideCfgDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $NeovideCfgDir -Force | Out-Null }
    }
    $target = Join-Path $NeovideCfgDir 'config.toml'
    if (Test-Path $target) {
        if (-not $DryRun) { Copy-Item $target "$target.bak" -Force }
        Warn "existing Neovide config backed up to config.toml.bak"
    }
    if (-not $DryRun) {
        Copy-Item (Join-Path $ScriptDir 'extras\neovide\config.toml') $target -Force
    }
    Ok "Neovide settings written to $target"
}

# ---------------------------------------------------------------------------
# 4. This Neovim config
# ---------------------------------------------------------------------------
Step 'Installing the Neovim config'

if (-not (Test-Path (Join-Path $ScriptDir 'init.lua'))) {
    Fail "$ScriptDir does not look like the config (no init.lua)."
    exit 1
}

$sourceResolved = (Resolve-Path $ScriptDir).Path
$destResolved   = if (Test-Path $NvimDest) { (Resolve-Path $NvimDest).Path } else { $NvimDest }

if ($sourceResolved -eq $destResolved) {
    Ok "already running from $NvimDest - nothing to copy"
} else {
    if ((Test-Path $NvimDest) -and (Get-ChildItem $NvimDest -Force | Select-Object -First 1)) {
        $backup = "$NvimDest.backup.$Stamp"
        if (Ask "There is already a config at $NvimDest. Move it to $backup?") {
            if (-not $DryRun) { Move-Item $NvimDest $backup }
            Ok "old config moved to $backup"
        } else {
            Fail 'Not overwriting your config. Nothing else was changed.'
            exit 1
        }
    }

    if ($DryRun) {
        Note "[dry-run] copy $ScriptDir -> $NvimDest"
    } else {
        New-Item -ItemType Directory -Path $NvimDest -Force | Out-Null
        $exclude = @('.git', 'install.log', 'install.ps1')
        Get-ChildItem $ScriptDir -Force | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
            Copy-Item $_.FullName -Destination $NvimDest -Recurse -Force
        }
    }
    Ok "config installed at $NvimDest"
}

$localLua = Join-Path $NvimDest 'lua\local.lua'
if (-not (Test-Path $localLua) -and -not $DryRun) {
    @'
-- lua/local.lua
--
-- Your personal overrides. Git-ignored and loaded last, so your settings win.
-- Examples:
--   vim.opt.relativenumber = true
--   vim.o.guifont = "Cascadia Code:h12"
'@ | Set-Content -Path $localLua -Encoding UTF8
    Ok 'created lua/local.lua for your own tweaks'
}

# ---------------------------------------------------------------------------
# 5. Terminal settings
# ---------------------------------------------------------------------------
Step 'Configuring the terminal'

Note 'Windows Terminal is recommended. Set it as the default terminal host in'
Note 'Settings > Startup, and pick "JetBrainsMono Nerd Font Mono" as the font face.'
Note 'tmux and the `ide` layout are Unix-only; on Windows, split panes in Windows'
Note 'Terminal (Alt+Shift+D) and run nvim in one pane, opencode in the other.'

# ---------------------------------------------------------------------------
# 6. First boot
# ---------------------------------------------------------------------------
Step 'Installing plugins and language tools (this takes a few minutes)'

if ($DryRun) {
    Note '[dry-run] nvim --headless "+Lazy! sync" +qa'
    Note '[dry-run] nvim --headless "+lua require(''lazy'').load({plugins={''mason-tool-installer.nvim''}})" +MasonToolsInstallSync +qa'
} elseif (-not (Have 'nvim')) {
    Fail 'nvim is not on PATH yet. Open a new terminal, then run:'
    Note '  nvim --headless "+Lazy! sync" +qa'
    Note '  nvim --headless "+lua require(''lazy'').load({plugins={''mason-tool-installer.nvim''}})" +MasonToolsInstallSync +qa'
} else {
    # HTTP/1.1 avoids the "unexpected disconnect while reading sideband packet"
    # failures that HTTP/2 multiplexing causes on flaky connections. Applies
    # only to git processes started by this script.
    $env:GIT_CONFIG_COUNT = '1'
    $env:GIT_CONFIG_KEY_0 = 'http.version'
    $env:GIT_CONFIG_VALUE_0 = 'HTTP/1.1'

    Note 'plugins...'
    if (Run 'nvim' @('--headless', '"+Lazy! sync"', '+qa')) {
        Ok 'plugins installed'
    } else {
        Warn "plugin sync had errors (see $Log) - open Neovim and run :Lazy sync"
    }

    Note 'LSP servers, formatters, linters, debug adapters...'
    # install-tools.lua reads the lists out of the plugin specs and waits for
    # every install, which is more reliable than :MasonToolsInstallSync.
    if (Run 'nvim' @('--headless', "-c `"lua dofile('$NvimDest\scripts\install-tools.lua')`"", '-c', 'qa')) {
        Ok 'language tools installed'
    } else {
        Warn "some Mason tools failed (see $Log) - open Neovim and run :Mason"
    }

    Note 'Tree-sitter parsers compile in the background on your first launch.'
}

# ---------------------------------------------------------------------------
# 7. Git
# ---------------------------------------------------------------------------
Step 'Version control'

if (Test-Path (Join-Path $NvimDest '.git')) {
    Ok 'config is already a git repository'
} elseif (Have 'git') {
    Run 'git' @('-C', $NvimDest, 'init', '-q')     | Out-Null
    Run 'git' @('-C', $NvimDest, 'add', '-A')      | Out-Null
    $email = (& git -C $NvimDest config user.email) 2>$null
    if ($email) {
        Run 'git' @('-C', $NvimDest, 'commit', '-q', '-m', 'Initial Neovim config') | Out-Null
    } else {
        Warn 'git user.email is not set, so no commit was made'
        Note 'Set it with: git config --global user.email you@example.com'
    }
    Ok "git repository initialised at $NvimDest"
} else {
    Warn 'git not found, skipping'
}

# ---------------------------------------------------------------------------
# 8. What to do now
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[8/8] Done." -ForegroundColor Green
Write-Host @"

  Start here
    neovide                open the GUI
    nvim                   open in Windows Terminal

  On Windows the primary modifier is Ctrl (there is no Cmd key)
    Ctrl+Shift+P           the command palette
    Ctrl+P                 open a file by name
    Ctrl+S                 save
    Ctrl+K                 ask the AI about this line

  First five things to try
    1. Space, then wait    a menu of everything, grouped
    2. F1                  every key and command, generated live
    3. Ctrl+Shift+F        search the whole project
    4. F12 / Shift+F12     go to definition / find references
    5. F5                  start the debugger

  If anything looks broken
    :Health    full diagnostic
    :Panic     "how do I get out of here"
    :HelpMe    searchable list of every key
    log:       $Log

  Docs
    $NvimDest\README.md
    $NvimDest\KEYBINDINGS.md
    $NvimDest\docs\TUTORIAL.md

"@
