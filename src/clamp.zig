const std = @import("std");
const c = @import("cg.zig");

pub const min_y: f64 = 4.0;
pub const bypass_flags: u64 = c.kCGEventFlagMaskCommand | c.kCGEventFlagMaskAlternate;
pub const bypass_keycode: u16 = 11;

var bypass_active: bool = false;

pub fn isBypassActive() bool {
    return bypass_active;
}

pub fn resetBypass() void {
    bypass_active = false;
}

pub fn toggleBypass() void {
    bypass_active = !bypass_active;
}

pub fn clampY(y: *f64) bool {
    if (bypass_active) return false;
    if (y.* < min_y) {
        y.* = min_y;
        return true;
    }
    return false;
}

pub fn handleKeyDown(flags: u64, keycode: u16) void {
    if ((flags & bypass_flags) == bypass_flags and keycode == bypass_keycode) {
        bypass_active = !bypass_active;
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

fn handleSignal(sig: i32) callconv(.c) void {
    switch (sig) {
        std.posix.SIG.USR1 => bypass_active = !bypass_active,
        std.posix.SIG.USR2 => bypass_active = false,
        else => {},
    }
}
