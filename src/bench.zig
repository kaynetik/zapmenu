const std = @import("std");
const clamp = @import("clamp.zig");

const iterations: u64 = 10_000_000;

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const elapsed = start.untilNow(io, .awake);
    return @intCast(elapsed.nanoseconds);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var buf: [512]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buf);
    const w: *std.Io.Writer = &writer.interface;

    clamp.resetBypass();

    {
        const start = std.Io.Timestamp.now(io, .awake);
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            var y: f64 = 1.0;
            _ = clamp.clampY(&y);
            std.mem.doNotOptimizeAway(&y);
        }
        const ns = elapsedNs(io, start);
        try w.print("clampY (clamped):     {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
    }

    {
        const start = std.Io.Timestamp.now(io, .awake);
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            var y: f64 = 500.0;
            _ = clamp.clampY(&y);
            std.mem.doNotOptimizeAway(&y);
        }
        const ns = elapsedNs(io, start);
        try w.print("clampY (passthrough): {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
    }

    {
        const start = std.Io.Timestamp.now(io, .awake);
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            clamp.handleKeyDown(0, 0);
        }
        const ns = elapsedNs(io, start);
        try w.print("handleKeyDown (miss): {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
    }

    {
        const start = std.Io.Timestamp.now(io, .awake);
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            clamp.toggleBypass();
        }
        const ns = elapsedNs(io, start);
        try w.print("toggleBypass:         {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
        clamp.resetBypass();
    }

    try w.print("\nTo measure idle CPU usage, run zapmenu manually and check:\n", .{});
    try w.print("  ps -o %cpu,rss -p $(pgrep zapmenu)\n", .{});
    try w.flush();
}
