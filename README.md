# FantaTennis macOS launcher

Swift command-line installer for the Windows-only JFTSE/FantaTennis client at
<https://jftse.com/>.

This project does not redistribute the game client. It downloads the official
`FantaTennis.7z` seed archive from JFTSE, verifies its SHA-256, extracts the
official `FT_Launcher.exe`, and writes a small wrapper that runs that launcher
through Wine.

## macOS DMG

Tagged releases build `FantaTennisMac-<version>.dmg`. The primary artifact in
the image is `FantaTennis.app`, a native macOS installer/launcher for the
official JFTSE Windows payload.

The DMG contains:

- `FantaTennis.app`: native macOS UI for install/update, diagnostics, and launch
- `fantatennis-mac`: the Swift launcher helper CLI
- `Install FantaTennis.command`: double-click full payload installer
- `FantaTennis Doctor.command`: endpoint and local runtime checks
- `Inspect Launcher.command`: prints the reverse-engineered launcher contract
- `README.md` and `LICENSE`

To build one locally on macOS:

```sh
scripts/build-dmg.sh
```

The DMG and SHA-256 checksum are written to `dist/`.

The GitHub Actions DMG workflow builds on manual dispatch and on `v*` tags. It
verifies the image with `hdiutil verify`, mounts the DMG read-only, checks that
`FantaTennis.app` and helper scripts are executable, runs `fantatennis-mac`
`inspect`, `doctor`, and `manifest` from inside the mounted image, then uses the
native updater path to download and verify a small prefix of the official
payload. Tagged builds publish the `.dmg` and `.dmg.sha256` files as GitHub
Release assets.

The release DMG is currently unsigned and not notarized. For broad public macOS
distribution, best practice is to sign the binary and DMG with an Apple
Developer ID certificate, notarize with Apple, and staple the notarization
ticket.

## Commands

```sh
swift run fantatennis-mac inspect
swift run fantatennis-mac doctor
swift run fantatennis-mac manifest
swift run fantatennis-mac install --destination ./FantaTennis-install
swift run fantatennis-mac install-full --destination ./FantaTennis-full
```

After install, run:

```sh
./FantaTennis-install/run-windows-client.command
```

The macOS app and CLI can natively inspect the service, parse
`https://jftse.com/updater/files.md5`, and download/verify the official game
payload. The game executable itself remains a 32-bit Windows Direct3D 9 binary,
so a Windows compatibility runtime is still required to launch it. In 2026, the
most stable macOS target for this kind of payload is CrossOver or another
actively maintained Wine distribution that can run 32-bit DirectX 9 programs in
a 64-bit bottle. On Debian or Ubuntu, that usually means enabling i386 and
installing Wine:

```sh
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install wine wine32 wine64
```

The official launcher is a .NET Windows app. If Wine reports that Mono is not
installed, install Wine Mono into the Wine prefix before launching the client.

`7z` or `7zz` is required to extract the official archive.

## Debian package

```sh
scripts/build-deb.sh
```

The package is written to `dist/`. It installs the CLI as
`/usr/bin/fantatennis-mac`. Linux release builds use Swift's static standard
library and strip the binary before packaging.

The GitHub Actions Debian workflow still exists for Linux testing. It builds on
manual dispatch and on `deb-v*` tags. Each workflow run inspects the built
package with `dpkg-deb`, checks it with `lintian --fail-on error`, installs it,
runs `fantatennis-mac inspect`, `doctor`, and `install` from `/usr/bin`, then
launches the generated Wine wrapper under Xvfb for 60 seconds. Tagged Debian
builds publish the `.deb` as a GitHub Release asset.

## Reverse-engineered launcher contract

- Seed archive: `https://jftse.com/client/FantaTennis.7z`
- Seed SHA-256: `c19ca21b8e2ab091953b2f631e48853b6477400f4d7000682ac7440f9994f12e`
- News: `https://jftse.com/launcher_news`
- Ranking: `https://jftse.com/launcher_ranking`
- Updater base: `https://jftse.com/updater/`
- Updater manifest: `https://jftse.com/updater/files.md5`
- Official seed launcher: `ClientSeed/FT_Launcher.exe`
- Final Windows launch file after update: `FantaTennis.exe`

## License

MIT. The JFTSE/FantaTennis game, launcher, assets, and services belong to their
respective owners.
