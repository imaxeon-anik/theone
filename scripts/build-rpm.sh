#!/bin/bash
# Build the theOne RPM on the sfbuild VM. Usage: build-rpm.sh [aarch64|armv7hl|i486]
set -euo pipefail
ARCH="${1:-aarch64}"
case "$ARCH" in aarch64|armv7hl|i486) ;; *) echo 'Usage: build-rpm.sh [aarch64|armv7hl|i486]' >&2; exit 2 ;; esac
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ssh -o BatchMode=yes -o ConnectTimeout=5 sfbuild true
rsync -a --delete --exclude .git --exclude RPMS --exclude 'preview/out' "$ROOT/" sfbuild:~/src/theone/
ssh sfbuild "cd ~/src/theone && rm -rf RPMS && ~/SailfishOS/bin/sfdk -c target=SailfishOS-5.1.0.11-$ARCH build 2>&1 | grep -v 'D-Bus connection failed'; exit \${PIPESTATUS[0]}"
mkdir -p "$ROOT/RPMS"
rsync -a "sfbuild:~/src/theone/RPMS/*.$ARCH.rpm" "$ROOT/RPMS/"
ls -lh "$ROOT"/RPMS/theone-keyboard-*.$ARCH.rpm
