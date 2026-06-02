#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ tuist generate"
tuist generate

RESOLVED_DIR="EdgeLab.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$RESOLVED_DIR"

if [[ -f .package.resolved ]]; then
  cp .package.resolved "$RESOLVED_DIR/Package.resolved"
  cp .package.resolved "EdgeLab.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" 2>/dev/null || true
fi

echo "→ resolve Swift packages"
xcodebuild -resolvePackageDependencies \
  -workspace EdgeLab.xcworkspace \
  -scheme EdgeLab \
  -onlyUsePackageVersionsFromResolvedFile

echo "✓ Done. Open EdgeLab.xcworkspace (not EdgeLab.xcodeproj)."