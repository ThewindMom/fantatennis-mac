# FantaTennis macOS/Linux launcher

Swift command-line installer for the Windows-only JFTSE/FantaTennis client at
<https://jftse.com/>.

This project does not redistribute the game client. It downloads the official
`FantaTennis.7z` seed archive from JFTSE, verifies its SHA-256, extracts the
official `FT_Launcher.exe`, and writes a small wrapper that runs that launcher
through Wine.

## Commands

```sh
swift run fantatennis-mac inspect
swift run fantatennis-mac doctor
swift run fantatennis-mac install --destination ./FantaTennis-install
```

After install, run:

```sh
./FantaTennis-install/run-windows-client.command
```

Wine is required to run the Windows launcher/game. `7z` or `7zz` is required to
extract the official archive.

## Build a Debian package

```sh
scripts/build-deb.sh
```

The package is written to `dist/`. It installs the CLI as
`/usr/bin/fantatennis-mac`.

The GitHub Actions workflow also builds a `.deb` on manual dispatch and on
`v*` tags. Each workflow run installs the built package and runs
`fantatennis-mac inspect`, `doctor`, and `install` from `/usr/bin` before
uploading artifacts. Tagged builds publish the `.deb` as a GitHub Release asset.

## Reverse-engineered launcher contract

- Seed archive: `https://jftse.com/client/FantaTennis.7z`
- Seed SHA-256: `c19ca21b8e2ab091953b2f631e48853b6477400f4d7000682ac7440f9994f12e`
- News: `https://jftse.com/launcher_news`
- Ranking: `https://jftse.com/launcher_ranking`
- Updater base: `https://jftse.com/updater/`
- Official seed launcher: `ClientSeed/FT_Launcher.exe`
- Final Windows launch file after update: `FantaTennis.exe`

## License

MIT. The JFTSE/FantaTennis game, launcher, assets, and services belong to their
respective owners.
