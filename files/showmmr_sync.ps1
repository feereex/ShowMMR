# ============================================================================
#  showmmr_sync.ps1 -- turn the mod's console output back into its history file
#
#  The Dota client cannot write to disk from a mod (every route was tested:
#  keybinds land in Steam userdata that LoadKeyValues cannot read, con_logfile
#  writes nothing, InitLogFile/AppendToLogFile are deprecated no-ops, archived
#  convars do not survive a restart, panorama has no storage API).
#
#  So the mod PRINTS its results and this script writes them:
#
#      game\dota\console.log            "ShowMMR-DATA <epoch> <mmr> <change>"
#              |
#              v
#      game\<mod folder>\cfg\showmmr_history.txt      read by the vscript at start
#
#  Requires "-condebug" in the Dota 2 launch options.
#
#  Usage:
#    showmmr_sync.ps1              sync once
#    showmmr_sync.ps1 -Watch       keep syncing every few seconds
# ============================================================================

param(
    [switch]$Watch,
    [int]$IntervalSeconds = 4,
    # add or correct matches by hand: -Set 1787591597=1345,1787603789=1385
    # (only needed for matches played before the mod was installed)
    [string[]]$Set = @(),
    # run the watcher hidden from now on, every time Windows starts
    [switch]$InstallStartup,
    [switch]$RemoveStartup,
    # appearance and options, merged onto whatever is already set:
    #   -Settings "win=#6FCF56,loss=#E45B5B,text=#B8C4C4,session=1,debug=0"
    # blank colour means "leave Dota's own colour there"
    [string]$Settings = '',
    # print a per-day breakdown of everything recorded so far
    [switch]$Report
)

$ErrorActionPreference = 'Stop'

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

# where the mod lives -> that is where its cfg folder goes
function Get-ModFolders($dotaPath) {
    $dirs = @()
    foreach ($d in (Get-ChildItem (Join-Path $dotaPath 'game') -Directory -ErrorAction SilentlyContinue)) {
        foreach ($v in (Get-ChildItem $d.FullName -Filter 'pak*_dir.vpk' -ErrorAction SilentlyContinue)) {
            # only the directory tree at the head of the file, not the whole archive
            $fs = [System.IO.File]::Open($v.FullName, 'Open', 'Read', 'ReadWrite')
            try {
                $len = [int][Math]::Min($fs.Length, 262144)
                $buf = New-Object byte[] $len
                [void]$fs.Read($buf, 0, $len)
                if ([System.Text.Encoding]::ASCII.GetString($buf) -match 'showmmr') {
                    $dirs += $d.FullName
                    break
                }
            } finally { $fs.Dispose() }
        }
    }
    # any folder that already holds a history file must be updated too - the game
    # mounts language folders BEFORE ShowMMR, so a stale copy there would win
    foreach ($d in (Get-ChildItem (Join-Path $dotaPath 'game') -Directory -ErrorAction SilentlyContinue)) {
        if ((Test-Path (Join-Path $d.FullName 'cfg\showmmr_history.txt')) -and ($dirs -notcontains $d.FullName)) {
            $dirs += $d.FullName
        }
    }
    if ($dirs.Count -eq 0) { $dirs = @((Join-Path $dotaPath 'game\ShowMMR')) }
    return $dirs
}


