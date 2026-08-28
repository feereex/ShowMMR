# ============================================================================
#  ShowMMR 2026 -- uninstaller
#
#  Removes the mod archive, the background sync, and any search path an older
#  build of ShowMMR added to gameinfo. Your MMR history is kept.
#  Run with Dota 2 CLOSED.
# ============================================================================

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

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

Write-Host ''
Write-Host '  ShowMMR 2026 :: uninstall' -ForegroundColor Cyan
Write-Host ''

$dota = Find-Dota2
Write-Host "  Dota 2   : $dota"
Write-Host ''

# --- the archives ------------------------------------------------------------
$gone = 0
foreach ($d in (Get-ChildItem (Join-Path $dota 'game') -Directory -ErrorAction SilentlyContinue)) {
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
        Write-Host "  removed $($v.FullName)" -ForegroundColor Green
        $gone++
    }
}
# our own folder is ours entirely - take it out whether or not the sniff above
# recognised what is in it
$own = Join-Path $dota 'game\ShowMMR'
if (Test-Path $own) {
    try {
        Remove-Item $own -Recurse -Force
        Write-Host "  removed $own" -ForegroundColor Green
        $gone++
    } catch {
        Write-Host "  could not remove $own - $_" -ForegroundColor Yellow
    }
}
if ($gone -eq 0) { Write-Host '  no ShowMMR archive found - already gone.' -ForegroundColor Yellow }

# --- the background sync -----------------------------------------------------
try {
    $startup = [Environment]::GetFolderPath('Startup')
    if ($startup) {
        $lnk = Join-Path $startup 'ShowMMR sync.lnk'
        if (Test-Path $lnk) {
            Remove-Item $lnk -Force
            Write-Host '  removed the Windows startup entry' -ForegroundColor Green
        }
    }
} catch { Write-Host "  could not check the startup folder: $_" -ForegroundColor Yellow }
foreach ($p in (Get-Process powershell -ErrorAction SilentlyContinue)) {
    try {
        if ($p.MainWindowTitle -eq '' -and $p.Path -and (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue).CommandLine -match 'showmmr_sync') {
            Stop-Process -Id $p.Id -Force
            Write-Host '  stopped the running sync' -ForegroundColor Green
        }
    } catch {}
}

# --- gameinfo ----------------------------------------------------------------
# Only gameinfo_branchspecific.gi was ever written to, so only it is put back.
# The original was kept outside the game folder; if it is gone, the stock file
# shipped next to this script does the same job.
$bs = Join-Path $dota 'game\dota\gameinfo_branchspecific.gi'
$bak = Join-Path $env:LOCALAPPDATA 'ShowMMR2026\gameinfo_backup\gameinfo_branchspecific.gi'
$stock = Join-Path $root 'gameinfo_stock.gi'

if (Test-Path $bs) {
    $lines = @(Get-Content $bs)
    $mine  = $false
    foreach ($l in $lines) { if ($l -match '^\s*(Game|Mod)(_NonTools)?\s+(ShowMMR|dota_mods)\s*$') { $mine = $true } }

    if (-not $mine) {
        Write-Host '  gameinfo_branchspecific.gi has nothing of ours in it - left alone' -ForegroundColor DarkGray
    } elseif (Test-Path $bak) {
        Copy-Item $bak $bs -Force
        Remove-Item $bak -Force
        Write-Host '  gameinfo_branchspecific.gi restored to how it was before the install' -ForegroundColor Green
    } else {
        # no backup: strip our lines, and if that empties the block back to
        # something meaningless, drop the stock file in
        $kept = @($lines | Where-Object { $_ -notmatch '^\s*(Game|Mod)(_NonTools)?\s+(ShowMMR|dota_mods)\s*$' })
        $others = $false
        foreach ($l in $kept) { if ($l -match '^\s*(Game|Mod)(_NonTools)?\s+(?!dota\s*$|core\s*$)\S+\s*$') { $others = $true } }
        if ($others) {
            Set-Content -Path $bs -Value $kept -Encoding ASCII
            Write-Host '  gameinfo_branchspecific.gi : our lines removed, another mod kept' -ForegroundColor Green
        } elseif (Test-Path $stock) {
            Copy-Item $stock $bs -Force
            Write-Host '  gameinfo_branchspecific.gi replaced with the stock file' -ForegroundColor Green
        } else {
            Set-Content -Path $bs -Value $kept -Encoding ASCII
            Write-Host '  gameinfo_branchspecific.gi : our lines removed' -ForegroundColor Green
        }
    }
}

# anything an older build left inside the game folder goes too
foreach ($stray in (Get-ChildItem (Join-Path $dota 'game\dota') -Filter '*.showmmr-backup' -ErrorAction SilentlyContinue)) {
    try { Remove-Item $stray.FullName -Force; Write-Host "  removed $($stray.Name)" -ForegroundColor Green } catch {}
}

Write-Host ''
Write-Host '  UNINSTALLED.' -ForegroundColor Green
Write-Host '  Your history is kept in %LOCALAPPDATA%\ShowMMR2026 - delete that folder'
Write-Host '  too if you want it gone.'
Write-Host ''
