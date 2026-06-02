#!/usr/bin/env bash
# Pull Edge Lab Documents/EdgeLabRuns from a connected iPhone (requires Xcode devicectl).
set -euo pipefail

DEVICE="${1:-}"
BUNDLE="com.andrewvoirol.edge-lab"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO_ROOT/docs/device-pull"

if [[ -z "$DEVICE" ]]; then
  echo "Usage: $0 <device-identifier>"
  echo "List devices: xcrun devicectl list devices"
  exit 1
fi

mkdir -p "$DEST"
xcrun devicectl device copy from \
  --device "$DEVICE" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE" \
  --source "Documents/EdgeLabRuns" \
  --destination "$DEST/EdgeLabRuns" \
  --remove-existing-content true

echo "✓ Pulled to $DEST/EdgeLabRuns"
echo "  Copy screenshots to docs/images/ and JSON to Examples/ as needed."