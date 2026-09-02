<p align="center"><img src="Design/banner.png" alt="Focal" width="720"></p>

# Focal

**Blur everything except the window you're working in.** A free, open-source macOS menu bar app.

Click a window and everything behind it softens into a blur. Switch windows and the focus follows. No account, no permissions dialog, no Dock icon.

## Install

Paste this in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/maka-tanmay/focal/main/install.sh | sh
```

That downloads the latest release into `/Applications` and launches it. Look for the ◐ icon in your menu bar.

Prefer clicking? Grab `Focal.zip` from the [latest release](https://github.com/maka-tanmay/focal/releases/latest), unzip, drag to Applications. Because the app isn't notarized, the first launch needs **right-click → Open**.

Requires macOS 13 or later. Universal binary (Apple Silicon and Intel).

## Use

The first time Focal launches it opens its panel and explains itself. After that:

- **Click the ◐ menu bar icon** to open the panel: on/off switch, blur strength slider, Auto, windows to keep sharp, launch at login.
- **⌥-click the icon** or press **⌃⌥⌘F** to pause or resume instantly. The icon turns dashed when paused.
- **Auto** lets Focal pick the strength: stronger the more windows sit behind the active one, off when there is nothing to hide.
- **Also keep sharp** pins up to two extra windows that stay clear next to the active one. Open the panel while the window you want is in front and click "Keep … window sharp".
- Full-screen apps are left alone. Works across multiple displays and Spaces.

## How it works

One borderless window per display holds an `NSVisualEffectView` with behind-window blending. Every 150 ms Focal reads the on-screen window list, finds the frontmost app's frontmost normal window, and orders the blur window directly beneath it. Everything above stays sharp, everything below gets blurred. That's the whole trick, in about 200 lines of Swift.

No Accessibility or Screen Recording permission is needed because the window list and window ordering are public APIs.

## Build from source

```bash
git clone https://github.com/maka-tanmay/focal && cd focal && ./build.sh
open build/Focal.app
```

Needs Xcode command line tools. Releases are built by GitHub Actions on every `v*` tag.

## Credits

Inspired by [Monocle](https://www.heyiam.dk/monocle) by Dominik Kandravy, and the window-ordering approach in [dimsum](https://github.com/nshi/dimsum). MIT licensed.
