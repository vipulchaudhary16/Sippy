#!/bin/bash
# Prints the CHANGELOG.md section for a version, followed by install steps.
# Usage: .github/scripts/release-notes.sh 1.2.0
# Fails if the changelog has no entry for that version.
set -euo pipefail
VERSION="$1"
CHANGES=$(awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { found = 1; next }
    found && /^## \[/       { exit }
    found && /^\[[^]]+\]: / { exit }
    found                   { print }
' CHANGELOG.md)

if [[ -z "${CHANGES//[[:space:]]/}" ]]; then
    echo "error: CHANGELOG.md has no '## [$VERSION]' section. Add one before releasing." >&2
    exit 1
fi

cat <<NOTES
$CHANGES

## Install

1. Download **Sippy-$VERSION.dmg** below and open it.
2. Drag **Sippy** into **Applications**.
3. Open it once. Sippy isn't notarized by Apple, so macOS blocks the first launch:
   - **macOS 15 Sequoia and later:** click *Done*, then go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Sippy.
   - **macOS 13–14:** right-click Sippy in Applications → **Open** → **Open**.
   - Or in Terminal: \`xattr -dr com.apple.quarantine /Applications/Sippy.app\`
4. Look for the glass icon in your menu bar. The character comes out to say hi. 💧

Universal app (Apple silicon + Intel), macOS 13 Ventura or later.
Make it yours with the [character guide](https://github.com/vipulchaudhary16/Sippy/blob/main/docs/character-guide.md).
Full history: [CHANGELOG.md](https://github.com/vipulchaudhary16/Sippy/blob/main/CHANGELOG.md).
NOTES
