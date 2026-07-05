# FantaTennis macOS launcher

Swift command-line installer for the Windows-only JFTSE/FantaTennis client at
<https://jftse.com/>.

This project does not redistribute the game client in source control. The macOS
app downloads the official JFTSE updater manifest, downloads payload files from
`https://jftse.com/updater/`, verifies MD5s, and writes a launch wrapper for the
official Windows client.

## Install and run on macOS

Tagged releases build `FantaTennisMac-<version>.dmg`. The primary artifact in
the image is `FantaTennis.app`, a native macOS installer/launcher for the
official JFTSE Windows payload.

For end users:

1. Download `FantaTennisMac-<version>.dmg` from the GitHub release linked by
   `jftse.com`.
2. Open the DMG and copy `FantaTennis.app` to `/Applications` or
   `~/Applications`.
3. Open `FantaTennis.app`.
4. Click `Install / Update` to download and verify the official client payload.
   The full payload is installed to `~/Applications/FantaTennis`.
5. Install a free Wine-compatible runtime, then click `Launch` in
   `FantaTennis.app`.

The recommended free runtime path in 2026 is
[Sikarugir](https://github.com/Sikarugir-App/Sikarugir), the actively
maintained Wineskin successor. Its project README lists this install command:

```sh
brew upgrade
brew trust Sikarugir-App/sikarugir
brew install --cask Sikarugir-App/sikarugir/sikarugir
```

Apple silicon systems also need Rosetta 2 for current Wine-based Windows game
compatibility:

```sh
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
```

The app window should open immediately when `FantaTennis.app` is launched. If no
compatible runtime is installed, it will still open and show `Runtime: missing`.
That state is expected until Sikarugir, Wine, or another compatible runtime is
present. If Sikarugir Creator is installed but no runnable engine is found, the
app opens Sikarugir Creator and tells the user to create/select a Wine engine.
CrossOver is supported as a fallback only for users who already have it; it is
not required for the public free client path.

The full installed payload is not bundled into the DMG. It is downloaded from
the official updater endpoints and verified with the upstream MD5 manifest.

## macOS DMG contents

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

For `jftse.com`, publish the DMG as the macOS client download. The page should
describe it as a native macOS installer/updater for the official JFTSE Windows
client. The game executable remains a Windows Direct3D 9 client, so launching
requires a Wine-compatible runtime. The app prefers free Wine runtimes when
present and uses CrossOver only as a fallback.

For broad public macOS distribution, sign with an Apple Developer ID
Application certificate, notarize with Apple, and staple the notarization
ticket. The local machine currently has an Apple Development identity only,
which is enough for local development signing but not for public notarized
distribution.

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
best free macOS target for this kind of payload is Sikarugir/Wineskin or another
actively maintained Wine distribution that can run 32-bit DirectX 9 programs in
a 64-bit bottle. Homebrew's `wine-stable` cask is free, but Homebrew currently
marks it as deprecated because it does not pass the macOS Gatekeeper check and
says it will be disabled on 2026-09-01, so Sikarugir is the better public
recommendation.

The official launcher is a .NET Windows app. If Wine reports that Mono is not
installed, install Wine Mono into the Wine prefix before launching the client.

`7z` or `7zz` is required to extract the official archive.

## Validation status

Validated on Apple silicon macOS with CrossOver 26.2.0 while narrowing the
runtime behavior. CrossOver is not the intended public free dependency:

- `FantaTennis.app` opens a visible native macOS launcher window.
- `Doctor` reaches the JFTSE seed archive, updater manifest, launcher news, and
  ranking endpoints.
- `Install / Update` downloads and verifies the official payload.
- `Launch` detects CrossOver, creates a dedicated `FantaTennis` bottle, and
  starts the official `FT_Launcher.exe`.
- Direct `FantaTennis.exe` startup renders its initial banner under CrossOver.
  The generated CrossOver wrapper defaults to the D3DMetal backend because it
  was the most stable observed renderer on Apple silicon. The default wined3d
  backend rendered but stalled before a server connection. DXVK reached the game
  server but crashed on this machine with a MoltenVK shader compile error.

The current build is a compatibility-runtime client, not a native rewrite of
the Windows game executable. On Apple silicon, CrossOver may trigger Apple's
Intel/Rosetta compatibility warning. Apple says Rosetta remains available
through macOS 27, with narrower support starting in macOS 28, so this path
should be presented as a practical compatibility build rather than a long-term
pure native macOS port.

As of the latest validation, the macOS package reaches the official launcher
and the Windows game initialization banner. It has not yet been validated as a
fully playable login/session on macOS.

Current free-runtime UX validation:

- The runtime resolver prefers `FANTATENNIS_WINE`, Wine app bundles, and `wine`
  from `PATH` before falling back to CrossOver.
- If Sikarugir Creator is installed but no runnable Wine engine is found, the
  app shows a setup-needed state and opens Sikarugir Creator.
- If neither a runtime nor Sikarugir Creator is found, the app shows a missing
  runtime state and opens the Sikarugir project page.
- If only CrossOver is available, the app labels it as a fallback instead of
  the recommended public path.

A pure native macOS rewrite is not currently possible from only the official
`.7z` and `.exe`; that would require the game source code or a clean-room
reimplementation of the client engine, protocol, asset pipeline, and
anti-cheat/launcher behavior.

## Troubleshooting

If `FantaTennis.app` opens but the game does not launch, run `Doctor` in the app.
The most common result on a fresh Mac is `runtime missing`, which means the
native macOS installer is working but Sikarugir or Wine is not installed yet.

If macOS blocks the app because it is unsigned or not notarized, right-click the
app and choose `Open`, or distribute a Developer ID signed and notarized build
for public users.

If the app window does not appear, quit any stuck copies and reopen it:

```sh
pkill -f FantaTennisLauncher
open ~/Applications/FantaTennis.app
```

For local validation, the expected installed app launch check is:

```sh
open ~/Applications/FantaTennis.app
osascript -e 'tell application "System Events" to tell process "FantaTennisLauncher" to get {frontmost, visible, name of every window}'
```

The window list should include `FantaTennis`.

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
