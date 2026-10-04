# Hop

A minimal macOS window switcher. It runs in the background, with no Dock or menu bar icon.

- **Option + Tab** shows every window on the current Space.
- **Option + `** shows only the active app's windows.

Keep holding Option while you pick a window:

- **Tab or `** moves to the next window.
- **The arrow keys** move left, right, up and down through the grid.
- **A click** on a window switches to it straight away. Moving the mouse over the windows does nothing.
- **The ✕ in a thumbnail's corner** closes that window, the same as its own close button. Hop stays open with the windows that are left.
- **The power button next to it** quits that window's app, the same as ⌘Q. All of the app's windows leave Hop, and it stays open with the rest.
- **Esc**, or a click anywhere outside Hop, closes it without switching.

Release Option to switch to the selected window, which is highlighted in blue.

Windows are listed in the order you last used them, so a quick Option + Tab takes you back to the previous window. That holds however you got there, whether through Hop, ⌘Tab, the Dock or a click.

The windows of an app you've hidden with ⌘H are listed too. Picking one shows the app again, which brings back all of its windows.

Minimized windows are listed as well. Picking one brings it out of the Dock.

Windows on other Spaces are not shown.

Each window is labelled with its app's icon and its title. A VS Code window is labelled with the name of the git repo holding its open file instead. When it shows something that isn't a file, such as a diff, it's labelled with the name of the folder open in VS Code.

## Build and open

Needs macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
```

This builds `Hop.app` in this directory. Move it to `/Applications` if you like, then open it.

On its first launch, Hop adds itself to System Settings > General > Login Items, so it starts at every login. If you switch it off there, Hop won't switch it back on.

## Releasing

Push a version tag to publish a release:

```bash
git tag v1.1
git push origin v1.1
```

GitHub then builds `Hop.app` and attaches it as `Hop.zip` to a release for that tag. The app's version is the tag's number without the `v`. The version in `Info.plist` is only what a local build reports. The workflow is `.github/workflows/release.yml`.

On a Mac set up with [workshop](https://github.com/emaishoaib/workshop), the next `setup.sh` run replaces the installed Hop with the new release. Its permissions then need granting again, as described under Permissions.

## Permissions

Hop needs two permissions, which it asks for on its first launch:

- **Accessibility**, to see the shortcuts, focus windows and follow which window you're in. Hop shows a Dock icon until this is granted, then hides it and starts working.
- **Screen Recording**, for the thumbnails and window titles. Hop has to be relaunched after this is granted.

Hop is signed ad hoc, so macOS treats each rebuild as a new app. After a rebuild, remove Hop from both lists in System Settings > Privacy & Security and add it back.

## The ` key

The Option + ` shortcut uses the physical key that types on a US keyboard, not the character. On a keyboard where that key sits somewhere else, the shortcut stays on the same physical key.

### If Option + ` sometimes does nothing

macOS has its own "Move focus to next window" shortcut, under System Settings → Keyboard → Keyboard Shortcuts → Keyboard. If it's bound to Option + `, macOS intermittently swallows the keypress before Hop sees it. The shortcut then works most of the time and silently does nothing the rest.

Unticking the checkbox is not a reliable fix. Even with the shortcut disabled, macOS still intercepted the keypress some of the time. Reassign it to a combo nothing else uses instead.

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

## Planned

- **Search.** Option + Tab followed by ` opens a search bar above the windows. Option then no longer needs to be held. Typing filters the windows by app name or window title. The arrow keys move through the matches, and Enter switches to the selected one. Esc or a click outside closes it.
