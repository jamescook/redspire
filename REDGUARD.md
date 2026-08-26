# Redguard on macOS — research notes (TBD)

*The Elder Scrolls Adventures: Redguard* (Bethesda, 1998) is a candidate
second game for this app, alongside Battlespire. This document is technical
research from a manual DOSBox smoke test, not yet user-facing instructions —
no app support exists yet (see beads for planned work). Written up here so
the findings survive between sessions.

## It runs

Both the GOG release and the raw two-disc retail original boot and play
their intro cinematics cleanly under `dosbox-staging` (0.82.2), with no
custom DOSBox fork required.

## Why this isn't Battlespire again

Redguard renders 3D via 3dfx Glide, not plain VGA/VESA. That sounds like it
should need GOG's bundled custom fork ("DOSBox SVN-Daum", confirmed via
`strings` on their `dosbox.exe` — it has real `VOODOO_PageHandler`/`GLIDE`
symbols), but it doesn't: **`dosbox-staging` has its own built-in 3dfx
Voodoo emulation** (`[voodoo]` config section, on by default). Point it at
the game and it works.

One thing IS needed that neither release ships as part of the actual game:
**`GLIDE2X.OVL`**, the DOS-side Glide driver the renderer (`RGFX.EXE`) looks
for on launch. It's absent from the GOG package, and confirmed absent
*anywhere* on the original retail discs (checked the mounted ISO and both
InstallShield cabinets). The fix is the same either way: pull
`glide2x_emu.ovl` out of GOG's own bundled DOSBox distribution
(`DOSBOX/glide2x_emu.ovl`, not `glide2x.ovl` — that variant is for real
hardware via nGlide, not DOSBox's software Voodoo emulation) and drop it in
next to `RGFX.EXE` as `GLIDE2X.OVL`. This will need to ship as a bundled app
resource, the same way `SPIRE.CFG`/`DIG.INI` are bundled for Battlespire —
except this one isn't sourced from the game at all, it's DOSBox-emulation
glue, so double check its license/redistribution terms before shipping it.

## GOG release

Extract with `innoextract` (same tool already used for Battlespire's GOG
installer). The resulting `Redguard/` folder already has a correct,
non-empty `sound/DIG.INI` and `MDI.INI` (Miles Sound System V4.0d) —
GOG's installer generated them at packaging time. No sound-config landmine
here, unlike Battlespire.

`game.ins` (bundled by GOG) is a single-file CD image: 1 data track
(MODE1/2352) + 6 redbook audio tracks, `imgmount`ed as `D:`.

## Raw retail discs (2-disc release: Install Disc + Play Disc)

Structurally similar to Battlespire's disc split — Disc 1 is the installer,
Disc 2 (7 tracks: 1 data + 6 redbook audio) is what you `imgmount` as `D:`
at runtime and matches GOG's `game.ins` layout track-for-track.

**Disc 1's installer is a real Windows InstallShield package**
(`SETUP.EXE` / `DATA1.CAB`), *not* a plain DOS file tree like Battlespire's
disc. `cabextract` can't open it — InstallShield used its own proprietary
CAB variant. Needed [`unshield`](https://github.com/twogood/unshield)
(`brew install unshield`) instead, which unpacks `DATA1.CAB`'s three file
groups (`Common_Files`, `Xngine_Art`, `3DFX_Art`) without touching Windows.
`Common_Files` + `3DFX_Art/fxart` merged together is the same DOS-mode
`Redguard/` payload GOG ships (confirmed: `RGFX.EXE` is byte-identical
between the two). `Xngine_Art/3dart` looks like assets for a non-3dfx
software-rendering fallback path — GOG's package doesn't include it, and
this hasn't been investigated further.

Two landmines, both confirmed by direct testing:

1. **`sound/DIG.INI` and `MDI.INI` on the disc are present but empty** —
   header comment only ("output by GSetSound"), no actual device config.
   Same underlying problem as Battlespire's *missing* `DIG.INI`: nothing
   configures the Miles Sound System until you run the interactive
   `setsound.exe`/`GSetSound.exe` tool by hand. Fix: same known-good
   `DIG.INI`/`MDI.INI` content pulled from a working GOG install, bundled
   as app resources and written in when the disc's copy is empty.
2. **No `GLIDE2X.OVL` anywhere on the disc** — see above; same fix as GOG.

`REDGUARD.EXE` from the raw disc is the same file *size* as GOG's but a
different MD5 — GOG patched it at some point, but this hasn't been shown to
matter: the raw disc's version ran the confirmed-working smoke test fine.

**No official Bethesda patch was ever released for Redguard** — confirmed
via web search (see below). Unlike Battlespire's mandatory v1.3→v1.5 patch,
there's no "you must be on version X" requirement here. (A fan-made
"Unofficial Redguard Patch" exists on Nexus Mods, fixing various bugs — it's
third-party content, not something to auto-fetch/bundle without separately
deciding on that.)

## Controls

Combat is 100% keyboard, no mouse, confirmed from the bundled manual PDF:
**S** draws/sheathes the sword (has to be drawn before Attack does
anything), then **Ctrl** = Attack, **Alt** = Defend, **Shift** = Run,
**Space** = Jump, arrow keys = move. Worth surfacing in onboarding UI if
this game gets added — mouse-only players will be as confused as I was
expecting mouse-driven combat.

## Steam release

Not tested — not purchased for this investigation. Likely the same
DOSBox-wrapper shape as Battlespire's Steam release (same publisher, same
GOG/Steam DOSBox-packaging pattern for their other DOS-era titles), but
that's an assumption, not a confirmed fact.

## Sources

- [MobyGames: Redguard patches](https://www.mobygames.com/game/972/the-elder-scrolls-adventures-redguard/patches/)
- [UESP: Redguard:Patch](https://en.uesp.net/wiki/Redguard:Patch)
- [Nexus Mods: Unofficial Redguard Patch](https://www.nexusmods.com/theelderscrollsadventuresredguard/mods/11)
