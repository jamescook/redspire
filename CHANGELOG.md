# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Native macOS SwiftUI launcher app wrapping the DOSBox setup: game-folder
  picker, fullscreen/memory/backend controls, and DOSBox-running detection.
- First-run onboarding wizard with guided install flows for GOG, Steam, and
  manual/disc-image installs, in plain language rather than DOS-era jargon.
- Automatic Steam install via `steamcmd`, as an alternative to the
  self-service copy-paste-a-command flow: Keychain-backed credential storage
  with multi-account support, Steam Guard handling, and live progress/log.
- Automatic GOG install extraction via `innoextract`, with progress/log UI.
- Manual install support: extract a raw retail disc image, apply the
  official v1.5 patch, and auto-repair config files the original DOS
  installer would normally generate but a raw disc doesn't ship
  (`SPIRE.CFG`, `MSS/DIG.INI`) — the latter's absence was traced to a severe
  in-game animation slowdown.
- `GAME.EXE` hash verification badge, showing whether the detected install
  matches the known-good v1.5 build.
- CD image auto-detection by file extension (rather than a hardcoded
  filename), so GOG, Steam, and manual installs all work regardless of what
  their CD image happens to be named.
- Hover tooltips explaining the DOSBox backend and memory controls.
- `build.sh`: parameterized codesign + notarization pipeline; CI workflow
  plumbing for automated builds.

[Unreleased]: https://github.com/jamescook/redspire/commits/main
