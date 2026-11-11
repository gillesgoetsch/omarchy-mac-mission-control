# Changelog

## 1.0.2 (unreleased)

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
