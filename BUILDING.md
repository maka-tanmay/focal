# Building and how it works

For people who want to look under the hood. Users don't need any of this; the [README](README.md) has the download.

## Build from source

```bash
git clone https://github.com/maka-tanmay/focal && cd focal && ./build.sh
open build/Focal.app
```

Needs the Xcode command line tools. `build.sh` produces a universal, ad-hoc signed `Focal.app` and a zip. Releases are built by GitHub Actions on every `v*` tag and attached to the release; the install script pulls the latest one.

## How the blur works

One borderless window per display holds an `NSVisualEffectView` with behind-window blending. Every 150 ms Focal reads the on-screen window list, finds the front app's real window, and orders the blur window directly beneath it. Everything above stays sharp, everything below is blurred. The window list and window ordering are public APIs, so no Accessibility or Screen Recording permission is needed.

Details that matter:

- Browsers keep toolbar strips and popups as extra windows, some parked off-screen. Windows that are mostly off-screen are ignored, and a small window inside a much larger sibling resolves to that sibling.
- Full-screen and maximized windows fill the display, so the blur window hides; there's nothing worth blurring behind them. The switch in the panel lets Focal blur inside full-screen Spaces (Split View) instead.
- Pinned "keep sharp" windows get holes cut in the blur via the effect view's mask image.
- The blur window lives only in the current Space and is dropped during a Space switch, then re-placed, so it never rides along on top of the incoming Space.

## Layout of the code

| File | What it does |
|---|---|
| `Sources/Overlay.swift` | The blur engine: window tracking, ordering, fullscreen and pin logic |
| `Sources/AppDelegate.swift` | Menu bar item, quick panel window, Settings window, global hotkey |
| `Sources/PanelView.swift`, `PanelTheme.swift` | The quick panel and its three materials |
| `Sources/SettingsView.swift` | Settings tabs, including the animated welcome |
| `Sources/Prefs.swift` | Icon styles, panel style, shortcut recording |
| `Design/` | Icon and banner generators, screenshots |

## Dev flags

- `Focal --snapshot <dir>` renders the panel to PNGs without the glass.
- `Focal --capture <dir> <count> <interval>` saves full-screen PNGs (asks for Screen Recording once). Used for README shots only.
