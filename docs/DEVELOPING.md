# Developing Mac Mission Control

## Layout of the repository

The repository root is the plugin, so that `omarchy plugin add <url>` can clone
it straight into `~/.config/omarchy/plugins/mac.missioncontrol/`.

| File | What |
|---|---|
| `manifest.json` | the plugin: an `overlay` that stays loaded |
| `MissionControl.qml` | the overview: state machine, springs, drawing |
| `Layout.js` | where each window goes (pure functions, tested with node) |
| `hypr/mac-mission-control.lua` | the Hyprland half: gesture, keys, snapshot, hiding the real windows |
| `shaders/shadow.frag` → `shadow.frag.qsb` | Hyprland's window shadow, for the copies |
| `tests/` | `check.sh` (never opens the overview), `layout.test.js` |
| `scripts/dev-install.sh` | copy the working tree to the plugin folder and restart the shell |
| `docs/demo/` | stand-in pages used for the screenshots |

## Workflow

```sh
$EDITOR MissionControl.qml       # or any other file
tests/check.sh --static          # syntax, manifest, layout
scripts/dev-install.sh           # working tree -> ~/.config/omarchy/plugins/mac.missioncontrol
tests/check.sh                   # + the live wiring
```

`dev-install.sh` refuses to overwrite a git clone made by `omarchy plugin add`;
remove that first. It restarts the shell once when plugin files changed (a
plugin hot reload keeps the old instance for new properties and sibling files,
and a restart on top of a hot reload has crashed Quickshell, so it waits), and
reloads Hyprland when the Lua changed.

## How it works

```
 touchpad (libinput -> Hyprland)
    │  hl.gesture { fingers = N, direction = "vertical", start/update/finish }
    ▼
 Hyprland ── hypr/mac-mission-control.lua
    │  start:  snapshot (monitors, workspaces, windows in stacking order,
    │          border/titlebar/shadow settings) + "g,s"
    │  update: "g,u,<dy>,<ms>" per movement        finish: "g,e"
    │  all as custom socket2 events:  hl.dsp.event("mmc>>...")
    ▼
 omarchy-shell ── MissionControl.qml
    │  arm():  builds the model, starts a ScreencopyView per window
    │          (overlay still unmapped), computes the layout (Layout.js)
    │  go():   all copies have a frame -> overlay maps (first frame = the
    │          copies exactly where the windows are)
    ▼
 Hyprland: layer.opened "mac-mission-control" on monitor M
    │  tags M's visible windows `mac-mission-control-hidden` (rule: opacity 0)
    │  in that handler, so hide and map land in the same frame; emits "h,M"
    ▼
 shell: every monitor acked -> `progress` follows the fingers / the spring
```

Leaving is the reverse: the copies return to the windows' real places
(`raw = 0`), two frames later the overlay unmaps, and `layer.closed` shows the
windows.

Shell → Hyprland goes through `hyprctl eval 'mac_mission_control.<fn>()'`:
`activate(address)`, `workspace(id, slide)`, `move(address, id)`,
`close(address)`, `quit(address)`, `geometry()`, `reorder(spec)`, `reset()`,
`toggle()`, plus `swipe(...)` and `demo(...)` for tests and recordings.

### Loading the Hyprland half

Nothing in `~/.config/hypr` requires the Lua file. The plugin runs
`hyprctl eval 'dofile([[…/hypr/mac-mission-control.lua]])'` when it starts and
again 150 ms after every `configreloaded` event, because a reload starts
Hyprland's Lua afresh.

The file is in two parts:

- **Hooks** (event handlers, the vertical gesture, the keys, the submap, the
  opacity rule, the layer rules) are registered once per Lua state, guarded by
  the global `mac_mission_control_hooks`, and never removed. Each one only
  calls `mac_mission_control_call(name, ...)`.
- **The module** (`mac_mission_control`) holds the state and the handlers the
  hooks call. Loading the file again replaces it: the old one's `unload()`
  resets and sets `live = false`, the new one takes over. With the plugin
  switched off the hooks find no live module and do nothing; a Hyprland reload
  removes them.

If the hooks themselves change, raise `HOOKS` in the Lua: a load that finds an
older set sends `stale`, and the shell answers with `hyprctl reload`.

### Phases (`MissionControl.qml`)

`closed → tracking` (fingers down) `→ settling` (critically damped spring to 0
or 1) `→ open → … → restoring → closed`. `open → switching` when a desktop is
clicked, `open → paging → pageSettling → open` for a sideways swipe.

A release goes the way the fingers were still moving (faster than `flick`);
at rest, a third of the way (`commit`) from where the swipe started is enough.

