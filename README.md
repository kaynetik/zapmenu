<h3 align="center">
 <br/>
 <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/misc/transparent.png" height="30" width="0px"/>
  zapmenu
 <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/misc/transparent.png" height="30" width="0px"/>
</h3>

<p align="center">
 <a href="https://github.com/kaynetik/zapmenu/releases/latest"><img src="https://img.shields.io/github/v/release/kaynetik/zapmenu?colorA=363a4f&colorB=a6da95&style=for-the-badge&logo=github&logoColor=d8dee9" alt="Latest release"></a>
 <a href="https://github.com/kaynetik/zapmenu/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/kaynetik/zapmenu/ci.yml?branch=main&colorA=363a4f&style=for-the-badge&logo=github&logoColor=d8dee9&label=CI" alt="CI status"></a>
 <a href="https://github.com/kaynetik/zapmenu/commits"><img src="https://img.shields.io/github/last-commit/kaynetik/zapmenu?colorA=363a4f&colorB=f5a97f&style=for-the-badge" alt="Last commit"></a>
 <a href="https://github.com/kaynetik/zapmenu/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kaynetik/zapmenu?colorA=363a4f&colorB=b7bdf8&style=for-the-badge" alt="License"></a>
</p>


# zapmenu

Blocks the macOS auto-hide menu bar from appearing when you move your mouse to the top of the screen (e.g. switching browser tabs).

The app clamps the cursor so it never enters the top 4 pixels of your screen. Toggle the block on/off with **Cmd+Option+B**, or externally via Unix signals. You can also show the menu bar manually with **Ctrl+F2** (macOS built-in).

Tested on **macOS Tahoe** (15.x) and later.

## Install (prebuilt binary)

Grab the latest archive for your architecture from the [Releases page](https://github.com/kaynetik/zapmenu/releases), or use `curl`:

```sh
# Apple Silicon (M1/M2/M3/M4)
curl -sL "$(curl -s https://api.github.com/repos/kaynetik/zapmenu/releases/latest \
  | grep browser_download_url | grep aarch64 | cut -d '"' -f 4)" | tar xz

# Intel
curl -sL "$(curl -s https://api.github.com/repos/kaynetik/zapmenu/releases/latest \
  | grep browser_download_url | grep x86_64 | cut -d '"' -f 4)" | tar xz
```

Move the binary somewhere on your `PATH`:

```sh
sudo mv zapmenu /usr/local/bin/
```

Or, to install without `sudo`, use a user-local directory:

```sh
mkdir -p ~/.local/bin
mv zapmenu ~/.local/bin/

# Make sure ~/.local/bin is in your PATH (add to ~/.zshrc or ~/.bashrc):
# export PATH="$HOME/.local/bin:$PATH"
```

> macOS will ask you to grant **Accessibility** (or **Input Monitoring**) permission to your terminal or the `zapmenu` binary on first run. The app cannot intercept mouse events without it.

## Usage

```sh
zapmenu
# or run in a detached tmux session
tmux new -d zapmenu
```

Press **Cmd+Option+B** to toggle the cursor clamp on/off at runtime.

State changes are printed to stderr (`zapmenu: clamp ON` / `zapmenu: clamp OFF`).

## External control

zapmenu listens for Unix signals, so any external tool can control it without the keyboard shortcut:

| Signal | Effect |
|--------|--------|
| `SIGUSR1` | Toggle clamp on/off |
| `SIGUSR2` | Force clamp ON (reset bypass) |

```sh
# Toggle
pkill -USR1 zapmenu

# Force clamp back on
pkill -USR2 zapmenu
```

### skhd example

```
cmd + alt - b : pkill -USR1 zapmenu
```

### AeroSpace example

Two things are needed: auto-start zapmenu at login, and a binding to toggle it.

In `after-startup-command`, launch zapmenu so it is always running:

```toml
after-startup-command = [
  "exec-and-forget /usr/local/bin/zapmenu"
]
```

Then bind the toggle inside a service mode (or any mode you prefer). The `b` key in `mode.service` here sends SIGUSR1 and returns to main mode:

```toml
mode.service.binding = {
  b = ["exec-and-forget /bin/bash -c 'pkill -USR1 zapmenu'" "mode main"]
}
```

Enter service mode with your existing binding (e.g. `alt-shift-semicolon = "mode service"`), then press `b` to toggle the clamp. See a [full working example in nix-darwin](https://github.com/kaynetik/kaynix/blob/03fcbf9e606d9291f2a4a8f7d452fa37d42e2c54/modules/aerospace.nix#L107).

### Hammerspoon example

```lua
hs.hotkey.bind({"cmd", "alt"}, "b", function()
  os.execute("pkill -USR1 zapmenu")
end)
```

## Build from source

Requires [Zig](https://ziglang.org/download/) 0.15.x and macOS with Xcode or Command Line Tools installed.

```sh
zig build                              # debug build
zig build -Doptimize=ReleaseFast       # release build (~51KB)
```

The binary is placed in `zig-out/bin/zapmenu`.

### Cross-compile (on macOS)

```sh
zig build -Dtarget=aarch64-macos       # Apple Silicon
zig build -Dtarget=x86_64-macos        # Intel
```

### Tests and benchmarks

```sh
zig build test                         # run unit tests
zig build bench                        # run hot-path benchmarks
```

## Benchmark

```bash
zig build bench

# clampY (clamped):     4713000ns total, 0ns/call (10000000 iters)
# clampY (passthrough): 3164917ns total, 0ns/call (10000000 iters)
# handleKeyDown (miss): 0ns total, 0ns/call (10000000 iters)
# toggleBypass:         42ns total, 0ns/call (10000000 iters)

# To measure idle CPU usage, run zapmenu manually and check:
#   ps -o %cpu,rss -p $(pgrep zapmenu)
```

## Notes

- This is a terminal application with no GUI.
- macOS-only (depends on CoreGraphics event taps).
- The 4px dead zone at the top of the screen may interfere with some apps; toggle it off with the hotkey or a signal.