# The watcher rewrites this file every tick and Dota reads it whenever the mod
# asks for a reload, so a collision is a matter of time. Two defences: never
# write content that is already there, and retry briefly if someone holds it.
function Write-HistoryFile($path, $body) {
    $text = ($body -join "`r`n") + "`r`n"
    if (Test-Path $path) {
        try {
            if ((Get-Content $path -Raw -ErrorAction Stop) -eq $text) { return $true }
        } catch {}   # unreadable right now - fall through and try to write
    }
    for ($i = 0; $i -lt 6; $i++) {
        try {
            [System.IO.File]::WriteAllText($path, $text, [System.Text.Encoding]::ASCII)
            return $true
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    return $false
}

function Read-Existing($file) {
    $entries = @{}
    if (Test-Path $file) {
        $raw = Get-Content $file -Raw
        foreach ($m in [regex]::Matches($raw, '(\d+):\[(-?\d+),(-?\d+)\]')) {
            $entries[[long]$m.Groups[1].Value] = [int]$m.Groups[2].Value
        }
    }
    return $entries
}

# ---------------------------------------------------------------------------
#  Per-account storage.
#
#  Several accounts on one PC share one history file, and their ratings sit
#  close together - so mixing them silently produces wrong deltas rather than
#  something obviously broken. The master list therefore keeps every account
#  separate, and only the account currently logged in gets written into the
#  file the mod reads. Switching account restarts Dota, the next tick sees the
#  new steamid in console.log and rewrites that file.
#
#  Kept outside the mod folder so re-extracting the zip cannot wipe it.
# ---------------------------------------------------------------------------
$script:AccountsFile = Join-Path $env:LOCALAPPDATA 'ShowMMR2026\accounts.txt'

function Read-Accounts {
    $acc = @{}
    if (Test-Path $script:AccountsFile) {
        foreach ($line in (Get-Content $script:AccountsFile)) {
            if ($line -match '^\s*"?(\d{5,})"?\s+"(.*)"\s*$') {
                $id = $matches[1]
                $map = @{}
                foreach ($m in [regex]::Matches($matches[2], '(\d+):(-?\d+)')) {
                    $map[[long]$m.Groups[1].Value] = [int]$m.Groups[2].Value
                }
                $acc[$id] = $map
            }
        }
    }
    return $acc
}

function Write-Accounts($acc) {
    $dir = Split-Path $script:AccountsFile -Parent
    [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('showmmr_accounts')
    $lines.Add('{')
    foreach ($id in ($acc.Keys | Sort-Object)) {
        $parts = @()
        foreach ($k in ($acc[$id].Keys | Sort-Object -Descending)) {
            $parts += ("{0}:{1}" -f $k, $acc[$id][$k])
        }
        $lines.Add(("`t{0}`t`t`"{1}`"" -f $id, ($parts -join ',')))
    }
    $lines.Add('}')
    $text = ($lines -join "`r`n") + "`r`n"
    for ($i = 0; $i -lt 6; $i++) {
        try { [System.IO.File]::WriteAllText($script:AccountsFile, $text, [System.Text.Encoding]::ASCII); return }
        catch { Start-Sleep -Milliseconds 250 }
    }
}

function Sync-Once($dota, $modDirs) {
    $log = Join-Path $dota 'game\dota\console.log'
    if (-not (Test-Path $log)) {
        Write-Host '  console.log not found - add "-condebug" to the Dota 2 launch options.' -ForegroundColor Yellow
        return 0
    }

    $acc = Read-Accounts
    $before = 0
    if ($script:Account -and $acc.ContainsKey($script:Account)) { $before = $acc[$script:Account].Count }

    function Add-Entry($acc, $id, $epoch, $mmr) {
        if (-not $acc.ContainsKey($id)) { $acc[$id] = @{} }
        $acc[$id][[long]$epoch] = [int]$mmr
    }

    # the mod prints: ShowMMR-DATA <epoch> <mmr> <change>
    # follow the log instead of re-reading it: it grows to megabytes over a session.
    # Dota stamps "AuthStatus (steamid:...)" on every logon, so walking the log in
    # order tells us which account each result belongs to - even across sessions.
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        if ($script:LogPos -gt $fs.Length) { $script:LogPos = 0 }  # log was cleared
        [void]$fs.Seek($script:LogPos, 'Begin')
        $sr = New-Object System.IO.StreamReader($fs)
        while (($line = $sr.ReadLine()) -ne $null) {
            if ($line -match 'AuthStatus\s*\(steamid:(\d+)\)') {
                $script:Account = $matches[1]
            }
            elseif ($line -match 'ShowMMR-DATA\s+(\d+)\s+(\d+)\s+(-?\d+)') {
                if (-not $script:Account) { $script:Account = 'unknown' }
                Add-Entry $acc $script:Account $matches[1] $matches[2]
            }
            # older builds printed it in prose - pick those up too, so an existing
            # console.log still yields its matches
            elseif ($line -match 'ShowMMR: saving match (\d+) mmr (\d+)') {
                if (-not $script:Account) { $script:Account = 'unknown' }
                Add-Entry $acc $script:Account $matches[1] $matches[2]
            }
            elseif ($line -match 'epoch (\d+) -> mmr (\d+)') {
                if (-not $script:Account) { $script:Account = 'unknown' }
                Add-Entry $acc $script:Account $matches[1] $matches[2]
            }
        }
        $script:LogPos = $fs.Position
    } finally { $fs.Dispose() }

    if (-not $script:Account) { $script:Account = 'unknown' }

    # one-time import of the old single-account history file
    if ($script:NeedMigrate) {
        foreach ($d in $modDirs) {
            foreach ($k in (Read-Existing (Join-Path $d 'cfg\showmmr_history.txt')).GetEnumerator()) {
                Add-Entry $acc $script:Account $k.Key $k.Value
            }
        }
        $script:NeedMigrate = $false
    }

    # anything the user added by hand goes to the account that is logged in
    foreach ($s in $script:ManualSet) {
        foreach ($pair in ($s -split ',')) {
            if ($pair -match '^\s*(\d+)\s*=\s*(\d+)\s*$') {
                Add-Entry $acc $script:Account $matches[1] $matches[2]
            } elseif ($pair.Trim() -ne '') {
                throw "Bad -Set value '$pair'. Expected epoch=mmr, e.g. 1787591597=1345"
            }
        }
    }
    $script:ManualSet = @()   # apply hand edits once, then let the file carry them

    if ($acc.Count -eq 0) { return 0 }
    Write-Accounts $acc
    $script:Accounts = $acc

    # only the account that is logged in right now goes into the game's file
    $entries = $acc[$script:Account]
    if ($entries -eq $null -or $entries.Count -eq 0) { return 0 }

    # changes are always recomputed from neighbouring MMR values
    $keys = @($entries.Keys | Sort-Object)
    $parts = New-Object System.Collections.Generic.List[string]
    for ($i = $keys.Count - 1; $i -ge 0; $i--) {
        $chg = if ($i -eq 0) { 0 } else { $entries[$keys[$i]] - $entries[$keys[$i-1]] }
        $parts.Add(("{0}:[{1},{2}]" -f $keys[$i], $entries[$keys[$i]], $chg))
    }

    # ONE KEY PER MATCH, not one long string.
    #
    # The whole history used to go into a single "data" value. A KeyValues value
    # is capped at about a kilobyte, and at ~26 characters per match that ceiling
    # arrives around the fortieth game: the value gets cut mid-entry and every
    # match past the cut silently disappears. One line each has no such ceiling.
    $body = New-Object System.Collections.Generic.List[string]
    $body.Add('showmmr') | Out-Null
    $body.Add('{') | Out-Null
    foreach ($p in $parts) {
        if ($p -match '^(\d+):\[(-?\d+),(-?\d+)\]$') {
            $body.Add(("`t{0}`t`t`"{1},{2}`"" -f $matches[1], $matches[2], $matches[3])) | Out-Null
        }
    }
    $body.Add('}') | Out-Null
    $body = @($body)
    foreach ($d in $modDirs) {
        $dir = Join-Path $d 'cfg'
        [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        if (-not (Write-HistoryFile (Join-Path $dir 'showmmr_history.txt') $body)) {
            Write-Host "  could not write $dir\showmmr_history.txt - still locked, will retry next tick" -ForegroundColor Yellow
        }
    }

    return ($entries.Count - $before)
}

$script:ManualSet = $Set
$script:LogPos = 0
$script:Account = $null                                    # steamid currently logged in
$script:Accounts = @{}
$script:NeedMigrate = -not (Test-Path (Join-Path $env:LOCALAPPDATA 'ShowMMR2026\accounts.txt'))

if ($Settings -ne '') {
    $dota = Find-Dota2 -NoPrompt
    $modDirs = Get-ModFolders $dota

    # start from what is already on disk so a change to one option does not wipe
    # the others
    $cur = @{ win = ''; loss = ''; text = ''; mmr = ''; session = ''; debug = '' }
    foreach ($d in $modDirs) {
        $f = Join-Path $d 'cfg\showmmr_settings.txt'
        if (-not (Test-Path $f)) { $f = Join-Path $d 'cfg\showmmr_colors.txt' }
        if (Test-Path $f) {
            $raw = Get-Content $f -Raw
            foreach ($k in @('win','loss','text','mmr','session','debug')) {
                if ($raw -match ('"?' + $k + '"?\s+"([^"]*)"')) { $cur[$k] = $matches[1] }
            }
        }
    }

    foreach ($pair in ($Settings -split ',')) {
        if ($pair.Trim() -eq '') { continue }
        if ($pair -match '^\s*(win|loss|text|mmr)\s*=\s*(#?[0-9A-Fa-f]{6})?\s*$') {
            $v = $matches[2]
            if ($v -and $v -notlike '#*') { $v = '#' + $v }
            $cur[$matches[1]] = [string]$v
        }
        elseif ($pair -match '^\s*(session|debug)\s*=\s*([01])\s*$') {
            $cur[$matches[1]] = $matches[2]
        }
        else {
            throw "Bad -Settings value '$pair'. Expected win=#RRGGBB, loss=#RRGGBB, text=#RRGGBB, mmr=#RRGGBB, session=0|1 or debug=0|1"
        }
    }

    # Old settings first, new settings second. A copy left in a folder that is
    # mounted earlier than ours silently wins - which looked exactly like "the
    # colour did not change". So every stale file goes, everywhere under game\,
    # including the showmmr_colors.txt name the first build used, and only then
    # is the new one written.
    foreach ($g in (Get-ChildItem (Join-Path $dota 'game') -Directory -ErrorAction SilentlyContinue)) {
        foreach ($n in @('showmmr_settings.txt', 'showmmr_colors.txt')) {
            $old = Join-Path $g.FullName ('cfg\' + $n)
            if (Test-Path $old) {
                try { Remove-Item $old -Force; Write-Host "  removed old $old" -ForegroundColor DarkYellow } catch {}
            }
        }
    }

    $body = @('showmmr_settings', '{',
              ("`twin`t`t`"" + $cur['win'] + "`""),
              ("`tloss`t`t`"" + $cur['loss'] + "`""),
              ("`ttext`t`t`"" + $cur['text'] + "`""),
              ("`tmmr`t`t`"" + $cur['mmr'] + "`""),
              ("`tsession`t`"" + $cur['session'] + "`""),
              ("`tdebug`t`t`"" + $cur['debug'] + "`""),
              '}')
    foreach ($d in $modDirs) {
        $dir = Join-Path $d 'cfg'
        [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        [void](Write-HistoryFile (Join-Path $dir 'showmmr_settings.txt') $body)
        Write-Host "  wrote $dir\showmmr_settings.txt" -ForegroundColor Green
    }

    Write-Host ''
    Write-Host ("  win     : {0}" -f $(if ($cur['win']  -eq '') { "Dota default" } else { $cur['win'] }))
    Write-Host ("  loss    : {0}" -f $(if ($cur['loss'] -eq '') { "Dota default" } else { $cur['loss'] }))
    Write-Host ("  text    : {0}" -f $(if ($cur['text'] -eq '') { "light grey" } else { $cur['text'] }))
    Write-Host ("  mmr blk : {0}" -f $(if ($cur['mmr'] -eq '') { "Dota gold" } else { $cur['mmr'] }))
    Write-Host ("  days    : {0}" -f $(if ($cur['session'] -eq '0') { "off" } else { "strip above the profile" }))
    Write-Host ("  log     : {0}" -f $(if ($cur['debug']   -eq '1') { "verbose (for troubleshooting)" } else { "quiet" }))
    Write-Host ''
    Write-Host '  Go back to the dashboard in Dota 2 to see it.'
    Write-Host ''
    return
}

if ($Report) {
    $acc = Read-Accounts

    # nothing in the master list yet (fresh install, or the sync never ran) -
    # fall back to whatever the game folder holds
    if ($acc.Count -eq 0) {
        $fallback = @{}
        foreach ($d in (Get-ModFolders (Find-Dota2 -NoPrompt))) {
            foreach ($k in (Read-Existing (Join-Path $d 'cfg\showmmr_history.txt')).GetEnumerator()) {
                $fallback[$k.Key] = $k.Value
            }
        }
        if ($fallback.Count -gt 0) { $acc = @{ 'this account' = $fallback } }
    }

    if ($acc.Count -eq 0) {
        Write-Host ''
        Write-Host '  Nothing recorded yet. Play a ranked match, then run [3].' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    # newest account first, so the one being played shows up at the top
    $order = $acc.Keys | Sort-Object -Property @{ Expression = {
        $ks = $acc[$_].Keys; if ($ks.Count) { ($ks | Measure-Object -Maximum).Maximum } else { 0 } } } -Descending

    foreach ($id in $order) {
        $map = $acc[$id]
        $keys = $map.Keys | Sort-Object
        if ($keys.Count -eq 0) { continue }

        $days = New-Object System.Collections.Specialized.OrderedDictionary
        $prev = 0
        foreach ($k in $keys) {
            $mmr = [int]$map[$k]
            $day = ([datetimeoffset]::FromUnixTimeSeconds([long]$k)).LocalDateTime.Date
            if (-not $days.Contains($day)) {
                $days[$day] = [pscustomobject]@{ Games = 0; Won = 0; Lost = 0; Change = 0; End = $mmr }
            }
            $row = $days[$day]
            $row.Games++
            $row.End = $mmr
            if ($prev -gt 0) {
                $delta = $mmr - $prev
                $row.Change += $delta
                if ($delta -gt 0) { $row.Won++ } elseif ($delta -lt 0) { $row.Lost++ }
            }
            $prev = $mmr
        }

        $first = ($keys | Select-Object -First 1)
        $last  = ($keys | Select-Object -Last 1)
        $total = [int]$map[$last] - [int]$map[$first]

        Write-Host ''
        if ($id -match '^\d+$') { Write-Host ("  Account {0}" -f $id) -ForegroundColor Cyan }
        else                     { Write-Host ("  {0}" -f $id)         -ForegroundColor Cyan }
        Write-Host '  -------------------------------------------------------------'
        Write-Host '   DATE                GAMES     W - L      CHANGE      MMR'

        # newest day at the top, same order as the match list in game.
        # The year is spelled out only once it is no longer the current one.
        $thisYear = (Get-Date).Year
        $fmt = { param($d) if ($d.Year -eq $thisYear) { $d.ToString('ddd dd MMM') } else { $d.ToString('ddd dd MMM yyyy') } }
        $ordered = @($days.Keys) ; [array]::Reverse($ordered)
        foreach ($day in $ordered) {
            $r = $days[$day]
            $sign = ''; if ($r.Change -gt 0) { $sign = '+' }
            $col = 'Gray'
            if ($r.Change -gt 0) { $col = 'Green' } elseif ($r.Change -lt 0) { $col = 'Red' }
            Write-Host ("   {0,-18}  {1,4}    {2,3} - {3,-3}   {4,7}   {5,6}" -f `
                (& $fmt $day), $r.Games, $r.Won, $r.Lost, ($sign + $r.Change), $r.End) -ForegroundColor $col
        }

        $sign = ''; if ($total -gt 0) { $sign = '+' }
        Write-Host '  -------------------------------------------------------------'
        Write-Host ("   {0,-18}  {1,4}                {2,7}   {3,6}" -f 'ALL', $keys.Count, ($sign + $total), [int]$map[$last])

        # the first recorded match has nothing before it, so its result is unknown
        if ($keys.Count -gt 1) {
            $best = $null; $worst = $null
            foreach ($day in $days.Keys) {
                $r = $days[$day]
                if ($best  -eq $null -or $r.Change -gt $days[$best].Change)  { $best  = $day }
                if ($worst -eq $null -or $r.Change -lt $days[$worst].Change) { $worst = $day }
            }
            Write-Host ''
            Write-Host ("   best day  : {0}  {1}{2}" -f (& $fmt $best),  $(if ($days[$best].Change  -gt 0) { '+' } else { '' }), $days[$best].Change)
            Write-Host ("   worst day : {0}  {1}{2}" -f (& $fmt $worst), $(if ($days[$worst].Change -gt 0) { '+' } else { '' }), $days[$worst].Change)
        }
    }

    Write-Host ''
    Write-Host '  Only matches the mod recorded are counted.' -ForegroundColor DarkGray
    Write-Host ''
    return
}

function Get-StartupLink {
    return (Join-Path ([Environment]::GetFolderPath('Startup')) 'ShowMMR sync.lnk')
}

# -----------------------------------------------------------------------------
#  Truly windowless autostart.
#
#  powershell.exe is a CONSOLE program. -WindowStyle Hidden is applied by the
#  host AFTER the console has already been allocated, so a shortcut pointing
#  straight at it flashes a black window at every boot and leaves a console
#  attached to the process that can be brought back up by accident.
#
#  wscript.exe is a GUI binary: it allocates no console at all, and Run with
#  intWindowStyle 0 gives the child none either. So the shortcut points at
#  wscript, wscript starts PowerShell, and nothing ever appears on screen.
#
#  The launcher lives in %LOCALAPPDATA%\ShowMMR2026 with the rest of the durable
#  state - re-extracting the zip cannot wipe it, and it is not inside the game
#  folder where it has no business being.
# -----------------------------------------------------------------------------
function Get-HiddenLauncher {
    $dir = Join-Path $env:LOCALAPPDATA 'ShowMMR2026'
    [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    return (Join-Path $dir 'showmmr_hidden.vbs')
}

function Write-HiddenLauncher($target) {
    $vbs = Get-HiddenLauncher
    $ps  = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    # in VBScript a doubled quote inside a string literal is one literal quote,
    # which is why the paths below are wrapped in "" and not "
    $lines = @(
        "' ShowMMR 2026 - starts the history sync with no window at all.",
        "' Written by showmmr_sync.ps1 -InstallStartup. Safe to delete by hand.",
        'Dim sh',
        'Set sh = CreateObject("WScript.Shell")',
        ('sh.Run """' + $ps + '"" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $target + '"" -Watch", 0, False')
    )
    [System.IO.File]::WriteAllText($vbs, (($lines -join "`r`n") + "`r`n"), [System.Text.Encoding]::ASCII)
    return $vbs
}

if ($RemoveStartup) {
    $startupLnk = Get-StartupLink
    $removed = 0
    if (Test-Path $startupLnk) { Remove-Item $startupLnk -Force; Write-Host "  Removed $startupLnk" -ForegroundColor Green; $removed++ }
    $vbs = Get-HiddenLauncher
    if (Test-Path $vbs) { Remove-Item $vbs -Force; Write-Host "  Removed $vbs" -ForegroundColor Green; $removed++ }
    if ($removed -eq 0) { Write-Host '  Nothing to remove - autostart was not set up.' -ForegroundColor Yellow }
    return
}

if ($InstallStartup) {
    $startupLnk = Get-StartupLink
    $self = $MyInvocation.MyCommand.Path
    $vbs  = Write-HiddenLauncher $self
    $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'

    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($startupLnk)
    $lnk.TargetPath  = $wscript
    $lnk.Arguments   = "`"$vbs`""
    $lnk.WorkingDirectory = (Split-Path $self -Parent)
    $lnk.WindowStyle = 7          # minimised, in case the shell honours it first
    $lnk.Description = 'ShowMMR history sync'
    $lnk.Save()

    Write-Host ''
    Write-Host '  Autostart installed - the sync runs with no window at all.' -ForegroundColor Green
    Write-Host "  $startupLnk"
    Write-Host "  $vbs"
    Write-Host '  Starting it once now so you do not have to reboot.'
    Start-Process -WindowStyle Hidden -FilePath $wscript -ArgumentList "`"$vbs`""
    Write-Host ''
    return
}

$dota = Find-Dota2 -NoPrompt
$modDirs = Get-ModFolders $dota

Write-Host ''
Write-Host '  ShowMMR 2026 :: sync' -ForegroundColor Cyan
Write-Host "  Dota 2  : $dota"
foreach ($d in $modDirs) { Write-Host "  Writing : $d\cfg\showmmr_history.txt" }
Write-Host ''

if ($Watch) {
    # a second watcher would fight the first one over the same file
    $createdNew = $false
    $mutex = New-Object System.Threading.Mutex($true, 'Global\ShowMMR_sync_watch', [ref]$createdNew)
    if (-not $createdNew) {
        Write-Host '  A ShowMMR sync watcher is already running - nothing to do here.' -ForegroundColor Yellow
        Write-Host '  (menu [9] installs a hidden one that starts with Windows)'
        Write-Host ''
        Start-Sleep -Seconds 3
        return
    }

    Write-Host "  Watching console.log every $IntervalSeconds s. Leave this window open while you play." -ForegroundColor Green
    Write-Host '  Ctrl+C to stop.'
    Write-Host ''
    while ($true) {
        try {
            $added = Sync-Once $dota $modDirs
            if ($added -gt 0) { Write-Host ("  {0:HH:mm:ss}  +{1} new match(es)" -f (Get-Date), $added) -ForegroundColor Green }
        } catch {
            Write-Host ("  {0:HH:mm:ss}  {1}" -f (Get-Date), $_.Exception.Message) -ForegroundColor Yellow
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

$added = Sync-Once $dota $modDirs
$file = Join-Path $modDirs[0] 'cfg\showmmr_history.txt'

if ($script:Accounts.Count -gt 0) {
    Write-Host '  Accounts seen in console.log:'
    foreach ($id in ($script:Accounts.Keys | Sort-Object)) {
        $mark = if ($id -eq $script:Account) { '  <- logged in now, this one is in the game file' } else { '' }
        Write-Host ("    {0}   {1,3} match(es){2}" -f $id, $script:Accounts[$id].Count, $mark) -ForegroundColor Green
    }
    Write-Host ''
}

if (Test-Path $file) {
    $entries = Read-Existing $file
    Write-Host ("  History : {0} match(es), {1} new" -f $entries.Count, $added) -ForegroundColor Green
    Write-Host ''
    Write-Host '  epoch        local time            mmr'
    Write-Host '  -------------------------------------------'
    foreach ($k in ($entries.Keys | Sort-Object -Descending | Select-Object -First 15)) {
        $when = [DateTimeOffset]::FromUnixTimeSeconds($k).LocalDateTime
        Write-Host ("  {0,-12} {1:yyyy-MM-dd HH:mm:ss}   {2,5}" -f $k, $when, $entries[$k])
    }
} else {
    Write-Host '  Nothing recorded yet.' -ForegroundColor Yellow
    Write-Host '  Play a ranked match with the mod installed, then run this again.'
    Write-Host '  (make sure "-condebug" is in the Dota 2 launch options)'
}
Write-Host ''
