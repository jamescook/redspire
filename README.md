# Battlespire on macOS

Get *The Elder Scrolls Legend: Battlespire* (Bethesda, 1997) running well on
Apple Silicon Macs, natively, via DOSBox — no Wine/CrossOver, no Rosetta.

You need to own a legitimate copy of the game (GOG, Steam, or an original
disc). This repo contains no game files or copyrighted assets — just setup
instructions and a launch script.

## 1. Install a DOSBox

```
brew install dosbox-staging
```

Do **not** use the plain `dosbox` Homebrew cask — it's an old build with no
arm64 slice, runs under Rosetta, and performs badly for this game.
(`dosbox-x` also works fine as an alternative; see the script's `--backend`
flag below.)

## 2. Get Battlespire v1.5

You need **v1.5**, not the original v1.3 retail release. v1.3 is broken under
DOSBox: wrong video mode, dead mouse, severe slowdown during any animation.

- **Own it on GOG or Steam?** Their copy is already v1.5. Use its game folder
  directly (no need to run it through Wine/the Steam client to play it in
  DOSBox). Steam AppID is `1812420` if you need to fetch files via `steamcmd`.
- **Only have a disc / `.bin`+`.cue` dump?** That's v1.3. Get the official 1.5
  patch (`batpat15.zip` or the self-extracting `batpat15.exe` — same content
  either way, ~1.1MB, 261 files) and apply it, overwriting the old files.
  [Internet Archive hosts it](https://archive.org/details/batpat15); wherever
  you get it from, verify the hash below before trusting it. The `.exe` in
  particular is just a ZIP with a stub, so you can unpack it with `unzip`/`7z`
  without ever executing it, if you'd rather not run a random old binary
  directly. To sanity-check what you downloaded:
  ```
  unzip batpat15.zip -d batpat15         # or: unzip batpat15.exe -d batpat15
  shasum -a 256 batpat15/GAME.EXE
  ```
  This build's `GAME.EXE` is known-good, hash `a07299044a65d3294450ada6312908c9
  0d26a6b265d13806010dd16527e0ee3e` (SHA-256) — confirmed by comparing two
  independently-sourced copies of the patch (byte-identical to each other) and
  the patched `GAME.EXE` against a legitimate GOG install's own `GAME.EXE`
  (also byte-identical). If your download's hash doesn't match, don't trust it.
  Then copy `batpat15/GAME.EXE` and `batpat15/GAMEDATA/*` into your game
  directory, overwriting the existing files (that's literally what applying
  the patch is — there's no installer, just files to copy over).

If ripping a disc yourself, extract the data track with `bchunk`:
```
brew install bchunk
bchunk -v Battlespire.bin Battlespire.cue Battlespire_track
```
This gives you `Battlespire_track01.iso` (used below) plus separate CD-audio
tracks for the game's music if you want those too.

## 3. Check the game's file layout

Open `SPIRE.CFG` in the game folder. It should say `path C:\` — meaning
`GAME.EXE` must sit at the **root** of whatever you mount as `C:`, not in a
subfolder, and the `MSS` sound-driver folder must be a sibling of `GAME.EXE` in
that same folder. If your copy has everything nested one level down (e.g.
`BATSPIRE/GAME.EXE`), mount that inner folder, not its parent.

## 4. Launch it

Use the included script:

```
./play-battlespire.sh /path/to/battlespire-folder
```

It auto-detects a CD image (`game.ins`, shipped by GOG/Steam installs) inside
the game folder, warns (but doesn't block) if it detects a v1.3 `GAME.EXE`,
and defaults to `dosbox-staging`. Pass a CD image explicitly if you're using
your own disc rip, and see `--help` for the fullscreen/memsize/backend flags:

```
./play-battlespire.sh --backend x -f /path/to/battlespire-folder /path/to/battlespire-data.iso
```

Or run DOSBox directly:

```
dosbox-staging \
  --set "dosbox memsize=48" \
  -c "MOUNT C /path/to/battlespire-folder" \
  -c "IMGMOUNT D /path/to/battlespire-data.iso -t iso" \
  -c "C:" \
  -c "set causeway=MAXMEM:70;PRE:40;NAME:spire.swp" \
  -c "game spire.cfg"
```

Replace `/path/to/battlespire-folder` with the directory from step 3
(containing `GAME.EXE`, `GameData`, `SPIRE.CFG`, `SPIRE.BAT`, `MSS`), and
`/path/to/battlespire-data.iso` with your CD image (GOG/Steam ship their own,
e.g. `game.ins` — use that instead of ripping your own if you have it).

To use dosbox-x instead, replace `dosbox-staging` with:
```
/Applications/dosbox-x.app/Contents/MacOS/DOSBox-X -nopromptfolder
```

## Notes

- Music plays via actual CD redbook audio tracks, not files. If you want music
  and are using your own disc rip, you need the full multi-track rip (data +
  audio tracks), not just the data-track `.iso`.
- If dosbox-x is quarantined by Gatekeeper after `brew install --cask
  dosbox-x-app`, clear it once with:
  ```
  xattr -d com.apple.quarantine /Applications/dosbox-x.app
  ```
- The Homebrew **formula** `dosbox-x` (as opposed to the `dosbox-x-app` cask)
  is built with `--enable-debug=heavy`, which costs real performance. Prefer
  the cask, or use `dosbox-staging`.

## Getting the files via SteamCMD

Only relevant if you don't already have GOG/Steam installed elsewhere and want
to pull just the files:

```
brew install steamcmd
steamcmd \
  +force_install_dir ~/Games/Battlespire \
  +login <your_steam_username> \
  +app_update 1812420 validate \
  +quit
```

Prompts for your Steam password (and Steam Guard code) interactively. AppID
`1812420`, depot `1812421` — confirmed via `steamcmd +login anonymous
+app_info_print 1812420 +quit` (public metadata, no purchase needed for that
part). Actually pulling the depot requires an account that owns the game.
Untested end-to-end here, but it's the same DOS game as GOG's, so it likely
carries the same v1.5 fix.

## License

The instructions, scripts, and any other original content in this repo are
licensed under the MIT License (see `LICENSE`). *The Elder Scrolls Legend:
Battlespire* itself is © Bethesda Softworks and is **not** included here —
buy it on [GOG](https://www.gog.com/) or [Steam](https://store.steampowered.com/).
