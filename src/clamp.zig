const std = @import("std");
const c = @import("cg.zig");

/// Pixels kept below a display's top edge. CG y grows downward; the top edge is
/// the display's origin.y, negative for displays above the main one.
pub const min_y: f64 = 4.0;

/// Display bounds in global CG space. `menu_bar` is false for displays without
/// one ("Displays have separate Spaces" off: all but the main display).
pub const Rect = struct { x: f64, y: f64, w: f64, h: f64, menu_bar: bool = true };

/// Top edge used when no display list is available.
pub const fallback_top: f64 = 0.0;

fn spanGap(pos: f64, start: f64, len: f64) f64 {
    if (pos < start) return start - pos;
    const end = start + len;
    if (pos >= end) return pos - end + 1;
    return 0;
}

/// The display for a pointer at (x, y): x-span coverage first, then vertical
/// proximity, so a pointer just outside every display (mid-warp) still resolves.
/// `rects` must not be empty.
pub fn displayFor(rects: []const Rect, x: f64, y: f64) Rect {
    var best = rects[0];
    var best_gx = spanGap(x, best.x, best.w);
    var best_gy = spanGap(y, best.y, best.h);
    for (rects[1..]) |r| {
        const gx = spanGap(x, r.x, r.w);
        const gy = spanGap(y, r.y, r.h);
        if (gx < best_gx or (gx == best_gx and gy < best_gy)) {
            best = r;
            best_gx = gx;
            best_gy = gy;
        }
    }
    return best;
}

/// Top edge to clamp against at (x, y), or null when there is nothing to guard:
/// no menu bar, or another display directly above (clamping there would make
/// that display unreachable).
pub fn exposedTop(rects: []const Rect, x: f64, y: f64) ?f64 {
    if (rects.len == 0) return fallback_top;
    const d = displayFor(rects, x, y);
    if (!d.menu_bar) return null;
    const px = @min(@max(x, d.x), d.x + d.w - 1);
    for (rects) |e| {
        if (e.y < d.y and e.y + e.h >= d.y and px >= e.x and px < e.x + e.w) return null;
    }
    return d.y;
}

/// Pin position for a detached cursor over a display with the given top.
/// `free` means it is outside that display's guard band and should be released.
pub const Pin = struct { y: f64, free: bool };

pub fn pinFor(top: ?f64, pinned_y: f64) Pin {
    const t = top orelse return .{ .y = pinned_y, .free = true };
    const limit = t + min_y;
    if (pinned_y > limit) return .{ .y = pinned_y, .free = true };
    return .{ .y = limit, .free = false };
}
pub const bypass_flags: u64 = c.kCGEventFlagMaskCommand | c.kCGEventFlagMaskAlternate;
pub const bypass_keycode: u16 = 11;

/// Also written from signal handlers, hence atomic.
var bypass_active: std.atomic.Value(bool) = .init(false);

pub fn isBypassActive() bool {
    return bypass_active.load(.monotonic);
}

pub fn resetBypass() void {
    bypass_active.store(false, .monotonic);
}

pub fn toggleBypass() bool {
    const next = !isBypassActive();
    bypass_active.store(next, .monotonic);
    return next;
}

/// Clamps `y` to `top + min_y`; true when it moved.
pub fn clampY(top: f64, y: *f64) bool {
    if (isBypassActive()) return false;
    const limit = top + min_y;
    if (y.* < limit) {
        y.* = limit;
        return true;
    }
    return false;
}

pub fn handleKeyDown(flags: u64, keycode: u16) void {
    if ((flags & bypass_flags) == bypass_flags and keycode == bypass_keycode) {
        _ = toggleBypass();
    }
}

pub fn installSignalHandler() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleSignal },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.RESTART,
    };
    std.posix.sigaction(std.posix.SIG.USR1, &act, null);
    std.posix.sigaction(std.posix.SIG.USR2, &act, null);
}

fn handleSignal(sig: std.posix.SIG) callconv(.c) void {
    switch (sig) {
        std.posix.SIG.USR1 => logSignal(if (toggleBypass()) "zapmenu: clamp OFF\n" else "zapmenu: clamp ON\n"),
        std.posix.SIG.USR2 => {
            resetBypass();
            logSignal("zapmenu: clamp ON\n");
        },
        else => {},
    }
}

fn logSignal(msg: []const u8) void {
    _ = std.posix.system.write(std.posix.STDERR_FILENO, msg.ptr, msg.len);
}
