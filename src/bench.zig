const std = @import("std");
const clamp = @import("clamp.zig");

const iterations: u64 = 10_000_000;

const layout = [_]clamp.Rect{
    .{ .x = 0, .y = 0, .w = 3200, .h = 1800 },
    .{ .x = -1800, .y = -712, .w = 1800, .h = 3200 },
};

/// Inputs go through `doNotOptimizeAway` so ReleaseFast cannot fold the call
/// into a constant and report a loop that never ran.
fn opaqueValue(v: anytype) @TypeOf(v) {
    var x = v;
    std.mem.doNotOptimizeAway(&x);
    return x;
}

fn clamped() void {
    var y: f64 = opaqueValue(@as(f64, 1.0));
    _ = clamp.clampY(0.0, &y);
    std.mem.doNotOptimizeAway(&y);
}

fn passthrough() void {
    var y: f64 = opaqueValue(@as(f64, 500.0));
    _ = clamp.clampY(0.0, &y);
    std.mem.doNotOptimizeAway(&y);
}

fn exposedTop() void {
    var top = clamp.exposedTop(opaqueValue(@as([]const clamp.Rect, &layout)), opaqueValue(@as(f64, -900.0)), -300.0);
    std.mem.doNotOptimizeAway(&top);
}

fn keyDownMiss() void {
    clamp.handleKeyDown(opaqueValue(@as(u64, 0)), opaqueValue(@as(u16, 0)));
}

fn toggle() void {
    var state = clamp.toggleBypass();
    std.mem.doNotOptimizeAway(&state);
}

const cases = .{
    .{ "clampY (clamped)", clamped },
    .{ "clampY (passthrough)", passthrough },
    .{ "exposedTop (2 displays)", exposedTop },
    .{ "handleKeyDown (miss)", keyDownMiss },
    .{ "toggleBypass", toggle },
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var buf: [512]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buf);
    const w: *std.Io.Writer = &writer.interface;

    inline for (cases) |case| {
        clamp.resetBypass();
        const start = std.Io.Timestamp.now(io, .awake);
        var i: u64 = 0;
        while (i < iterations) : (i += 1) case[1]();
        const ns: u64 = @intCast(start.untilNow(io, .awake).nanoseconds);
        const per_call = @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(iterations));
        try w.print("{s:<24} {d:>5.2} ns/call ({d} iters)\n", .{ case[0], per_call, iterations });
    }
    clamp.resetBypass();

    try w.print("\nTo measure idle CPU usage, run zapmenu manually and check:\n", .{});
    try w.print("  ps -o %cpu,rss -p $(pgrep zapmenu)\n", .{});
    try w.flush();
}
