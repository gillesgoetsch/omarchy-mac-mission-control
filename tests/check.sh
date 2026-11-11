#!/usr/bin/env bash
# Checks that never open the overview. `--static` skips the ones that need a session.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ID="$(jq -r .id "$REPO/manifest.json")"
rc=0
ok() { echo "ok    $1"; }
bad() { echo "FAIL  $1"; rc=1; }

luac -p "$REPO/hypr/mac-mission-control.lua" && ok "lua syntax" || bad "lua syntax"
jq -e '.id and .entryPoints.overlay' "$REPO/manifest.json" >/dev/null && ok "manifest" || bad "manifest"
[ -f "$REPO/$(jq -r .entryPoints.overlay "$REPO/manifest.json")" ] && ok "entry point exists" || bad "entry point missing"
if grep -nE 'font\.pixelSize: *[0-9]+\.[0-9]' "$REPO/MissionControl.qml"; then bad "fractional font.pixelSize (an int: the plugin would not load)"; else ok "no fractional pixel sizes"; fi
if grep -nE '(^|[^A-Za-z0-9_.$])Color *\. *[A-Za-z_]' "$REPO/MissionControl.qml"; then bad "a bare Color (Qt 6.12's QtQuick has a Color of its own: write Commons.Color)"; else ok "colours through Commons.Color"; fi
if grep -nE ':remove\(\)|:unbind\(\)' "$REPO/hypr/mac-mission-control.lua" | grep -v '^\S*--'; then bad "a keybind or event handle is removed (crashes Hyprland 0.56, see docs/DEVELOPING.md)"; else ok "no handle is removed"; fi
if [ -x /usr/lib/qt6/bin/qmllint ]; then
  if /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml "$REPO/MissionControl.qml" 2>&1 | grep -qiE "syntax|expected token"; then bad "qml syntax"; else ok "qml syntax"; fi
fi
if [ -x /usr/lib/qt6/bin/qsb ] || [ -n "${CHECK_SHADER:-}" ]; then
  [ "$REPO/shadow.frag.qsb" -nt "$REPO/shaders/shadow.frag" ] || [ "$(git -C "$REPO" log -1 --format=%ct -- shadow.frag.qsb 2>/dev/null || echo 1)" -ge "$(git -C "$REPO" log -1 --format=%ct -- shaders/shadow.frag 2>/dev/null || echo 0)" ] \
    && ok "shadow shader is built" || bad "shadow shader older than its source (scripts/build-shader.sh)"
fi
lua="$(command -v lua5.4 || command -v lua || true)"
if [ -n "$lua" ]; then
  t="$(mktemp -d)"
  HOME="$t" XDG_RUNTIME_DIR="" "$lua" "$REPO/tests/submap.test.lua" | sed 's/^/      /'
  s="${PIPESTATUS[0]}"; rm -rf "$t"
  [ "$s" -eq 0 ] && ok "submap: entered and left, also after a config reload" || bad "submap"
else echo "skip  submap (no lua)"; fi
node="$(mise which node 2>/dev/null || command -v node)"
if [ -n "$node" ]; then "$node" "$REPO/tests/layout.test.js" | sed 's/^/      /'; [ "${PIPESTATUS[0]}" -eq 0 ] && ok "layout: no overlaps, inside the area" || bad "layout"; else echo "skip  layout (no node)"; fi

[ "${1:-}" = "--static" ] && exit $rc

command -v omarchy >/dev/null && { omarchy plugin validate "$REPO" >/dev/null 2>&1 && ok "plugin validates" || bad "omarchy plugin validate"; }
[ -z "$(hyprctl configerrors)" ] && ok "no Hyprland config errors" || bad "Hyprland config errors"
hyprctl eval 'if not (mac_mission_control and mac_mission_control.live) then error("missing") end' >/dev/null 2>&1 && ok "Hyprland half loaded" || bad "Hyprland half not loaded"
[ "$(hyprctl binds -j | jq '[.[] | select(.description=="Mission Control")] | length')" -ge 1 ] && ok "toggle key bound" || bad "toggle key"
state="$(omarchy-shell shell call "$ID" debugState "" 2>/dev/null | grep '^{' || true)"
[ -n "$state" ] && ok "overview loaded (phase $(echo "$state" | jq -r .phase))" || bad "overview not loaded in the shell"
[ "$(hyprctl clients -j | jq '[.[] | select(.tags | index("mac-mission-control-hidden"))] | length')" -eq 0 ] || [ "$(echo "$state" | jq -r .phase)" != "closed" ] \
  && ok "no window left hidden" || bad "windows hidden while the overview is closed: hyprctl eval 'mac_mission_control.reset()'"
exit $rc
