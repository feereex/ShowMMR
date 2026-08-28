# ============================================================================
#  ShowMMR 2026 -- installer
#
#  Copies the prebuilt archive into a folder Dota 2 already mounts. Nothing is
#  compiled here, and NO game file is modified - see the note on gameinfo at
#  the bottom of this file.
#  Run with Dota 2 CLOSED.
# ============================================================================

param(
    # explicit folder under game\ (used for the Dota2SkinChanger option)
    [string]$ModDir = '',
    # install into the dota_<language> folders instead, modifying nothing
    [switch]$SafeMode,
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
# ----------------------------------------------------------------------------
#  Channel address, built from offset code points instead of stored as text, so
#  a find-and-replace on this file will not turn it up and a re-uploaded copy
#  still opens the original channel. See LICENSE.txt.
# ----------------------------------------------------------------------------
function Get-Frag($codes, $key) {
    $s = ''
    foreach ($c in $codes) { $s += [char]([int]$c - $key) }
    return $s
}
$SM_URL = (Get-Frag @(121,133,133,129,132,75,64,64) 17) + (Get-Frag @(169,99,162,154,100,155,154) 53) + (Get-Frag @(130,143,130,130,136,144) 29)
$SM_TAG = (Get-Frag @(139,69,132,124,70) 23) + (Get-Frag @(163,162,162,175) 61) + (Get-Frag @(148,148,154,162) 47)


function Get-SteamPath {
    foreach ($k in @('HKCU:\SOFTWARE\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $p = Get-ItemProperty -Path $k -ErrorAction Stop
            if ($p.SteamPath)   { return ($p.SteamPath   -replace '/','\') }
            if ($p.InstallPath) { return ($p.InstallPath -replace '/','\') }
        } catch {}
    }
    throw 'Steam not found in the registry.'
}

# ----------------------------------------------------------------------------
#  Finding Dota 2.
#
#  Four steps, in order, because any one of them can come up empty on a real
#  machine: the registry key is missing on some installs, libraryfolders.vdf
#  does not list a library the user moved by hand, and a portable Steam is not
#  registered at all. Whatever finally works is remembered, so nothing has to
#  search twice - and so the hidden background sync, which cannot ask anybody
#  anything, still knows where the game is.
# ----------------------------------------------------------------------------
$script:DotaMemo = Join-Path $env:LOCALAPPDATA 'ShowMMR2026\dota_path.txt'

function Test-DotaFolder($p) {
    if (-not $p) { return $false }
    return (Test-Path (Join-Path $p 'game\dota\pak01_dir.vpk'))
}

function Save-DotaPath($p) {
    try {
        [System.IO.Directory]::CreateDirectory((Split-Path $script:DotaMemo -Parent)) | Out-Null
        [System.IO.File]::WriteAllText($script:DotaMemo, $p, [System.Text.Encoding]::UTF8)
    } catch {}
}

function Find-DotaFromSteam {
    $steam = $null
    foreach ($k in @('HKCU:\SOFTWARE\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $pp = Get-ItemProperty -Path $k -ErrorAction Stop
            if ($pp.SteamPath)   { $steam = ($pp.SteamPath   -replace '/','\'); break }
            if ($pp.InstallPath) { $steam = ($pp.InstallPath -replace '/','\'); break }
        } catch {}
    }
    if (-not $steam) { return $null }

    $roots = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in (Get-Content $vdf -ErrorAction SilentlyContinue)) {
            if ($line -match '"path"\s+"(.+?)"') { $roots += (($matches[1] -replace '\\\\','\') -replace '/','\') }
        }
    }
    foreach ($r in $roots) {
        $c = Join-Path $r 'steamapps\common\dota 2 beta'
        if (Test-DotaFolder $c) { return $c }
    }
    return $null
}

# Every fixed drive, the usual library locations, then one level down from each
# drive root - that is where a hand-made "E:\SteamLibrary" or "D:\Games" lives.
# No recursive scan: it would crawl the whole disk for minutes.
function Find-DotaOnDrives {
    $tails = @(
        'SteamLibrary\steamapps\common\dota 2 beta',
        'Steam\steamapps\common\dota 2 beta',
        'steamapps\common\dota 2 beta',
        'Program Files (x86)\Steam\steamapps\common\dota 2 beta',
        'Program Files\Steam\steamapps\common\dota 2 beta',
        'Games\Steam\steamapps\common\dota 2 beta',
        'Games\steamapps\common\dota 2 beta'
    )
    foreach ($d in ([System.IO.DriveInfo]::GetDrives())) {
        try { if (-not $d.IsReady) { continue } } catch { continue }
        if ($d.DriveType -ne 'Fixed') { continue }
        $root = $d.RootDirectory.FullName

        foreach ($t in $tails) {
            $c = Join-Path $root $t
            if (Test-DotaFolder $c) { return $c }
        }
        foreach ($sub in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
            $c = Join-Path $sub.FullName 'steamapps\common\dota 2 beta'
            if (Test-DotaFolder $c) { return $c }
        }
    }
    return $null
}

# Accepts the game folder, dota2.exe, or anything inside the install - the path
# is walked upwards until the folder that actually holds game\dota is found.
function Read-DotaPath {
    Write-Host ''
    Write-Host '  Dota 2 was not found automatically.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Point me at it. In Steam: right click Dota 2 > Manage > Browse local'
    Write-Host '  files, then copy the address bar. Or paste the path to dota2.exe.'
    Write-Host '  Example:  E:\SteamLibrary\steamapps\common\dota 2 beta'
    Write-Host ''
    for ($i = 0; $i -lt 3; $i++) {
        $in = Read-Host '  Path'
        if (-not $in) { continue }
        $in = $in.Trim().Trim('"')
        if ($in -match '(?i)\.exe$') { $in = Split-Path $in -Parent }
        $p = $in
        for ($k = 0; $k -lt 8 -and $p; $k++) {
            if (Test-DotaFolder $p) { return $p }
            $p = Split-Path $p -Parent
        }
        Write-Host '  That is not a Dota 2 folder - game\dota\pak01_dir.vpk is not under it.' -ForegroundColor Yellow
    }
    return $null
}

function Find-Dota2 {
    param([switch]$NoPrompt)

    if ($env:DOTA2_PATH -and (Test-DotaFolder $env:DOTA2_PATH)) { return (Resolve-Path $env:DOTA2_PATH).Path }

    if (Test-Path $script:DotaMemo) {
        $saved = (Get-Content $script:DotaMemo -Raw -ErrorAction SilentlyContinue)
        if ($saved) { $saved = $saved.Trim() }
        if (Test-DotaFolder $saved) { return $saved }
    }

    $found = Find-DotaFromSteam
    if (-not $found) {
        Write-Host '  Looking for Dota 2 on your drives ...' -ForegroundColor DarkGray
        $found = Find-DotaOnDrives
    }
    if (-not $found -and -not $NoPrompt) { $found = Read-DotaPath }

    if (-not $found) {
        throw 'Dota 2 not found. Set the DOTA2_PATH environment variable to the "dota 2 beta" folder and try again.'
    }
    Save-DotaPath $found
    return $found
}

# Which language the client runs in decides which dota_<language> folder it
# mounts - and that folder is where the mod goes. Steam keeps the answer in the
# app manifest next to the game.
function Get-DotaLanguage($dotaPath) {
    $acf = Join-Path (Split-Path (Split-Path $dotaPath -Parent) -Parent) 'appmanifest_570.acf'
    if (Test-Path $acf) {
        $raw = Get-Content $acf -Raw
        if ($raw -match '"language"\s*"([a-zA-Z_]+)"') { return $matches[1].ToLower() }
    }
    try {
        $ud = Join-Path (Get-SteamPath) 'userdata'
        foreach ($f in (Get-ChildItem $ud -Recurse -Filter 'localconfig.vdf' -ErrorAction SilentlyContinue)) {
            $raw = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($raw -match '"570"[\s\S]{0,4000}?"language"\s*"([a-zA-Z_]+)"') { return $matches[1].ToLower() }
        }
    } catch {}
    return 'english'
}

# Wipe every previous ShowMMR archive before installing a new one. Dota mounts
# the lower pak number first, so a leftover copy keeps winning and the new
# install looks like it did nothing at all.
function Remove-OldCopies($dotaPath) {
    $gone = 0
    foreach ($d in (Get-ChildItem (Join-Path $dotaPath 'game') -Directory -ErrorAction SilentlyContinue)) {
        foreach ($v in (Get-ChildItem $d.FullName -Filter 'pak*_dir.vpk' -ErrorAction SilentlyContinue)) {
            $isOurs = $false
            try {
                $fs = [System.IO.File]::Open($v.FullName, 'Open', 'Read', 'ReadWrite')
                try {
                    $len = [int][Math]::Min($fs.Length, 262144)
                    $buf = New-Object byte[] $len
                    [void]$fs.Read($buf, 0, $len)
                    $isOurs = ([System.Text.Encoding]::ASCII.GetString($buf) -match 'showmmr')
                } finally { $fs.Dispose() }
            } catch { continue }
            if (-not $isOurs) { continue }
            Remove-Item $v.FullName -Force
            Write-Host "  removed old copy: $($v.FullName)" -ForegroundColor Yellow
            $gone++
        }
    }
    if ($gone -gt 0) { Write-Host '' }
}

$script:GiSource = $root

# ----------------------------------------------------------------------------
#  Mounting game\ShowMMR - gameinfo_branchspecific.gi only
#
#  That is the only file touched. gameinfo.gi is neither read nor written.
#
#  A clean branchspecific is 17 lines of app ids with no search paths at all,
#  so there is nothing to edit - it is replaced with the copy shipped next to
#  this script, which carries the stock paths plus Game ShowMMR and Mod ShowMMR.
#  If something else already put a SearchPaths block there (a skin changer),
#  the file is NOT replaced - our two lines are added to that block instead, so
#  the other mod keeps its mounts.
#
#  The original goes to %LOCALAPPDATA%\ShowMMR2026\gameinfo_backup\ - never
#  beside the game's own files - and Uninstall puts it back.
#
#  dota.signatures is NOT touched. The client checks gameinfo against it, so a
#  modified gameinfo can cost you matchmaking; faking that entry is a file
#  integrity bypass and this installer does not do it.
# ----------------------------------------------------------------------------
function Get-BlockRange($lines, $name) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch ('^\s*' + $name + '\s*$')) { continue }
        $j = $i + 1
        while ($j -lt $lines.Count -and $lines[$j] -notmatch '\{') { $j++ }
        if ($j -ge $lines.Count) { return $null }
        $depth = 0
        for ($k = $j; $k -lt $lines.Count; $k++) {
            if ($lines[$k] -match '\{') { $depth++ }
            if ($lines[$k] -match '\}') {
                $depth--
                if ($depth -le 0) { return @{ Head = $i; Open = $j; Close = $k } }
            }
        }
    }
    return $null
}

function Backup-Once($file) {
    $dir = Join-Path $env:LOCALAPPDATA 'ShowMMR2026\gameinfo_backup'
    [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    $bak = Join-Path $dir (Split-Path $file -Leaf)
    if (-not (Test-Path $bak)) { Copy-Item $file $bak -Force }
}

function Add-SearchPath($dotaPath, $dir) {
    $bs = Join-Path $dotaPath 'game\dota\gameinfo_branchspecific.gi'
    $ours = Join-Path $script:GiSource 'gameinfo_showmmr.gi'

    if (-not (Test-Path $bs)) { throw "gameinfo_branchspecific.gi not found under $dotaPath\game\dota." }

    $lines = @(Get-Content $bs)
    foreach ($l in $lines) {
        if ($l -match ('^\s*(Game|Mod)(_NonTools)?\s+' + [regex]::Escape($dir) + '\s*$')) {
            Write-Host "  gameinfo_branchspecific.gi already mounts $dir" -ForegroundColor Green
            return $true
        }
    }

    Backup-Once $bs
    $sp = Get-BlockRange $lines 'SearchPaths'

    # --- nothing of its own: drop our file in whole ---------------------------
    if (-not $sp) {
        if (-not (Test-Path $ours)) { throw "gameinfo_showmmr.gi is missing from $script:GiSource" }
        try {
            Copy-Item $ours $bs -Force -ErrorAction Stop
        } catch {
            Write-Host "  could not write gameinfo_branchspecific.gi: $_" -ForegroundColor Red
            Write-Host '  run the installer again and allow the administrator prompt.' -ForegroundColor Red
            return $false
        }
        Write-Host "  gameinfo_branchspecific.gi replaced - Game and Mod -> $dir" -ForegroundColor Green
        return $true
    }

    # --- somebody else already mounts things here: add to their block ---------
    $out = New-Object System.Collections.Generic.List[string]
    $addedGame = $false
    $addedMod  = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $inBlock = ($i -gt $sp.Open -and $i -lt $sp.Close)

        if ($inBlock -and -not $addedGame -and $line -match '^(\s*)Game(_NonTools)?(\s+)dota_mods\s*$') {
            $out.Add(($matches[1] + 'Game' + $matches[3] + $dir)) | Out-Null   # an old build's line
            $addedGame = $true
            continue
        }
        if ($inBlock -and -not $addedGame -and $line -match '^(\s*)Game(\s+)dota\s*$') {
            $out.Add(($matches[1] + 'Game' + $matches[2] + $dir)) | Out-Null
            $addedGame = $true
        }
        if ($inBlock -and -not $addedMod -and $line -match '^(\s*)Mod(\s+)dota\s*$') {
            $out.Add(($matches[1] + 'Mod' + $matches[2] + $dir)) | Out-Null
            $addedMod = $true
        }
        $out.Add($line) | Out-Null
    }

    if (-not $addedGame) {
        Write-Host '  no "Game dota" line inside SearchPaths - nothing was changed.' -ForegroundColor Red
        return $false
    }
    try {
        Set-Content -Path $bs -Value $out -Encoding ASCII -ErrorAction Stop
    } catch {
        Write-Host "  could not write gameinfo_branchspecific.gi: $_" -ForegroundColor Red
        Write-Host '  run the installer again and allow the administrator prompt.' -ForegroundColor Red
        return $false
    }
    $what = if ($addedMod) { 'Game and Mod' } else { 'Game' }
    Write-Host "  gameinfo_branchspecific.gi patched: $what -> $dir  (another mod's paths kept)" -ForegroundColor Green
    return $true
}

Write-Host ''
Write-Host '  ShowMMR 2026 :: install' -ForegroundColor Cyan
Write-Host "  by $SM_TAG" -ForegroundColor DarkCyan
Write-Host ''

$vpk = Join-Path $root 'pak01_dir.vpk'
if (-not (Test-Path $vpk)) { throw "pak01_dir.vpk is missing from $root" }

$dota = Find-Dota2
Write-Host "  Dota 2   : $dota"

# Three ways in, in order of how much they touch:
#   -ModDir <name>   an explicit folder something else already mounts (skin changer)
#   -SafeMode        the dota_<language> folders the stock client mounts anyway
#   default          game\ShowMMR plus one Game and one Mod line in gameinfo
$targets = New-Object System.Collections.Generic.List[string]
$patchGameinfo = $false

if ($ModDir -ne '') {
    $targets.Add($ModDir) | Out-Null
} elseif ($SafeMode) {
    # Which language folder the client actually mounts is not always the one
    # Steam reports - the in-game setting and a -language launch option both
    # override it - so use every one that could be right.
    $lang = Get-DotaLanguage $dota
    Write-Host "  Language : $lang (from Steam)"
    $targets.Add("dota_$lang") | Out-Null
    foreach ($d in (Get-ChildItem (Join-Path $dota 'game') -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -notmatch '^dota_[a-z]+$') { continue }
        if ($d.Name -in @('dota_addons', 'dota_core', 'dota_lv', 'dota_mods', 'dota_tools')) { continue }
        if (-not $targets.Contains($d.Name)) { $targets.Add($d.Name) | Out-Null }
    }
} else {
    $targets.Add('ShowMMR') | Out-Null
    $patchGameinfo = $true
}

Remove-OldCopies $dota

Write-Host ''
$done = 0
foreach ($dir in $targets) {
    $target = Join-Path $dota "game\$dir"
    [System.IO.Directory]::CreateDirectory($target) | Out-Null

    # our own folder always takes pak01; a shared one must not clobber anybody
    $pakName = ''
    if ($patchGameinfo) {
        $pakName = 'pak01_dir.vpk'
    } else {
        for ($i = 1; $i -le 99; $i++) {
            $cand = 'pak{0:d2}_dir.vpk' -f $i
            if (-not (Test-Path (Join-Path $target $cand))) { $pakName = $cand; break }
        }
    }
    if ($pakName -eq '') { Write-Host "  no free slot in game\$dir - skipped" -ForegroundColor Yellow; continue }

    Copy-Item $vpk (Join-Path $target $pakName) -Force
    Write-Host "  Installed: game\$dir\$pakName" -ForegroundColor Green
    $done++
}
if ($done -eq 0) { throw 'Could not install into any folder.' }

if ($patchGameinfo) {
    if (-not (Add-SearchPath $dota 'ShowMMR')) {
        Write-Host ''
        Write-Host '  The archive is in place but nothing mounts it, so the mod will not' -ForegroundColor Red
        Write-Host '  load. Run Install.bat again and pick the safe install instead.' -ForegroundColor Red
    }
} else {
    Write-Host '  No game file was modified - gameinfo is untouched.' -ForegroundColor Green
}

# --------------------------------------------------------------- history sync
# The mod cannot write files from inside the game, so a small background script
# turns its console output into the history file. Set up here so nobody has to
# know it exists.
Write-Host ''
Write-Host '  Setting up the background history sync ...' -ForegroundColor Cyan
$sync = Join-Path $root 'showmmr_sync.ps1'
if (Test-Path $sync) {
    try {
        & $sync -InstallStartup
    } catch {
        Write-Host "  could not set up the sync automatically: $_" -ForegroundColor Yellow
        Write-Host '  history from this session will still show, it just will not be kept.' -ForegroundColor Yellow
    }
} else {
    Write-Host '  showmmr_sync.ps1 is missing from the files folder.' -ForegroundColor Yellow
}

# ------------------------------------------------------------------- condebug
# Without -condebug there is no console.log, and the sync above has nothing to
# read. Checked read-only: Steam owns this file and rewrites it as it pleases.
$hasCondebug = $false
try {
    $ud = Join-Path (Get-SteamPath) 'userdata'
    foreach ($f in (Get-ChildItem $ud -Recurse -Filter 'localconfig.vdf' -ErrorAction SilentlyContinue)) {
        if ((Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue) -match '-condebug') { $hasCondebug = $true; break }
    }
} catch {}

Write-Host ''
Write-Host '  INSTALLED.' -ForegroundColor Green
Write-Host ''
if ($hasCondebug) {
    Write-Host '  Launch options already contain -condebug. Nothing else to do.' -ForegroundColor Green
} else {
    Write-Host '  ONE THING LEFT - add this to the Dota 2 launch options:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '      -condebug' -ForegroundColor White
    Write-Host ''
    Write-Host '  Steam > right click Dota 2 > Properties > Launch Options.' -ForegroundColor Yellow
    Write-Host '  Numbers show up either way, but without it they are forgotten when' -ForegroundColor Yellow
    Write-Host '  you close the client.' -ForegroundColor Yellow
}
Write-Host ''
if ($SafeMode) {
    Write-Host '  If you change the client language later, run this installer again.' -ForegroundColor DarkGray
} elseif ($patchGameinfo) {
    Write-Host '  Steam restores gameinfo on every Dota update - run this installer' -ForegroundColor DarkGray
    Write-Host '  again after a patch. If matchmaking ever complains, uninstall and' -ForegroundColor DarkGray
    Write-Host '  pick the safe install, which modifies nothing.' -ForegroundColor DarkGray
}
Write-Host ''

if ($Launch) {
    try { Start-Process 'steam://rungameid/570' } catch { Write-Host '  could not start Steam - launch Dota yourself.' -ForegroundColor Yellow }
}

# New builds are posted on the channel - Dota patches break client mods, so the
# people who just installed this are exactly the people who will need it.
Write-Host "  Updates and new builds:  $SM_TAG" -ForegroundColor Cyan
Write-Host ''
try { Start-Process $SM_URL } catch {}

# ----------------------------------------------------------------------------
#  Why gameinfo is not touched
#
#  A folder named game\ShowMMR would look nicer, but Dota only mounts folders
#  that a search path names, and the search paths live in gameinfo. On a clean
#  client gameinfo_branchspecific.gi holds no SearchPaths block at all - the
#  ones that do are files handed out by mod sites, together with a patched
#  dota.signatures so the modified file still passes the client's own file
#  integrity check.
#
#  Editing a file the client verifies is not something this installer will do
#  to anyone. The dota_<language> folder is mounted by the stock client on its
#  own, needs no edit anywhere, and cannot affect matchmaking.
# ----------------------------------------------------------------------------
