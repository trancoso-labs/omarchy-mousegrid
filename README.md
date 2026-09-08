# Mousegrid

Point and click with the keyboard on Hyprland. A 6×4 lattice on the focused
window, two speeds, Enter to click. No overlay — the cursor is the feedback.

Built to use the desktop without a mouse. Links, text fields, cards, the
scrollable part of a page: aim, click, drop back into normal keys.

This is an Omarchy shell plugin (`kind: bar-widget`). The pointer itself is
Hyprland Lua plus a small `/dev/uinput` helper.

## Use

`SUPER+A` enters the mode and warps to the center of the focused window.

| Key | Action |
|-----|--------|
| arrows | Jump cell to cell; two arrows together snap to that quarter of the cell |
| arrows on the last cell | One more press scrolls |
| `SUPER` + arrows | Fine move (step from the picker) |
| `Enter` | Left click and leave |
| `Space` (hold) | Hold left button — drag / select |
| `SUPER` + `Space` | Same hold, so fine-aim and drag can overlap |
| tap `Space` | Left click and stay in the mode |
| `Shift` + `Enter` | Right click and leave |
| `PrintScreen` | Enter the grid to aim, or capture the current cell (no slurp) |
| `Shift` + `PrintScreen` | Capture the focused window |
| `Esc` or `SUPER+A` | Leave without clicking |
| `SUPER`+1–0, Tab, scratchpad, monitor | Leave, then the Omarchy screen action |

After a click the mode exits, so the app gets the keyboard: type in the field
you just focused, arrow-scroll the page you just clicked, follow the link.

## Install

```bash
omarchy plugin add https://github.com/trancoso-labs/omarchy-mousegrid.git --enable
omarchy bar put 3v4ng3li0n00.mousegrid --section left
python3 ~/.config/omarchy/plugins/3v4ng3li0n00.mousegrid/scripts/install.py
hyprctl reload
```

The bar icon is a cheatsheet. The install script copies the Hyprland loader
and the click helper, and appends `require("hypr.mousegrid")` to
`~/.config/hypr/bindings.lua` if it is missing.

If the widget does not appear after add:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable 3v4ng3li0n00.mousegrid --section left
```

`SUPER+A` is the default enter key. If that bind is already taken, unbind it
in `bindings.lua` before requiring the loader.

The bar icon opens a wallpaper-style overlay: one row for the coarse lattice
(arrows) and one for the Super+arrows step. Sizes are saved to
`~/.config/omarchy/mousegrid.json` and apply on the next `SUPER+A`.

## Requirements

- Hyprland 0.55+ with Lua config (Omarchy ships this)
- Write access to `/dev/uinput` (typical logind seat ACL on Omarchy)

Clicks go through a user-session virtual pointer, not `ydotool`. The helper
lives at `~/.local/bin/mousegrid-click` after install.

## How it aims

The lattice covers the focused window, not the whole monitor. Six columns by
four rows — a cell is about the size of a card. From the center, one or two
arrow taps reach most of the window; Super+arrows finish the pixel.

There is no drawn grid. If you want one later, that is a separate layer on
top of the same motion.

## Remove

```bash
omarchy plugin remove 3v4ng3li0n00.mousegrid
```

Drop `require("hypr.mousegrid")` from `hypr/bindings.lua`, and remove
`~/.config/hypr/mousegrid.lua` and `~/.local/bin/mousegrid-click` if you no
longer want the pointer.
