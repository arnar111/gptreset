#!/bin/bash
# Pick the newest Xcode 16 or newer installed on a GitHub macOS runner.
set -euo pipefail

# macOS /usr/bin/sort has no -V. Compare up to three numeric components.
ver_gt() {
  left=$1
  right=$2
  i=1
  while [ "$i" -le 3 ]; do
    l=${left%%.*}
    r=${right%%.*}
    if [ "$l" = "$left" ]; then left=0; else left=${left#*.}; fi
    if [ "$r" = "$right" ]; then right=0; else right=${right#*.}; fi
    l=$(printf '%s' "$l" | sed 's/[^0-9].*//')
    r=$(printf '%s' "$r" | sed 's/[^0-9].*//')
    l=${l:-0}
    r=${r:-0}
    if [ "$l" -gt "$r" ]; then return 0; fi
    if [ "$l" -lt "$r" ]; then return 1; fi
    i=$((i + 1))
  done
  return 1
}

best_dev=""
best_ver="0"

shopt -s nullglob
for app in /Applications/Xcode*.app; do
  dev="$app/Contents/Developer"
  if [ ! -x "$dev/usr/bin/xcodebuild" ]; then
    continue
  fi
  ver=$("$dev/usr/bin/xcodebuild" -version | awk 'NR==1 { print $2 }')
  major=${ver%%.*}
  major=$(printf '%s' "$major" | sed 's/[^0-9].*//')
  echo "Found $app ($ver)"
  if [ -z "$major" ] || [ "$major" -lt 16 ]; then
    continue
  fi
  if ver_gt "$ver" "$best_ver"; then
    best_dev="$dev"
    best_ver="$ver"
  fi
done

if [ -z "$best_dev" ]; then
  echo "::error::No Xcode 16 or newer is installed on this runner."
  exit 1
fi

echo "Selecting Xcode $best_ver"
sudo xcode-select -s "$best_dev"
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version
