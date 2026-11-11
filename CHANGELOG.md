# Changelog

## 1.0.4 (2026-11-11)

- With several monitors, a window can be dragged onto a desktop of another
  monitor. Every monitor's overview now has a copy of every window and shows
  the ones whose desktop is on it, so the window turns up there at once; the
  real window stays hidden while that desktop is in view under the overview.

## 1.0.3 (2026-11-11)

- With several monitors, the overview on every monitor takes the pointer: its
  windows and desktops can be hovered, clicked and dragged, not only those of
  the monitor it was opened on. The overlay no longer takes the keyboard
  exclusively, which made Hyprland send all pointer input to that one monitor's
  overlay; `Esc` is now a bind of the overview's submap, and other keys stop
  there instead of reaching the hidden window that has the focus.

## 1.0.2 (2026-11-11)

- A Hyprland config reload while the overview is open no longer leaves
  Hyprland in the overview's submap, where most keys did nothing until the
  next open and close.

## 1.0.1 (2026-11-10)

- Swiping the overview shut with the pointer on a window brings that window
  to the front and focuses it.
- Colours show on Qt 6.12: its QtQuick has a `Color` of its own, which
  hid Omarchy's (window placeholders, the hover frame, the desktops bar).
- The README says that the Mission Control key can arrive as `F3` in a VM.

## 1.0.0 (2026-11-10)

First release.

- Four fingers up and down open and close the overview, following the fingers.
- Windows keep their relative positions and share one scale; piles and
  cascades are packed into rows.
- Live copies of the windows with their titlebars, borders and shadows.
- Desktops bar with live previews: click to open, drag a window onto one to
  move it, drag the previews to reorder.
- Four fingers sideways page through the desktops while the overview is open.
- `Super`/`Ctrl` + `W`/`Q` close the window or quit the app under the pointer.
- Works on every monitor at once; the bar starts below a camera notch.
