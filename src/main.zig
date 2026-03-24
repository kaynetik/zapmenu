const std = @import("std");
const c = @import("cg.zig");
const clamp = @import("clamp.zig");

var tap_port: c.CFMachPortRef = null;

fn eventTapCallback(
    _: c.CGEventTapProxy,
    event_type: c.CGEventType,
    event: c.CGEventRef,
    _: ?*anyopaque,
) callconv(.c) c.CGEventRef {
    switch (event_type) {
        c.kCGEventKeyDown => {
            const was_active = clamp.isBypassActive();
            const flags = c.CGEventGetFlags(event);
            const keycode: u16 = @intCast(c.CGEventGetIntegerValueField(event, c.kCGKeyboardEventKeycode));
            clamp.handleKeyDown(flags, keycode);
            if (was_active != clamp.isBypassActive()) {
                logState();
            }
            return event;
        },
        c.kCGEventMouseMoved => {
            var point = c.CGEventGetLocation(event);
            if (clamp.clampY(&point.y)) {
                c.CGEventSetLocation(event, point);
            }
            return event;
        },
        c.kCGEventTapDisabledByTimeout, c.kCGEventTapDisabledByUserInput => {
            if (tap_port != null) c.CGEventTapEnable(tap_port, true);
            return event;
        },
        else => return event,
    }
}

fn logState() void {
    if (clamp.isBypassActive()) {
        printErr("zapmenu: clamp OFF\n");
    } else {
        printErr("zapmenu: clamp ON\n");
    }
}

fn printErr(comptime msg: []const u8) void {
    std.fs.File.stderr().writeAll(msg) catch {};
}

pub fn main() void {
    clamp.installSignalHandler();

    const event_mask: u64 = c.CGEventMaskBit(c.kCGEventMouseMoved) |
        c.CGEventMaskBit(c.kCGEventKeyDown);

    const event_tap = c.CGEventTapCreate(
        c.kCGHIDEventTap,
        c.kCGHeadInsertEventTap,
        c.kCGEventTapOptionDefault,
        event_mask,
        &eventTapCallback,
        null,
    );

    if (event_tap == null) {
        printErr("failed to create event tap (check Accessibility permissions)\n");
        std.process.exit(1);
    }

    tap_port = event_tap;

    const run_loop_source = c.CFMachPortCreateRunLoopSource(null, event_tap, 0);
    if (run_loop_source == null) {
        printErr("failed to create run loop source\n");
        std.process.exit(1);
    }

    c.CFRunLoopAddSource(c.CFRunLoopGetCurrent(), run_loop_source, c.kCFRunLoopDefaultMode);
    c.CGEventTapEnable(event_tap, true);
    c.CFRelease(event_tap);
    c.CFRelease(run_loop_source);

    printErr("zapmenu: clamp ON\n");
    c.CFRunLoopRun();
}
