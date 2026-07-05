#!/usr/bin/env bash
set -euo pipefail

package_name="fantatennis-mac"
version="${DEB_VERSION:-0.1.0}"
maintainer="${DEB_MAINTAINER:-ThewindMom <noreply@users.noreply.github.com>}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="$root_dir/dist"
work_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

if ! command -v swift >/dev/null 2>&1; then
  echo "swift is required to build $package_name" >&2
  exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "dpkg-deb is required to build a Debian package" >&2
  exit 1
fi

if command -v dpkg >/dev/null 2>&1; then
  arch="$(dpkg --print-architecture)"
else
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    *) arch="$(uname -m)" ;;
  esac
fi

swift build -c release --product "$package_name" --package-path "$root_dir"

package_root="$work_dir/${package_name}_${version}_${arch}"
install -d "$package_root/DEBIAN"
install -d "$package_root/usr/bin"
install -d "$package_root/usr/share/doc/$package_name"

install -m 0755 "$root_dir/.build/release/$package_name" "$package_root/usr/bin/$package_name"
install -m 0644 "$root_dir/README.md" "$package_root/usr/share/doc/$package_name/README.md"
install -m 0644 "$root_dir/LICENSE" "$package_root/usr/share/doc/$package_name/copyright"

installed_size="$(du -sk "$package_root/usr" | awk '{print $1}')"

cat > "$package_root/DEBIAN/control" <<CONTROL
Package: $package_name
Version: $version
Section: games
Priority: optional
Architecture: $arch
Maintainer: $maintainer
Installed-Size: $installed_size
Depends: 7zip | p7zip-full
Recommends: wine | wine64
Homepage: https://jftse.com/
Description: macOS/Linux installer for the JFTSE FantaTennis Windows client
 Downloads and verifies the official JFTSE FantaTennis launcher seed,
 extracts FT_Launcher.exe, and writes a Wine wrapper for running the
 official Windows launcher.
CONTROL

install -d "$dist_dir"
dpkg-deb --root-owner-group --build "$package_root" "$dist_dir/${package_name}_${version}_${arch}.deb"
