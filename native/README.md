# Sippy: native macOS app

This folder is the app: a Swift Package that builds with only the Xcode Command Line Tools.

```sh
scripts/build.sh            # checks + dist/Sippy.app + dist/Sippy.dmg
scripts/build.sh --install  # also installs to /Applications and launches
swift run SippyChecks       # logic checks
swift scripts/check_frames.swift   # validate custom character frames
```

See the [main README](../README.md), the [character guide](../docs/character-guide.md) and the
[architecture notes](../docs/architecture.md).
