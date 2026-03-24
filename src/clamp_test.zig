const std = @import("std");
const clamp = @import("clamp.zig");
const c = @import("cg.zig");

test "clampY clamps values below min_y" {
    clamp.resetBypass();
    var y: f64 = 0.0;
    try std.testing.expect(clamp.clampY(&y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY clamps negative values" {
    clamp.resetBypass();
    var y: f64 = -10.0;
    try std.testing.expect(clamp.clampY(&y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY does not clamp values at min_y" {
    clamp.resetBypass();
    var y: f64 = clamp.min_y;
    try std.testing.expect(!clamp.clampY(&y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY does not clamp values above min_y" {
    clamp.resetBypass();
    var y: f64 = 500.0;
    try std.testing.expect(!clamp.clampY(&y));
    try std.testing.expectEqual(500.0, y);
}

test "clampY boundary: just below min_y" {
    clamp.resetBypass();
    var y: f64 = 3.999;
    try std.testing.expect(clamp.clampY(&y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY boundary: just above min_y" {
    clamp.resetBypass();
    var y: f64 = 4.001;
    try std.testing.expect(!clamp.clampY(&y));
    try std.testing.expectEqual(4.001, y);
}

test "bypass starts inactive" {
    clamp.resetBypass();
    try std.testing.expect(!clamp.isBypassActive());
}

test "bypass toggle with correct combo" {
    clamp.resetBypass();
    clamp.handleKeyDown(clamp.bypass_flags, clamp.bypass_keycode);
    try std.testing.expect(clamp.isBypassActive());
    clamp.handleKeyDown(clamp.bypass_flags, clamp.bypass_keycode);
    try std.testing.expect(!clamp.isBypassActive());
}

test "bypass ignores wrong keycode" {
    clamp.resetBypass();
    clamp.handleKeyDown(clamp.bypass_flags, 0);
    try std.testing.expect(!clamp.isBypassActive());
}

test "bypass ignores partial modifier: cmd only" {
    clamp.resetBypass();
    clamp.handleKeyDown(c.kCGEventFlagMaskCommand, clamp.bypass_keycode);
    try std.testing.expect(!clamp.isBypassActive());
}

test "bypass ignores partial modifier: option only" {
    clamp.resetBypass();
    clamp.handleKeyDown(c.kCGEventFlagMaskAlternate, clamp.bypass_keycode);
    try std.testing.expect(!clamp.isBypassActive());
}

test "bypass ignores no modifiers" {
    clamp.resetBypass();
    clamp.handleKeyDown(0, clamp.bypass_keycode);
    try std.testing.expect(!clamp.isBypassActive());
}

test "bypass works with extra modifier flags present" {
    clamp.resetBypass();
    const flags_with_shift = clamp.bypass_flags | 0x00020000;
    clamp.handleKeyDown(flags_with_shift, clamp.bypass_keycode);
    try std.testing.expect(clamp.isBypassActive());
    clamp.resetBypass();
}

test "clampY skips clamping when bypass is active" {
    clamp.resetBypass();
    clamp.handleKeyDown(clamp.bypass_flags, clamp.bypass_keycode);
    var y: f64 = 0.0;
    try std.testing.expect(!clamp.clampY(&y));
    try std.testing.expectEqual(0.0, y);
    clamp.resetBypass();
}

test "toggleBypass flips state" {
    clamp.resetBypass();
    try std.testing.expect(!clamp.isBypassActive());
    clamp.toggleBypass();
    try std.testing.expect(clamp.isBypassActive());
    clamp.toggleBypass();
    try std.testing.expect(!clamp.isBypassActive());
}

test "SIGUSR1 toggles bypass via signal handler" {
    clamp.resetBypass();
    clamp.installSignalHandler();
    std.posix.raise(std.posix.SIG.USR1) catch return;
    try std.testing.expect(clamp.isBypassActive());
    std.posix.raise(std.posix.SIG.USR1) catch return;
    try std.testing.expect(!clamp.isBypassActive());
}

test "SIGUSR2 resets bypass via signal handler" {
    clamp.resetBypass();
    clamp.installSignalHandler();
    clamp.toggleBypass();
    try std.testing.expect(clamp.isBypassActive());
    std.posix.raise(std.posix.SIG.USR2) catch return;
    try std.testing.expect(!clamp.isBypassActive());
}

test "CGEventMaskBit produces correct bitmask" {
    try std.testing.expectEqual(@as(u64, 1 << 5), c.CGEventMaskBit(c.kCGEventMouseMoved));
    try std.testing.expectEqual(@as(u64, 1 << 10), c.CGEventMaskBit(c.kCGEventKeyDown));
}
