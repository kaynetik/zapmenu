const std = @import("std");
const clamp = @import("clamp.zig");

const iterations: u64 = 10_000_000;

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var writer = std.fs.File.stderr().writer(&buf);
    const w: *std.Io.Writer = &writer.interface;

    clamp.resetBypass();

    {
        var timer = try std.time.Timer.start();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            var y: f64 = 1.0;
            _ = clamp.clampY(&y);
            std.mem.doNotOptimizeAway(&y);
        }
        const ns = timer.read();
        try w.print("clampY (clamped):     {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
    }

    {
        var timer = try std.time.Timer.start();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            var y: f64 = 500.0;
            _ = clamp.clampY(&y);
            std.mem.doNotOptimizeAway(&y);
        }
        const ns = timer.read();
        try w.print("clampY (passthrough): {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
    }

    {
        var timer = try std.time.Timer.start();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            clamp.handleKeyDown(0, 0);
        }
        const ns = timer.read();
        try w.print("handleKeyDown (miss): {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
    }

    {
        var timer = try std.time.Timer.start();
        var i: u64 = 0;
        while (i < iterations) : (i += 1) {
            clamp.toggleBypass();
        }
        const ns = timer.read();
        try w.print("toggleBypass:         {d}ns total, {d}ns/call ({d} iters)\n", .{ ns, ns / iterations, iterations });
        clamp.resetBypass();
    }

    try w.print("\nTo measure idle CPU usage, run zapmenu manually and check:\n", .{});
    try w.print("  ps -o %cpu,rss -p $(pgrep zapmenu)\n", .{});
    try w.flush();
}