`raw` is 0..1 from the fingers or the spring, and `progress` is `raw` once the
swap has happened. Nothing moves before the swap; what the fingers travelled
until then is `debt`, which decays exponentially (`catchUp`, 70 ms) while the
fingers are down, so the copies close the gap smoothly instead of jumping.
Opening by key starts its spring at the swap.

### Layout (`Layout.js`, tested by `tests/layout.test.js`)

1. `spread`: KWin's "natural" Present Windows layout (written to imitate
   Exposé): every overlapping pair is pushed apart a step at a time, the
   bounding box keeps the screen's shape, then all of it is scaled into the
   area. One scale for all windows; relative positions survive.
2. `grow`: the spread leaves air; binary-search the largest common scale at
   which neighbours can still shove each other apart inside the area.
3. `rows`: windows packed into rows by where they are. Replaces the result of
   1 + 2 when its windows come out more than `ROWS_WIN_BY` (10 %) larger, which
   is what happens with cascades and piles (a diagonal chain only gets longer
   when pushed along the line between centres).

Every desktop of a monitor gets its layout, not only the visible one: the
others are what slides in when paging.

### Sideways: paging through the desktops

A finger count and direction has exactly one gesture in Hyprland, and N fingers
sideways is usually the workspace swipe. While the overview is up (first
`layer.opened` → last `layer.closed`) the Lua takes that gesture out
(`action = "unset"`) and registers its own, which sends
`s,s,<monitor under the pointer>,<workspace_swipe_distance>`, `s,u,<dx>,<ms>`,
`s,e`; afterwards it puts the workspace swipe back.

Each copy is offset by `(its desktop's index − pagePos) × screen width`. On
release the target desktop is chosen (a flick: the next one that way;
otherwise the one more than 15 % in view), `workspace(id, slide)` hides its
real windows and switches Hyprland, and the page spring finishes.

A switch from outside (a key) arrives as `workspace.active`: the Lua hides the
new desktop's windows in that handler and sends `ws,<monitor>,<id>`; the shell
slides over to it (`enterSpace`).

Hyprland's own workspace animation must not play during a switch the overview
makes. The shell reads the `workspaces` leaf from `hyprctl -j animations` when
it loads and, if it is on, passes it as `slide`; the Lua turns the leaf off,
switches, and sets it again 120 ms later.

### Keys while it is up

`SUPER + Q` and `SUPER + W` are usually global binds that act on the focused
window, and a second bind on the same key would run next to the first, not
instead of it. So the Lua enters the submap `mac-mission-control` with the
first `layer.opened` and leaves it with the last `layer.closed`: in it those
keys (and their `CTRL` twins) send `key,q` / `key,w`, the shell answers with
`quit(address)` / `close(address)` for the window under the pointer, and the
toggle keys and `SUPER + 1..0` are bound again. Unbound keys reach the overlay
(`ESC`).

### Things that change while it is up

The model (`byMonitor`) is built once per opening; replacing it would recreate
every copy. What changes later lives in maps keyed by window address that the
delegates look up: `wsOf` (its desktop), `geo` (geometry since the snapshot),
`gone` (closed), `topped` (brought to the front of another desktop).

- A window moved to another desktop, a reorder, a window closed: Hyprland
  re-tiles what is left, so `refreshGeometry()` asks for `geometry()` after
  70 ms and again after 450 ms (Omarchy's layout mode floats or tiles a moved
  window a moment later); the `x,…` lines fill `geo` and `layout()` runs again.
- Reordering renumbers the workspaces with `workspace.change_id` through spare
  ids 9001…, so each keeps its windows and tiling tree. Omarchy's layout mode
  belongs to the number: after the renumbering the Lua calls
  `default.hypr.workspace-modes`' `apply()`, and if that floated or tiled
  anything the overview leaves, because the windows rearrange underneath.
- A dragged copy is `free`: `heldX/Y/Scale` keep the grabbed point under the
  pointer while `factor` shrinks it towards the bar, and `fly` (0→1, 300 ms)
  takes it from there to `bar.landing()` (its place in the preview) or back to
  its slot.

### The copies

Checked by capturing the real desktop, then the overview held at progress 0
(`swipe("s")`), and `magick compare`.

