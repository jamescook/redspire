#!/usr/bin/env bash
# Launch Battlespire under DOSBox. See README.md for background.
#
# Usage:
#   ./play-battlespire.sh [options] <game-directory> [cd-image.iso]
#
#   <game-directory>  Directory containing GAME.EXE, GameData, SPIRE.CFG,
#                      SPIRE.BAT, MSS directly (not a parent folder).
#   [cd-image.iso]     CD data-track image to mount as D:. If omitted, looks
#                      for game.ins inside <game-directory> (GOG/Steam installs
#                      ship this already).
#
# Options:
#   -b, --backend <name> DOSBox backend: "staging" (default) or "x".
#   -f, --fullscreen     Launch DOSBox in fullscreen mode.
#   -m, --memsize <MB>   Override emulated RAM (default: 48).
#   -h, --help           Show this help.
set -euo pipefail

FULLSCREEN=0
MEMSIZE=48
BACKEND="staging"

usage() {
  # Print the leading comment block (after the shebang) as help text.
  sed -n '2,/^[^#]/p' "$0" | sed '$d; s/^#//; s/^ //'
  exit "${1:-1}"
}

ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--backend) BACKEND="$2"; shift 2 ;;
    -f|--fullscreen) FULLSCREEN=1; shift ;;
    -m|--memsize) MEMSIZE="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    --) shift; while [ $# -gt 0 ]; do ARGS+=("$1"); shift; done ;;
    -*) echo "Unknown option: $1" >&2; usage 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

[ $# -ge 1 ] || usage 1

case "$BACKEND" in
  staging|x) ;;
  *) echo "Error: --backend must be 'staging' or 'x', got '$BACKEND'." >&2; usage 1 ;;
esac

if [ ! -d "$1" ]; then
  echo "Error: directory not found: $1" >&2
  exit 1
fi
GAME_DIR=$(cd "$1" && pwd)
if [ ! -f "$GAME_DIR/GAME.EXE" ]; then
  echo "Error: $GAME_DIR/GAME.EXE not found." >&2
  echo "Point this at the folder containing GAME.EXE directly, not its parent." >&2
  exit 1
fi

if [ $# -ge 2 ]; then
  CD_IMAGE=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
else
  CD_IMAGE="$GAME_DIR/game.ins"
fi
if [ ! -f "$CD_IMAGE" ]; then
  echo "Error: CD image not found at $CD_IMAGE" >&2
  echo "Pass one explicitly: $0 <game-directory> <cd-image.iso>" >&2
  exit 1
fi

# Version check: whine, don't block. v1.3 is known-broken under DOSBox (
# wrong video mode, severe slowdown during animation) -- see the README
# for how to patch to 1.5 -- but this is just a heads-up, not a gate.
VERSION_STRING=$(strings "$GAME_DIR/GAME.EXE" 2>/dev/null | grep -im1 "battlespire v" || true)
if [ -z "$VERSION_STRING" ]; then
  echo "Warning: couldn't find a 'Battlespire V*' string in GAME.EXE -- unexpected, continuing anyway." >&2
elif [[ "$VERSION_STRING" != *"V1.5"* ]]; then
  echo "Warning: this looks like '$VERSION_STRING', not v1.5." >&2
  echo "v1.3 is known to be broken under DOSBox (wrong video mode," >&2
  echo "severe slowdown during animation). See README.md for" >&2
  echo "how to patch to 1.5. Continuing anyway with what you pointed me at..." >&2
fi

DOSBOX_ARGS=(--set "dosbox memsize=$MEMSIZE")

if [ "$BACKEND" = "staging" ]; then
  DOSBOX_BIN="dosbox-staging"
  if ! command -v "$DOSBOX_BIN" >/dev/null 2>&1; then
    echo "Error: '$DOSBOX_BIN' not found on PATH." >&2
    echo "Install with: brew install dosbox-staging" >&2
    echo "(Or pass --backend x to use dosbox-x instead.)" >&2
    exit 1
  fi
  [ "$FULLSCREEN" -eq 1 ] && DOSBOX_ARGS+=(--fullscreen)
else
  DOSBOX_BIN="/Applications/dosbox-x.app/Contents/MacOS/DOSBox-X"
  if [ ! -x "$DOSBOX_BIN" ]; then
    echo "Error: $DOSBOX_BIN not found." >&2
    echo "Install with: brew install --cask dosbox-x-app" >&2
    echo "(If it's quarantined by Gatekeeper: xattr -d com.apple.quarantine /Applications/dosbox-x.app)" >&2
    exit 1
  fi
  DOSBOX_ARGS=(-nopromptfolder "${DOSBOX_ARGS[@]}")
  [ "$FULLSCREEN" -eq 1 ] && DOSBOX_ARGS+=(--fullscreen)
fi

exec "$DOSBOX_BIN" \
  "${DOSBOX_ARGS[@]}" \
  -c "MOUNT C \"$GAME_DIR\"" \
  -c "IMGMOUNT D \"$CD_IMAGE\" -t iso" \
  -c "C:" \
  -c "set causeway=MAXMEM:70;PRE:40;NAME:spire.swp" \
  -c "game spire.cfg"
