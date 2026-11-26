#!/bin/bash
# Render keyboard previews on the sfbuild VM (Qt 5, offscreen) and copy them to preview/out/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rsync -a --delete --exclude .git --exclude 'preview/out' "$ROOT/" sfbuild:~/src/theone/
ssh sfbuild 'rm -rf /tmp/theone-preview && mkdir -p /tmp/theone-preview && cd ~/src/theone/preview &&
  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout 60 qmlscene -I ../qml preview.qml 2>&1 |
  grep -v -E "^(QStandardPaths|qt.qpa)" || true; ls /tmp/theone-preview'
mkdir -p "$ROOT/preview/out"
rsync -a 'sfbuild:/tmp/theone-preview/' "$ROOT/preview/out/"