- Border: a frame in the active or inactive border colour.
- Titlebar: what `omarchy-hyprland-titlebars` draws on floating workspaces.
  Its text is the app's name from the desktop entry whose `StartupWMClass` (or
  else file name) is the window's class, and only a window no launcher claims
  shows its title (`appName()` mirrors the plugin's `appName.cpp`).
- Shadow: Hyprland's own formula in `shaders/shadow.frag`
  (`(distance from the outer edge / range) ^ render_power`, radial at corners).

## Hard rules (each one was a bug)

1. **Never remove a keybind or an event handle from Lua.** In Hyprland 0.56
   `Keybind:remove()` erases *every* bind on that key and modifiers (the user's
   own included), and a second handle to a bind that is already gone segfaults
   the compositor (`CLuaKeybind`, 2026-11-10: the whole session went down).
   Hence the hooks that stay; `tests/check.sh` greps for `:remove()`.
2. **Hide the windows in the overlay's own `layer.opened`, nothing else.** A
   separate layer mapped "when the copies are ready" lost the race against the
   overlay's first frame: one frame of bare wallpaper. The overlay maps *after*
   the copies have content; `ScreencopyView` captures fine while its window is
   unmapped.
3. **Draw nothing of a copy before it has a frame**, and draw its border as a
   frame, never as a filled rectangle. Either shows as a slab of colour over
   the real window.
4. **Keep the overlay's first frame light.** The time from the first finger
   movement to that frame is what a swipe feels as lag. The bar is only
   `visible` after the swap, its backdrop is blurred at an eighth of the size
   and scaled up, and the previews start capturing one window every 12 ms
   (`quota`) instead of all at once.
5. **`hl.dsp.window.set_prop` cannot undo an opacity** ("unset" fails and the
   override sticks). Hide through a tag and a window rule; removing the tag
   restores the window exactly. The rule is added at run time and therefore
   after the rules of the config, Omarchy's `opacity 1 override` for floating
   workspaces among them.
6. **A failing `hl.gesture` is a config error on the screen, not a Lua error**
   (`pcall` returns true). Removing a gesture that is not there, or adding one
   that is shadowed, puts up the red bar until the next reload. So the
   sideways swap only runs when the workspace swipe is known to exist, and
   tracks what it did in `paging`.
7. **`font.pixelSize` is an int**, and `top`, `left`, … are FINAL properties of
   `Item`. A fractional pixel size or a property with such a name fails the
   whole plugin load, and the IPC then answers `unknown`.
8. **A lower layer `order` is further up.** The overview has -50 so that its
   bar covers bars that also sit on the overlay layer.
9. **Etiquette when testing live:** the overview opens on the screens someone
   is working on, and screenshots capture what they are doing. Ask first,
   delete captures right after.

10. **Write `Commons.Color`, never a bare `Color`.** Qt 6.12's QtQuick has a
    `Color` singleton of its own, and under a plain `import QtQuick` a bare
    `Color` is that one, whatever the order of the imports: every colour of
    Omarchy's (`Color.background`, `Color.accent`, ...) is then undefined.
    `import qs.Commons as Commons` and `Commons.Color.x` reach Omarchy's on
    every Qt; `tests/check.sh` greps for a bare one.

## Debugging

```sh
omarchy-shell shell call mac.missioncontrol debugState ""    # phase, timing, slots, slide
omarchy-shell shell call mac.missioncontrol debugAction "space eDP-1 2"      # open desktop 2
omarchy-shell shell call mac.missioncontrol debugAction "drop 0xaaaa… 6"     # a window let go over desktop 6
omarchy-shell shell call mac.missioncontrol debugAction "reorder eDP-1 2 0"  # bar positions, from 0
hyprctl eval 'mac_mission_control.swipe("s")'                # a swipe without fingers: then ("u", dy, ms), ("e")
hyprctl eval 'error(hl.get_current_submap())'                # "mac-mission-control" while up
hyprctl eval 'mac_mission_control.reset()'                   # unstick
journalctl --user -b | grep MissionControl.qml               # QML errors
```

`timing` in `debugState`: `ready` is arm → all copies captured (20–40 ms),
`hidden` arm → windows hidden on every monitor (55–75 ms), `longest` and `slow`
the longest frame and the number of frames over 20 ms since the opening began.
The first opening after a shell restart is slower (about 180 ms).

For anything visual, record at the monitor's refresh rate and look at single
frames (`wf-recorder -r 120`, `ffmpeg … signalstats` for brightness per
frame): the start flicker was one frame.

## Recording the README media

Demo mode limits the overview to one monitor and a few workspaces and numbers
them from 1: `mac_mission_control.demo("eDP-1", { 5, 6, 7 }, true)`. Swipes
were sent with `swipe(...)` through Hyprland's socket, the pointer was driven
through `wlr-virtual-pointer`, so the drags in the GIFs are real pointer
drags.
