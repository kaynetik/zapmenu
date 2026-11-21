const std = @import("std");
const clamp = @import("clamp.zig");
const c = @import("cg.zig");

test "clampY clamps values below min_y" {
    clamp.resetBypass();
    var y: f64 = 0.0;
    try std.testing.expect(clamp.clampY(0.0, &y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY clamps negative values" {
    clamp.resetBypass();
    var y: f64 = -10.0;
    try std.testing.expect(clamp.clampY(0.0, &y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY does not clamp values at min_y" {
    clamp.resetBypass();
    var y: f64 = clamp.min_y;
    try std.testing.expect(!clamp.clampY(0.0, &y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY does not clamp values above min_y" {
    clamp.resetBypass();
    var y: f64 = 500.0;
    try std.testing.expect(!clamp.clampY(0.0, &y));
    try std.testing.expectEqual(500.0, y);
}

test "clampY boundary: just below min_y" {
    clamp.resetBypass();
    var y: f64 = 3.999;
    try std.testing.expect(clamp.clampY(0.0, &y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "clampY boundary: just above min_y" {
    clamp.resetBypass();
    var y: f64 = 4.001;
    try std.testing.expect(!clamp.clampY(0.0, &y));
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
    try std.testing.expect(!clamp.clampY(0.0, &y));
    try std.testing.expectEqual(0.0, y);
    clamp.resetBypass();
}

test "toggleBypass flips state" {
    clamp.resetBypass();
    try std.testing.expect(!clamp.isBypassActive());
    _ = clamp.toggleBypass();
    try std.testing.expect(clamp.isBypassActive());
    _ = clamp.toggleBypass();
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
    _ = clamp.toggleBypass();
    try std.testing.expect(clamp.isBypassActive());
    std.posix.raise(std.posix.SIG.USR2) catch return;
    try std.testing.expect(!clamp.isBypassActive());
}

test "CGEventMaskBit produces correct bitmask" {
    try std.testing.expectEqual(@as(u64, 1 << 5), c.CGEventMaskBit(c.kCGEventMouseMoved));
    try std.testing.expectEqual(@as(u64, 1 << 10), c.CGEventMaskBit(c.kCGEventKeyDown));
}

// Layout from the 1.2.0 multi-monitor report: a vertical display whose top
// (y = -712) sits above the main display's.
const main_display: clamp.Rect = .{ .x = 0, .y = 0, .w = 3200, .h = 1800 };
const vertical_display: clamp.Rect = .{ .x = -1800, .y = -712, .w = 1800, .h = 3200 };
const reported_layout = [_]clamp.Rect{ main_display, vertical_display };

/// Mirrors `onMouse`.
fn clampAt(rects: []const clamp.Rect, x: f64, y: *f64) bool {
    const top = clamp.exposedTop(rects, x, y.*) orelse return false;
    return clamp.clampY(top, y);
}

test "reported layout: pointer inside the top of the vertical display is not clamped" {
    clamp.resetBypass();
    var y: f64 = -300.0;
    try std.testing.expect(!clampAt(&reported_layout, -900, &y));
    try std.testing.expectEqual(-300.0, y);
}

test "reported layout: vertical display clamps against its own top, not y=0" {
    clamp.resetBypass();
    var y: f64 = -711.0;
    try std.testing.expect(clampAt(&reported_layout, -900, &y));
    try std.testing.expectEqual(-708.0, y);
}

test "reported layout: vertical display top edge is clamped to its own guard line" {
    clamp.resetBypass();
    var y: f64 = -712.0;
    try std.testing.expect(clampAt(&reported_layout, -900, &y));
    try std.testing.expectEqual(vertical_display.y + clamp.min_y, y);
}

test "reported layout: main display still clamps at y=4" {
    clamp.resetBypass();
    var y: f64 = 1.0;
    try std.testing.expect(clampAt(&reported_layout, 1600, &y));
    try std.testing.expectEqual(clamp.min_y, y);
    var below: f64 = 100.0;
    try std.testing.expect(!clampAt(&reported_layout, 1600, &below));
}

test "reported layout: boundary column x=0 belongs to the main display" {
    clamp.resetBypass();
    var y: f64 = 1.0;
    try std.testing.expect(clampAt(&reported_layout, 0, &y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "reported layout: bypass still disables the per-display clamp" {
    clamp.resetBypass();
    _ = clamp.toggleBypass();
    defer clamp.resetBypass();
    var y: f64 = -711.0;
    try std.testing.expect(!clampAt(&reported_layout, -900, &y));
    try std.testing.expectEqual(-711.0, y);
}

test "exposedTop: pointer slightly outside every display resolves to the nearest" {
    try std.testing.expectEqual(-712.0, clamp.exposedTop(&reported_layout, -900, -730));
    try std.testing.expectEqual(0.0, clamp.exposedTop(&reported_layout, 3300, 50));
}

test "exposedTop: display stacked above main leaves main's top free to cross" {
    const above: clamp.Rect = .{ .x = 0, .y = -1000, .w = 3200, .h = 1000 };
    const rects = [_]clamp.Rect{ main_display, above };
    try std.testing.expectEqual(@as(?f64, null), clamp.exposedTop(&rects, 1600, 1));
    try std.testing.expectEqual(@as(?f64, -1000.0), clamp.exposedTop(&rects, 1600, -999));
    var y: f64 = 1.0;
    try std.testing.expect(!clampAt(&rects, 1600, &y));
    try std.testing.expectEqual(1.0, y);
}

test "exposedTop: display stacked below main does not clamp at the seam" {
    const below: clamp.Rect = .{ .x = 0, .y = 1800, .w = 3200, .h = 1000 };
    const rects = [_]clamp.Rect{ main_display, below };
    try std.testing.expectEqual(@as(?f64, null), clamp.exposedTop(&rects, 1600, 1801));
    var y: f64 = 1801.0;
    try std.testing.expect(!clampAt(&rects, 1600, &y));
}

test "exposedTop: a display covering only part of the width frees only that part" {
    const narrow_above: clamp.Rect = .{ .x = 0, .y = -500, .w = 1000, .h = 500 };
    const rects = [_]clamp.Rect{ main_display, narrow_above };
    try std.testing.expectEqual(@as(?f64, null), clamp.exposedTop(&rects, 500, 1));
    try std.testing.expectEqual(@as(?f64, 0.0), clamp.exposedTop(&rects, 2000, 1));
}

test "exposedTop: a detached display's own top stays exposed" {
    const far: clamp.Rect = .{ .x = 0, .y = 5000, .w = 1000, .h = 1000 };
    const rects = [_]clamp.Rect{ main_display, far };
    try std.testing.expectEqual(@as(?f64, 5000.0), clamp.exposedTop(&rects, 500, 5001));
}

test "exposedTop: empty display list falls back to the legacy top" {
    try std.testing.expectEqual(@as(?f64, clamp.fallback_top), clamp.exposedTop(&.{}, 10, -50));
}

test "pinFor: pin on the line stays pinned" {
    const p = clamp.pinFor(-712.0, -708.0);
    try std.testing.expect(!p.free);
    try std.testing.expectEqual(-708.0, p.y);
}

test "pinFor: sliding from the vertical display onto main re-pins at main's guard line" {
    const p = clamp.pinFor(0.0, -708.0);
    try std.testing.expect(!p.free);
    try std.testing.expectEqual(clamp.min_y, p.y);
}

test "pinFor: sliding from main into the vertical display's open area releases" {
    const p = clamp.pinFor(-712.0, clamp.min_y);
    try std.testing.expect(p.free);
    try std.testing.expectEqual(clamp.min_y, p.y);
}

test "pinFor: unexposed top releases" {
    try std.testing.expect(clamp.pinFor(null, 4.0).free);
}

test "toggleBypass returns the new state" {
    clamp.resetBypass();
    try std.testing.expect(clamp.toggleBypass());
    try std.testing.expect(!clamp.toggleBypass());
}

// "Displays have separate Spaces" off: only main has a menu bar.
const single_bar_layout = [_]clamp.Rect{
    main_display,
    .{ .x = -1800, .y = -712, .w = 1800, .h = 3200, .menu_bar = false },
};

test "single menu bar: display without a menu bar is never clamped" {
    clamp.resetBypass();
    try std.testing.expectEqual(@as(?f64, null), clamp.exposedTop(&single_bar_layout, -900, -712));
    var y: f64 = -712.0;
    try std.testing.expect(!clampAt(&single_bar_layout, -900, &y));
    try std.testing.expectEqual(-712.0, y);
}

test "single menu bar: main display is still clamped" {
    clamp.resetBypass();
    var y: f64 = 0.0;
    try std.testing.expect(clampAt(&single_bar_layout, 1600, &y));
    try std.testing.expectEqual(clamp.min_y, y);
}

test "single menu bar: a pin sliding onto a bar-less display is released" {
    const top = clamp.exposedTop(&single_bar_layout, -5, clamp.min_y);
    try std.testing.expect(clamp.pinFor(top, clamp.min_y).free);
}
