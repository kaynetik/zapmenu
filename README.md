<h3 align="center">
 <br/>
 <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/misc/transparent.png" height="30" width="0px"/>
  <bold>zapmenu</bold> - ditch annoying MacOS top Menu Bar
 <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/misc/transparent.png" height="30" width="0px"/>
</h3>

<p align="center">
 <a href="https://github.com/kaynetik/zapmenu/releases/latest"><img src="https://img.shields.io/github/v/release/kaynetik/zapmenu?colorA=363a4f&colorB=a6da95&style=for-the-badge&logo=github&logoColor=d8dee9" alt="Latest release"></a>
 <a href="https://github.com/kaynetik/zapmenu/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/kaynetik/zapmenu/ci.yml?branch=main&colorA=363a4f&style=for-the-badge&logo=github&logoColor=d8dee9&label=CI" alt="CI status"></a>
 <a href="https://github.com/kaynetik/zapmenu/commits"><img src="https://img.shields.io/github/last-commit/kaynetik/zapmenu?colorA=363a4f&colorB=f5a97f&style=for-the-badge" alt="Last commit"></a>
 <a href="https://github.com/kaynetik/zapmenu/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kaynetik/zapmenu?colorA=363a4f&colorB=b7bdf7&style=for-the-badge" alt="License"></a>
</p>


Blocks the macOS auto-hide menu bar from appearing when you move your mouse to the top of the screen (e.g. switching browser tabs).

zapmenu keeps the cursor out of a 4px strip at the top of each display. With several displays the strip follows each display's own top edge; an edge that borders another display stays open so the cursor can cross. If "Displays have separate Spaces" is off, only the main display is guarded. Toggle it with **Cmd+Option+B** or Unix signals. The menu bar can still be shown manually with **Ctrl+F2**.

Tested on macOS Sequoia (15), Tahoe (26), and macOS 27.

## Install

Download `Zapmenu-<version>-universal.zip` (Apple Silicon and Intel) from the [Releases page](https://github.com/kaynetik/zapmenu/releases), unzip it, move `Zapmenu.app` to `/Applications` and open it. It has no window or Dock icon; quit it with `pkill zapmenu`.

If the release is not notarized, macOS blocks a browser download on first launch. Allow it under System Settings → Privacy & Security → Open Anyway, or run `xattr -dr com.apple.quarantine /Applications/Zapmenu.app`.

Releases also include bare binaries per architecture and a `checksums.txt` (`shasum -a 256 -c checksums.txt --ignore-missing`):

```sh
curl -sL "$(curl -s https://api.github.com/repos/kaynetik/zapmenu/releases/latest \
  | grep browser_download_url | grep "$(uname -m | sed s/arm64/aarch64/)" | cut -d '"' -f 4)" | tar xz
sudo mv zapmenu /usr/local/bin/
```

> Grant **Device Control and Data Access** (System Settings → Privacy & Security; the old Accessibility permission). Input Monitoring is not enough: zapmenu has to move the cursor, not only watch it.

## Usage

Run the app or `zapmenu`. Press **Cmd+Option+B** to toggle the clamp. State changes are printed to stderr and `/tmp/zapmenu.log`.

### External control

| Signal | Effect |
|--------|--------|
| `SIGUSR1` | Toggle clamp on/off |
| `SIGUSR2` | Force clamp ON |

```sh
pkill -USR1 zapmenu
```

**skhd**

```
cmd + alt - b : pkill -USR1 zapmenu
```

**Hammerspoon**

```lua
hs.hotkey.bind({"cmd", "alt"}, "b", function()
  os.execute("pkill -USR1 zapmenu")
end)
```

**AeroSpace** (start at login, toggle from service mode; [full example](https://github.com/kaynetik/kaynix/blob/main/modules/aerospace.nix))

```toml
after-startup-command = ["exec-and-forget /usr/local/bin/zapmenu"]

mode.service.binding = {
  b = ["exec-and-forget /bin/bash -c 'pkill -USR1 zapmenu'" "mode main"]
}
```

## Build from source

Requires [Zig](https://ziglang.org/download/) 0.17.1 and Xcode or Command Line Tools.

```sh
zig build                                  # zig-out/bin/zapmenu and zig-out/Zapmenu.app
zig build -Doptimize=ReleaseFast           # release build
zig build -Dtarget=x86_64-macos            # cross-compile (or aarch64-macos)
zig build test                             # unit tests
zig build bench                            # hot-path benchmarks
./scripts/package-release.sh v1.3.0        # release artifacts in dist/
```

Open `zig-out/Zapmenu.app` rather than the bare binary so macOS lists it under Device Control and Data Access. To keep that grant across rebuilds, sign with a stable certificate: `scripts/create-signing-cert.sh`, then `-Dsign-identity="zapmenu Dev"`.

## Notes

- Terminal/background app with no GUI; macOS only (CoreGraphics event taps).
- The 4px dead zone may interfere with some apps; toggle it off with the hotkey or a signal.
