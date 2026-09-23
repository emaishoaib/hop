# Hop

A minimal macOS window switcher. It runs in the background, with no Dock or menu bar icon.

- **ption + Tab** shows every window on the current Space.
- **Option + `** shows only the active app's windows.

Keep holding Option while you pick a window:

- **Tab or `** moves to the next window.
- **The arrow keys** move left, right, up and down through the grid.
- **The mouse** selects a window when you move over it. Clicking switches to it straight away.

Release Option to switch to the selected window, which is highlighted in blue.

Windows are listed in the order you last used them, so a quick OptionTab takes you back to the previous window. That holds however you got there, whether through Hop, ⌘Tab, the Dock or a click.

Windows on other Spaces and minimized windows are not shown.

## Build and open

Needs macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
```

This builds `Hop.app` in this directory. Move it to `/Applications` if you like, then open it.

On its first launch, Hop adds itself to System Settings > General > Login Items, so it starts at every login. If you switch it off there, Hop won't switch it back on.

## Permissions

Hop needs two permissions, which it asks for on its first launch:

- **Accessibility**, to see the shortcuts, focus windows and follow which window you're in. Hop shows a Dock icon until this is granted, then hides it and starts working.
- **Screen Recording**, for the thumbnails and window titles. Hop has to be relaunched after this is granted.

Hop is signed ad hoc, so macOS treats each rebuild as a new app. After a rebuild, remove Hop from both lists in System Settings > Privacy & Security and add it back.

## The ` key

The Option` shortcut uses the physical key that types ` on a US keyboard, not the character. On a keyboard where that key sits somewhere else, the shortcut stays on the same physical key.

## Private API

Hop uses one private macOS function, `_AXUIElementGetWindow`. It's the only reliable way to match a window from the window list to the same window in Accessibility, and it has been stable for over a decade. If a macOS update breaks focusing or the window order, check this first.

## Icon

`AppIcon.icns` is drawn by `make-icon.swift`. After changing the design, regenerate it:

```bash
swift make-icon.swift
```

## Quit and uninstall

Hop has no window or menu to quit from. To quit it:

```bash
pkill -x Hop
```

To uninstall, quit it, switch it off in Login Items, and delete `Hop.app`.
