# ShowMMR

Your MMR, back in the Dota 2 match history.

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

Your colours on the numbers, a day-by-day strip above the profile, and effects
if you want them - breathe, rainbow, fire, glitch, typewriter and more, with a
live preview in the window.

New builds: **[t.me/feereeks](https://t.me/feereeks)**

## Install

1. Close Dota 2
2. Run `ShowMMR.exe` and click through the three steps
3. Play a ranked game

That's it. One file, nothing else to download, no fix to run first.

It installs into the language folder your Dota already loads, so nothing in the
game gets edited. Launch options get written for you, and the sync that keeps
your history is set up on the way.

## How it works

You don't have to open anything yourself. After a ranked game it reads your
rating off the post-game screen, saves it, and puts you back on the page you
were on.

The UI blinks for a split second when you start Dota, and once more after a
match. That's it grabbing the page it needs. Most people don't catch it.

Gameplay is not touched, the game's memory is never read, and nothing is sent
anywhere. Client mods are still used at your own risk.

## Notes

- It only knows games you play after installing. Older ones can be imported -
  **import matches** in the window tells you how.
- The first game it records shows `(+0)`. There's nothing before it to compare
  against.
- Run `ShowMMR.exe` again any time to change colours or effects - your history
  stays as it is.
- A big Dota patch can break it. The client's layouts change and the mod is
  built against them, so wait for a new build on the channel. Your history is
  never touched either way.
- It asks for admin rights because Dota usually sits in `Program Files`.
- To remove it: right-click `uninstall.ps1` in
  `%LOCALAPPDATA%\ShowMMR2026\app\files` and choose *Run with PowerShell*.

## License

See [LICENSE.txt](LICENSE.txt). Free to pass on as long as you pass on the
whole thing unchanged, ask nothing for it, and credit
**[t.me/feereeks](https://t.me/feereeks)**.

Built on [AveYo's ShowMMR](https://github.com/AveYo/ShowMMR) (2023), MIT
licensed; that notice is reproduced in full in the license file.

Unofficial client-side interface modification. Not affiliated with or endorsed
by Valve Corporation.
