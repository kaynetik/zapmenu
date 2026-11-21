const std = @import("std");
const c = @import("cg.zig");

/// Pixels kept between the cursor and the top edge of a display. CG y grows
/// downward, and the top edge of a display is its `origin.y` in global space,
/// which is negative for any display placed above the main one.
pub const min_y: f64 = 4.0;

/// A display's bounds in global CG space (`CGDisplayBounds`). `menu_bar` is
/// false for a display that never shows one: every display but the main one
/// when "Displays have separate Spaces" is off.
pub const Rect = struct { x: f64, y: f64, w: f64, h: f64, menu_bar: bool = true };

/// Top edge assumed when no display list is available: the pre-multi-monitor
/// behaviour of treating global y = 0 as the top of the screen.
pub const fallback_top: f64 = 0.0;

/// Distance from `pos` to the half-open span [start, start + len). Zero inside.
fn spanGap(pos: f64, start: f64, len: f64) f64 {
    if (pos < start) return start - pos;
    const end = start + len;
    if (pos >= end) return pos - end + 1;
    return 0;
}

/// The display a pointer at (x, y) belongs to. A display whose x-span covers the
/// pointer wins over one that does not, then the one closest vertically. The
/// pointer can sit just outside every display (mid-warp, mid-reconfiguration),
/// so containment alone is not enough, and x is the primary key because the
/// edge being guarded is horizontal. `rects` must not be empty.
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

/// Top edge to clamp against for a pointer at (x, y), or null when there is
/// nothing to guard: the display has no menu bar, or its top is not exposed
/// because another display sits directly above it at this x. There the pointer
/// must be free to cross, or the display above would be unreachable.
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

/// Where a detached (pinned) cursor should be, given the exposed top edge of
/// the display it is now over. Sliding sideways along the top edge can carry
/// the pin onto a display with a different top, so this is re-evaluated on
/// every detached event. `free` means the cursor is no longer in the guard
/// band of that display and should be handed back to the user.
pub const Pin = struct { y: f64, free: bool };

pub fn pinFor(top: ?f64, pinned_y: f64) Pin {
    const t = top orelse return .{ .y = pinned_y, .free = true };
    const limit = t + min_y;
    if (pinned_y > limit) return .{ .y = pinned_y, .free = true };
    return .{ .y = limit, .free = false };
}
pub const bypass_flags: u64 = c.kCGEventFlagMaskCommand | c.kCGEventFlagMaskAlternate;
pub const bypass_keycode: u16 = 11;

/// Written from the SIGUSR handlers as well as the event tap, hence atomic.
var bypass_active: std.atomic.Value(bool) = .init(false);

pub fn isBypassActive() bool {
    return bypass_active.load(.monotonic);
}

pub fn resetBypass() void {
    bypass_active.store(false, .monotonic);
}

/// Returns the new state.
pub fn toggleBypass() bool {
    const next = !isBypassActive();
    bypass_active.store(next, .monotonic);
    return next;
}

/// Clamp `y` to `min_y` below `top`, the top edge of the display the pointer is
/// on (see `exposedTop`). Returns true when `y` was moved.
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
