# Clash RS

[简体中文](README_ZH.md) · English

[![Windows x64](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-windows.yml/badge.svg)](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-windows.yml)
[![Linux x64](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-linux.yml/badge.svg)](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-linux.yml)
![Version](https://img.shields.io/badge/version-1.0.0-1688f0)
![Flutter](https://img.shields.io/badge/Flutter-cross--platform-02569B?logo=flutter&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-2d3345)

**Clash RS is a cross-platform Flutter proxy client, VPN client, and Mihomo GUI for Android, macOS, Windows, and Linux.** It combines subscription management, proxy-node selection, latency testing, Rule/Global/Direct routing, system proxy, TUN mode, active connections, logs, IP information, and real-time traffic monitoring in one interface.

Desktop builds use a pinned [mihomo](https://github.com/MetaCubeX/mihomo) core. Android uses `VpnService` together with the Rust `core-bridge` library.

> Current application version: **1.0.0**. The desktop window is fixed at **960 × 720**.

**[Download](#download)** · **[Quick start](#quick-start-for-users)** · **[Build packages](#build-packages)** · **[中文文档](README_ZH.md)**

## Download

Use the [GitHub Releases download page](https://github.com/goodlovesky/monorepo/releases/latest) for ready-to-install Clash RS packages and checksum files.

| Download | Location | Notes |
| --- | --- | --- |
| Stable packages | [Latest release](https://github.com/goodlovesky/monorepo/releases/latest) | Versioned installers, portable packages, manifests, and SHA-256 checksums |
| All published versions | [All releases](https://github.com/goodlovesky/monorepo/releases) | Previous releases and release notes |
| Windows x64 development build | [Windows Actions](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-windows.yml) | Open a successful run and download `Clash-RS-Windows-x64` |
| Linux x64 development build | [Linux Actions](https://github.com/goodlovesky/monorepo/actions/workflows/desktop-linux.yml) | Open a successful run and download `Clash-RS-Linux-x64` |
| Source code | [ZIP](https://github.com/goodlovesky/monorepo/archive/refs/heads/main.zip) · [tar.gz](https://github.com/goodlovesky/monorepo/archive/refs/heads/main.tar.gz) | Source snapshot of the current `main` branch |

GitHub Actions artifacts are intended for testing and are retained for a limited time. Prefer the release page for normal installation.

## Features

- Manage subscription links and refresh proxy profiles.
- Browse proxy groups, test node latency, and select the active node.
- Switch between Rule, Global, and Direct routing modes.
- Enable system proxy or virtual network adapter (TUN) mode.
- View real-time upload/download traffic, memory usage, connections, rules, and logs.
- Recover previous system proxy settings after a crash or abnormal exit.
- Share one Flutter desktop UI across macOS, Windows, and Linux.
- Build versioned packages with manifests and SHA-256 checksums.

## Platform status

| Platform | Runtime | Package output |
| --- | --- | --- |
| Android | Android `VpnService` + Rust `core-bridge` | APK, AAB |
| macOS | mihomo, system proxy, utun | Universal App, DMG |
| Windows x64 | mihomo, WinINet proxy, Wintun | Portable ZIP, Inno Setup EXE |
| Linux x64 | mihomo, GNOME/KDE proxy, TUN | DEB, tar.gz |

Windows ARM64, Linux ARM64, RPM, and AppImage are not part of the 1.0.0 release.

## Quick start for users

If you only want to use Clash RS, download the package produced for your operating system and follow these steps:

1. Install or extract Clash RS and start the application.
2. Open **Subscriptions**.
3. Paste your subscription URL into the input field, then select **New**.
4. Wait for the profile to finish loading.
5. Open **Proxies**, move the pointer over a proxy node, and select **Check** to test it.
6. Select a working node. Its measured latency is displayed in milliseconds.
7. Return to **Home** and enable **System Proxy** for normal desktop applications, or **TUN Mode** when full-device routing is required.
8. Open **IP Info**, **Connections**, or **Traffic** to confirm that the connection is active.

Use subscription URLs and proxy servers that you are permitted to access. Do not share subscription URLs in issue reports or screenshots.

## System proxy or TUN?

| Mode | Best for | Notes |
| --- | --- | --- |
| System Proxy | Browsers and applications that honor the operating-system proxy | Starts quickly and normally needs no elevated network permission |
| TUN Mode | Applications that ignore system proxy, games, command-line tools, and full-device routing | Requires an administrator prompt, Wintun, or Linux network capabilities |

Start with **System Proxy**. Switch to **TUN Mode** only when an application does not use the system proxy.

## Build prerequisites

All commands below are run from the repository root.

### Common tools

- Git
- Flutter stable with desktop support enabled
- Rust stable and Cargo
- Python 3

Prepare Flutter dependencies:

```bash
git clone https://github.com/goodlovesky/monorepo.git proxy-monorepo
cd proxy-monorepo
flutter doctor
cd app
flutter pub get
cd ..
```

### Android

Install Android Studio, Android SDK, Android NDK, Java, Rust, and Bash 4 or newer. Set the NDK path:

```bash
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/<installed-version>"
```

`cargo-ndk` is installed automatically by the Android build helper when missing.

### macOS

Use macOS with Xcode, Xcode Command Line Tools, Flutter, Rust, `hdiutil`, and `codesign`. The default local package uses ad-hoc signing and does not require a Developer ID.

### Windows

Use Windows 10/11 x64 with Flutter, Visual Studio Desktop development with C++, Rust MSVC, PowerShell, and Inno Setup. macOS and Linux hosts do not create Windows binaries locally; use the Windows GitHub Actions workflow instead.

### Linux

Ubuntu/Debian dependencies:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libblkid-dev libcap2-bin dpkg-dev curl
```

## Build packages

### Android APK and AAB

```bash
./cmd/build-android.sh --clean
```

Optional commands:

```bash
./cmd/build-android.sh --apk-only
./cmd/build-android.sh --aab-only
./cmd/build-android.sh --skip-tests
```

Outputs:

```text
dist/android/ClashRS-1.0.0-android.apk
dist/android/ClashRS-1.0.0-android.aab
dist/android/BUILD-MANIFEST.json
dist/android/BUILD-ENVIRONMENT.txt
dist/android/SHA256.txt
```

### macOS App and DMG

```bash
./cmd/build-macos.sh --clean
```

Outputs:

```text
dist/macos/Clash RS.app
dist/macos/Clash-RS-macOS.dmg
dist/macos/BUILD-MANIFEST.json
dist/macos/BUILD-ENVIRONMENT.txt
dist/macos/SHA256.txt
```

For a signed and notarized release, provide `SIGN_IDENTITY` and `NOTARY_PROFILE` as documented in [`docs/desktop-release-checklist.md`](docs/desktop-release-checklist.md).

### Windows x64

Run in PowerShell on Windows:

```powershell
.\cmd\build-windows.ps1 -Clean
```

Outputs:

```text
dist/windows/ClashRS-1.0.0-windows-x64-portable.zip
dist/windows/ClashRS-Setup-1.0.0-x64.exe
dist/windows/BUILD-MANIFEST.json
dist/windows/BUILD-ENVIRONMENT.txt
dist/windows/SHA256.txt
```

#### Build Windows with GitHub Actions

1. Push the branch to GitHub.
2. Open the repository's **Actions** page.
3. Select **Desktop Windows x64**.
4. Select **Run workflow** and choose the branch.
5. Wait for the build and install/uninstall smoke test to pass.
6. Download the **Clash-RS-Windows-x64** artifact from the workflow run.

The workflow file is [`.github/workflows/desktop-windows.yml`](.github/workflows/desktop-windows.yml).

### Linux x64

Run on Ubuntu or Debian:

```bash
./cmd/build-linux.sh --clean
```

Optional package selection:

```bash
./cmd/build-linux.sh --deb-only
./cmd/build-linux.sh --tar-only
```

Outputs:

```text
dist/linux/clash-rs_1.0.0_amd64.deb
dist/linux/ClashRS-1.0.0-linux-x64.tar.gz
dist/linux/BUILD-MANIFEST.json
dist/linux/BUILD-ENVIRONMENT.txt
dist/linux/SHA256.txt
```

Install the DEB package with:

```bash
sudo apt install ./dist/linux/clash-rs_1.0.0_amd64.deb
```

The DEB post-install script applies the required TUN capability to the bundled mihomo binary. A tar.gz installation may request `pkexec setcap` the first time TUN mode is enabled.

Linux packages can also be built without a Linux computer: open **Actions**, run **Desktop Linux x64**, and download the **Clash-RS-Linux-x64** artifact after the workflow passes. The workflow is defined in [`.github/workflows/desktop-linux.yml`](.github/workflows/desktop-linux.yml).

### Build everything supported by the current host

```bash
./cmd/build-all.sh --clean
```

On macOS this builds Android and macOS. On Linux it builds Android and Linux. Windows packaging uses the PowerShell command above.

## Development and tests

```bash
cd app
flutter analyze
flutter test

cd ..
RUSTC_BOOTSTRAP=1 cargo test --workspace
```

Useful documentation:

- [Architecture](ARCHITECTURE.md)
- [Network modes](NETWORK_MODES.md)
- [Packaging commands](cmd/README.md)
- [Desktop release checklist](docs/desktop-release-checklist.md)
- [Clean-machine verification](docs/clean-machine-verification.md)
- [Verification results](VERIFICATION.txt)

## Troubleshooting

### The core does not start

- Confirm that the active subscription is valid.
- Confirm that the bundled `mihomo` file exists and is executable.
- Check whether another process is already using the configured mixed or controller port.
- Open the in-app **Logs** page and export diagnostic logs.

### A node does not show latency

- Move the pointer over the actual proxy-node card and select **Check**.
- Confirm that the core is running and the subscription contains usable nodes.
- Refresh the subscription, then retry the test.

### System proxy is enabled but applications cannot connect

- Turn System Proxy off and on once.
- Verify that the selected node is healthy.
- Check **Connections**, **Traffic**, and **IP Info**.
- Restore the original network mode before manually changing operating-system proxy settings.

### TUN mode cannot start

- macOS may display an administrator prompt.
- Windows requires the packaged `wintun.dll`.
- Linux requires `cap_net_admin` and `cap_net_raw` on the packaged mihomo binary.

### Log locations

- macOS: `~/Library/Logs/ClashRS/`
- Windows: open **Settings → Advanced Settings → Log Directory**
- Linux: open **Settings → Advanced Settings → Log Directory**; recovery state is stored under `$XDG_STATE_HOME` or `~/.local/state`

## Project layout

```text
app/          Flutter application and native platform runners
crates/       Rust core-bridge workspace
cmd/          beginner-friendly packaging entry points
tools/        platform build and dependency helpers
docs/         architecture, verification, and release documents
dist/         generated release packages
```

## License

Clash RS is licensed under **GPL-3.0-or-later**.
