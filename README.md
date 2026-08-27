# Redspire

A native macOS app for playing two classic Bethesda DOS games on Apple
Silicon, via DOSBox — no Wine/CrossOver, no Rosetta. The name's a portmanteau
of the two games it supports:

- *The Elder Scrolls Legend: Battlespire* (1997)
- *The Elder Scrolls Adventures: Redguard* (1998)

You need to own a legitimate copy of whichever game you want to play — GOG,
Steam, or the original disc(s). This repo contains no game files or
copyrighted assets, just the launcher app and setup instructions.

![Redspire's Battlespire launcher window](assets/window.png)

## Getting started

There's no pre-built download yet — see [Building from
source](#building-from-source) below to get the app running.

Once it's open:

1. Pick **Battlespire** or **Redguard** at the top of the window.
2. Click **Setup Wizard…** and tell it how you have the game:
   - **GOG** — point it at the installer you downloaded; it unpacks it for you.
   - **Steam** — it can detect an install you already have, or download the
     game for you if you give it your Steam login (nothing leaves your Mac).
   - **The original disc(s)** — point it at a disc image and it extracts and
     repairs everything that needs fixing. (Yes, that's a real thing — these
     25-year-old installers set up some files DOSBox never runs on its own;
     the app does that part for you.)
3. Click **Play**.

If DOSBox itself isn't installed, the app offers to install it for you too.
That's the whole workflow — the wizard handles CD images, sound driver
setup, and known compatibility fixes automatically, so you don't need to
understand how DOSBox or these old installers work under the hood.

## Building from source

```
brew install dosbox-staging innoextract unshield swiftlint
```

From the `App/` folder of this repository:

```
swift test        # optional, confirms everything's working
swiftlint lint     # optional, style/consistency checks (also runs in CI)
./build.sh
open dist/Redspire.app
```

`build.sh` also supports signed, notarized builds for distributing outside
your own Mac — see the comments at the top of the script.

## Troubleshooting

- Prefer `dosbox-staging` over the `dosbox-x` **Homebrew formula** — that
  formula is built with `--enable-debug=heavy`, which costs real
  performance. The `dosbox-x-app` **cask** is fine as an alternative if you
  want to try dosbox-x.
- If dosbox-x is quarantined by Gatekeeper after `brew install --cask
  dosbox-x-app`, clear it once with:
  ```
  xattr -d com.apple.quarantine /Applications/dosbox-x.app
  ```

## License

The app, scripts, and any other original content in this repo are licensed
under the MIT License (see `LICENSE`). Neither game is included here — buy
Battlespire and Redguard on [GOG](https://www.gog.com/) or
[Steam](https://store.steampowered.com/).
