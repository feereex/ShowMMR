# ShowMMR 2026

**Your MMR, back in the Dota 2 match history.**

```
HERO PLAYED       RESULT         DATE / TIME          DURATION   TYPE
[icon] Lina       1489 (+40)     26-8-2026  17:37     56:19      Ranked
[icon] Axe        1449 (-26)     26-8-2026  16:55     34:48      Ranked
[icon] Crystal M. 1475 (+40)     25-8-2026  21:19     47:43      Ranked
```

```
[avatar] [medal]  CRUSADER 3
                  STAR  ▓▓▓▓▓▓▓░░░  143
                  RANK  ▓▓▓░░░░░░░  451
```

Valve took the numbers out. This puts them back — the rating after every ranked
match and what it cost or earned you, how far you are from the next star and the
next medal, plus a day-by-day strip above your profile.

Built on [AveYo's ShowMMR](https://github.com/AveYo/ShowMMR) (2023), rebuilt
from the ground up for the current client.

**Updates and new builds: [t.me/feereeks](https://t.me/feereeks)**

---

## What you get

| | |
|---|---|
| **Numbers in the match list** | `1489 (+40)` in the RESULT column, for every ranked game |
| **Live** | the number appears the moment you leave the post-game screen — no client restart |
| **Day strip** | `TODAY +14 (2)   YESTERDAY +90 (4)   MONDAY -30 (3)` above your profile |
| **Week / month totals** | hover the strip: this week, last week, the calendar month, all time |
| **Your colours** | win, loss, plain text, and Dota's own MMR block — presets or your own hex |
| **Several accounts** | kept apart automatically, no setup |

---

## Install

**1. Add `-condebug` to the Dota 2 launch options.**
Steam → right click Dota 2 → Properties → Launch Options.

Do this first. Without it the numbers still show, but everything you played is
forgotten the moment you close the client. The installer checks and reminds you.

**2. Close Dota 2 and run `Install.bat`.**

| | |
|---|---|
| `[1]` | you use Dota2SkinChanger — the mod goes into its folder, nothing else is touched |
| `[2]` | everything else — the mod gets its own `game\ShowMMR` folder and one `Game` + one `Mod` line is added to gameinfo |
| `[3]` | safe install — a folder Dota already mounts, no file modified at all |

**3. Play a ranked match.** The number is there when you get back to the
dashboard.

Everything else — the background sync that remembers your history — is set up
by the installer and runs with Windows. You never have to touch it.

---

## About gameinfo

Dota only reads folders that a search path names, so the standard install `[2]`
puts `Game ShowMMR` and `Mod ShowMMR` into the search paths.

**Only `gameinfo_branchspecific.gi` is touched. `gameinfo.gi` is never read and
never written.** On a clean client that branchspecific file is 17 lines of app
ids with no search paths at all, so there is nothing to edit — it is replaced
with the copy shipped in `files\`, which carries the stock paths plus our two
lines. If a skin changer already put a search path block there, the file is
*not* replaced: our two lines are added to that block and the other mod keeps
its mounts.

No backup is left inside the game folder. The original goes to
`%LOCALAPPDATA%\ShowMMR2026\gameinfo_backup\`, and `Uninstall.bat` puts it back
— or drops in the stock file shipped in `files\` if that copy is gone.

**`dota.signatures` is never touched.** The client checks `gameinfo` against
that list, so a modified `gameinfo` can upset matchmaking. Mod packs get around
it by faking the signature entry; this installer will not do that to your
client. If matchmaking ever complains, uninstall and use the safe install `[3]`,
which puts the mod in a folder Dota already mounts and modifies nothing at all.

Steam restores `gameinfo` on every Dota update, so after a patch run
`Install.bat` again.

Both `Install.bat` and `Uninstall.bat` ask for administrator rights up front —
Dota usually sits under `Program Files`, where writing needs them.

## Settings

`Settings.bat`:

- **win / loss numbers** — colour of `+40` and `-26`
- **plain text** — colour of the day names and game counts
- **MMR block** — recolours Dota's own rating, caption and Rank Confidence bar
- **day strip** — on or off

Eight presets or any hex you like. A colour you set replaces the old one
everywhere.

Out of the box: **green** wins, **red** losses, **white** text, and Dota's own
gold left alone on the MMR block.

---

## Notes

- Numbers appear only for ranked matches played **after** installing — the
  rating of a match the mod never saw cannot be recovered.
- The first recorded match shows `(+0)`. There is nothing older to subtract from.
- The installer covers every language folder it can find, so changing the
  client language normally keeps working. If you add a language Dota has never
  used before, run `Install.bat` again.
- A Dota patch can break any client mod. When that happens, a new build goes up
  at [t.me/feereeks](https://t.me/feereeks).

---

## License

See [LICENSE.txt](LICENSE.txt). Personal use. Do not redistribute the files —
if someone wants it, send them to [t.me/feereeks](https://t.me/feereeks).

Portions derived from ShowMMR by AveYo, MIT licensed; that notice and those
rights are reproduced in full in the license file.

Unofficial client-side interface modification. Not affiliated with or endorsed
by Valve Corporation.
