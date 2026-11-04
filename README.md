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

Needs macOS 14 or later, Xcode, `xcodegen` (`brew install xcodegen`) and a Developer ID Application certificate.

Release builds are signed with that certificate, so Accessibility and Screen Recording stay granted from one build to the next. They read the Apple development team, the updates host and the Sparkle public key from `Config/Release.xcconfig`, which is not committed. Copy `Config/Release.xcconfig.example` and fill it in.

The Xcode project is generated from `project.yml` and is not committed. Generate it first, and again whenever a file is added or removed:

```bash
xcodegen generate
```

Then build it:

```bash
xcodebuild -project Hop.xcodeproj -scheme Hop-macOS -configuration Release -derivedDataPath build build
```

This builds `Hop.app` in `build/Build/Products/Release`. Move it to `/Applications` if you like, then open it.

To try a change, use the script instead. It generates the project, builds it, quits Hop and installs the new build in `/Applications`, replacing the copy there, then reopens it. If the build fails, the running Hop is left alone:

```bash
scripts/rebuild.sh
```

On its first launch, Hop adds itself to System Settings > General > Login Items, so it starts at every login. If you switch it off there, Hop won't switch it back on.

## Releasing

Hop is released as a signed and notarized DMG from any website.

**Setup**

1. **Create a Developer ID certificate** -- this shows Macs the app came from you
2. **Store the notarization login** -- this lets the script send the app to Apple for scanning. Hop uses the login stored as `notary`
3. **Generate the Sparkle key** -- this proves that updates really came from you
4. **Get a website address** -- this is where the DMG and update file will live. It's the `apps` bucket in Cloudflare R2, connected to `apps.mashoaib.com`. Set the address as `HOP_UPDATES_HOST` in `Config/Release.xcconfig`
5. **Log in to Cloudflare** -- this lets the script upload to the bucket. Run `npx wrangler login` once

**Release**

1. Raise the version and build number in `project.yml`
2. Run `scripts/release.sh`. It does all of this for you:
   - builds and signs the app
   - puts it in a DMG
   - gets Apple to scan it
   - updates `appcast.xml`, the file that tells installed apps what the latest version is
   - uploads the DMG and then `appcast.xml` to the website, so the appcast never lists a DMG that isn't there yet
   - uploads the DMG a second time as `Hop.dmg`, which each release overwrites, so that name is always the latest version

**Sharing the download**

Share `https://apps.mashoaib.com/hop`. It works with or without the slash at the end, so `https://apps.mashoaib.com/hop/` does the same. A redirect rule in Cloudflare sends both on to `/hop/Hop.dmg`, so they always download the latest version. The rule is set up once, under Rules > Redirect Rules for mashoaib.com:

- **When incoming requests match** -- a custom filter expression, entered through **Edit expression**:

  ```
  http.host eq "apps.mashoaib.com" and http.request.uri.path in {"/hop" "/hop/"}
  ```

- **Then** -- a static redirect to `https://apps.mashoaib.com/hop/Hop.dmg` with status code 302, and the query string not preserved

The expression lists both paths exactly. A wildcard such as `/hop*` would also catch `/hop/Hop.dmg` and `/hop/appcast.xml`, so the download would redirect to itself and installed copies couldn't check for updates.

It's a 302, a temporary redirect, because browsers remember a 301 permanently.

**What people do**

1. They download the DMG from `https://apps.mashoaib.com/hop`
2. They open it and drag Hop into Applications
3. From then on, Hop checks `appcast.xml` by itself and offers new versions as you release them. They can also use **Check for Updates…** in the settings window

## Permissions

Hop needs two permissions, which it asks for on its first launch:

- **Accessibility**, to see the shortcuts, focus windows and follow which window you're in. Hop shows a Dock icon until this is granted, then hides it and starts working.
- **Screen Recording**, for the thumbnails and window titles. Hop has to be relaunched after this is granted.

Release builds are signed with Developer ID, so both permissions carry over from one build to the next. Debug builds are signed ad hoc, so macOS treats each of them as a new app. After a Debug build, remove Hop from both lists in System Settings > Privacy & Security and add it back.

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

## Settings

Open Hop while it's already running, from Applications or Spotlight, and its settings window appears. It shows the version and has a **Check for Updates…** button.

The button is disabled in Debug builds, because the updater only runs in Release builds.

## Quit and uninstall

Hop has no menu or button to quit from. To quit it:

```bash
pkill -x Hop
```

To uninstall, quit it, switch it off in Login Items, and delete `Hop.app`.

## Planned

- **Search.** Option + Tab followed by ` opens a search bar above the windows. Option then no longer needs to be held. Typing filters the windows by app name or window title. The arrow keys move through the matches, and Enter switches to the selected one. Esc or a click outside closes it.
