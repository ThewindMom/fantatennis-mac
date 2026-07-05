#!/usr/bin/env bash
set -euo pipefail

package_name="fantatennis-mac"
version="${DMG_VERSION:-0.2.0}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="$root_dir/dist"
build_dir="$root_dir/.build/dmg"
stage_dir="$build_dir/FantaTennis Mac"
dmg_path="$dist_dir/FantaTennisMac-${version}.dmg"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "build-dmg.sh must run on macOS because it uses hdiutil" >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "swift is required to build $package_name" >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required to build a DMG" >&2
  exit 1
fi

rm -rf "$stage_dir"
install -d "$stage_dir"
install -d "$dist_dir"

swift build -c release --product "$package_name" --package-path "$root_dir"

install -m 0755 "$root_dir/.build/release/$package_name" "$stage_dir/$package_name"
strip "$stage_dir/$package_name" 2>/dev/null || true
install -m 0644 "$root_dir/README.md" "$stage_dir/README.md"
install -m 0644 "$root_dir/LICENSE" "$stage_dir/LICENSE"

cat > "$stage_dir/Install FantaTennis.command" <<'INSTALLER'
#!/bin/sh
set -eu

disk_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
destination="${FANTATENNIS_DESTINATION:-$HOME/Applications/FantaTennis}"

printf 'Installing FantaTennis launcher helper to %s\n\n' "$destination"
"$disk_dir/fantatennis-mac" install --destination "$destination"

printf '\nInstalled.\n'
printf 'Run this after installing Wine or CrossOver:\n  %s/run-windows-client.command\n\n' "$destination"
printf 'Press return to close this window.'
IFS= read -r _ || true
INSTALLER

cat > "$stage_dir/FantaTennis Doctor.command" <<'DOCTOR'
#!/bin/sh
set -eu

disk_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
"$disk_dir/fantatennis-mac" doctor

printf '\nPress return to close this window.'
IFS= read -r _ || true
DOCTOR

cat > "$stage_dir/Inspect Launcher.command" <<'INSPECT'
#!/bin/sh
set -eu

disk_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
"$disk_dir/fantatennis-mac" inspect

printf '\nPress return to close this window.'
IFS= read -r _ || true
INSPECT

chmod 0755 "$stage_dir/"*.command

rm -f "$dmg_path"
hdiutil create \
  -volname "FantaTennis Mac" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$dmg_path"

shasum -a 256 "$dmg_path" > "$dmg_path.sha256"
echo "Built $dmg_path"
