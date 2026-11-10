#!/usr/bin/env bash
# For working on the plugin: put this working tree where the shell loads
# plugins from (instead of a git clone made by `omarchy plugin add`), enable
# it and restart the shell once. Run it again after every change.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ID="$(jq -r .id "$REPO/manifest.json")"
TARGET="$HOME/.config/omarchy/plugins/$ID"

if [ -d "$TARGET/.git" ]; then
  echo "$TARGET is a git clone (omarchy plugin add). Remove it first: omarchy plugin remove $ID" >&2
  exit 1
fi
mkdir -p "$TARGET/hypr"
changed=0
lua_changed=0
for file in manifest.json MissionControl.qml Layout.js shadow.frag.qsb hypr/mac-mission-control.lua; do
  if ! cmp -s "$REPO/$file" "$TARGET/$file" 2>/dev/null; then
    install -Dm644 "$REPO/$file" "$TARGET/$file"
    echo "updated  $file"
    changed=1
    case "$file" in hypr/*) lua_changed=1;; esac
  fi
done

if ! jq -e --arg id "$ID" '.plugins // [] | any(.id == $id)' "$HOME/.config/omarchy/shell.json" >/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  sleep 2
  omarchy plugin enable "$ID" >/dev/null
  echo "enabled  $ID"
  changed=1
fi

if [ "$changed" -eq 1 ]; then
  # A changed file starts a hot reload; a restart on top of one has crashed
  # Quickshell, so let it settle first.
  sleep 3
  omarchy restart shell >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    omarchy-shell shell call "$ID" debugState "" 2>/dev/null | grep -q '^{' && break
    sleep 1
  done
fi
# The hooks the Lua file registers in Hyprland stay for the life of its Lua
# state; a config reload starts a new one, and the plugin loads the file again.
if [ "$lua_changed" -eq 1 ]; then
  hyprctl reload >/dev/null
  sleep 1
  errors="$(hyprctl configerrors)"
  [ -z "$errors" ] || { echo "HYPRLAND CONFIG ERRORS: $errors" >&2; exit 1; }
fi
omarchy-shell shell call "$ID" debugState "" 2>/dev/null | grep -q '^{' && echo "loaded" || { echo "NOT loaded: journalctl --user -b | grep MissionControl.qml" >&2; exit 1; }
