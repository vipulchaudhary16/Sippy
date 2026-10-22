# Sippy (native macOS)

A menu-bar app: every so often a little character walks onto your screen, sips
some water, and asks whether you drank too. Answer **Yes, I drank!** to log a
glass or **Snooze**. If you ignore it, it snoozes itself after a few minutes.

Built with Swift/SwiftUI using only the Xcode **Command Line Tools** (no Xcode needed).

## Build & install

```sh
scripts/build.sh            # dist/Sippy.app + dist/Sippy.dmg
scripts/build.sh --install  # also copies to /Applications and launches
swift run SippyChecks       # core logic checks
```

The app is ad-hoc signed. On another Mac, right-click → Open the first time.

## Your own character

Settings → **Open Character Folder** (`~/Library/Application Support/Sippy/Character`)
and drop transparent PNGs facing right: `walk_0.png, walk_1.png…`, `idle_0.png…`,
`sip_0.png…`, optionally `cheer_0.png…`, plus optional `appear.mp3` (plays once as she walks in) and `cheer.mp3` (plays when you log a glass). Picked up on the next reminder. Empty folder = built-in character.

## Where things live

- Settings: `defaults read com.vipulchaudhary.sippy`
- Water log: `~/Library/Application Support/Sippy/intake.json`
- Art check without a screen: `.build/debug/Sippy --render-previews <dir>`
