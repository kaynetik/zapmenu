const std = @import("std");
const c = @import("cg.zig");
const clamp = @import("clamp.zig");

const log_path = "/tmp/zapmenu.log";

var tap_port: c.CFMachPortRef = null;
var debug_enabled: bool = false;
var skip_relaunch: bool = false;
var log_fd: c_int = -1;
var detached: bool = false;
var pinned_x: f64 = 0;
var menu_held: bool = false;
var reveal_limit: f64 = 30;

extern "c" fn _NSGetExecutablePath(buf: [*]u8, bufsize: *u32) c_int;

fn eventTapCallback(
    _: c.CGEventTapProxy,
    event_type: c.CGEventType,
    event: c.CGEventRef,
    _: ?*anyopaque,
) callconv(.c) c.CGEventRef {
    return switch (event_type) {
        c.kCGEventKeyDown => onKeyDown(event),
        c.kCGEventMouseMoved, c.kCGEventLeftMouseDragged, c.kCGEventRightMouseDragged, c.kCGEventOtherMouseDragged => onMouse(event),
        c.kCGEventTapDisabledByTimeout, c.kCGEventTapDisabledByUserInput => reenableTap(event),
        else => event,
    };
}

fn onKeyDown(event: c.CGEventRef) c.CGEventRef {
    const was_active = clamp.isBypassActive();
    const flags = c.CGEventGetFlags(event);
    const keycode: u16 = @intCast(c.CGEventGetIntegerValueField(event, c.kCGKeyboardEventKeycode));
    clamp.handleKeyDown(flags, keycode);
    if (was_active != clamp.isBypassActive()) {
        if (clamp.isBypassActive()) {
            reattach();
            releaseMenuBar();
        } else holdMenuBar();
        logState();
    }
    return event;
}

fn onMouse(event: c.CGEventRef) c.CGEventRef {
    if (clamp.isBypassActive()) {
        reattach();
        return event;
    }
    const dx = c.CGEventGetIntegerValueField(event, c.kCGMouseEventDeltaX);
    const dy = c.CGEventGetIntegerValueField(event, c.kCGMouseEventDeltaY);
    if (detached) return whileDetached(dx, dy);

    var point = c.CGEventGetLocation(event);
    if (point.y < reveal_limit) holdMenuBar();
    if (!clamp.clampY(&point.y)) return event;

    pinned_x = point.x;
    _ = c.CGWarpMouseCursorPosition(point);
    _ = c.CGAssociateMouseAndMouseCursorPosition(0);
    detached = true;
    return null;
}

fn reenableTap(event: c.CGEventRef) c.CGEventRef {
    printErr("zapmenu: tap disabled, re-enabling\n");
    if (tap_port != null) c.CGEventTapEnable(tap_port, true);
    return event;
}

fn whileDetached(dx: i64, dy: i64) c.CGEventRef {
    // CG y grows downward, so a positive delta leaves the 4px strip.
    if (!clamp.isBypassActive()) _ = c.SLSInterruptMenuBarReveal(c.SLSMainConnectionID());
    if (dy > 0) {
        pinned_x += @floatFromInt(dx);
        _ = c.CGWarpMouseCursorPosition(.{ .x = pinned_x, .y = clamp.min_y + @as(f64, @floatFromInt(dy)) });
        reattach();
        return null;
    }
    if (dx != 0) {
        pinned_x += @floatFromInt(dx);
        _ = c.CGWarpMouseCursorPosition(.{ .x = pinned_x, .y = clamp.min_y });
    }
    return null;
}

fn reattach() void {
    if (!detached) return;
    _ = c.CGAssociateMouseAndMouseCursorPosition(1);
    detached = false;
}

fn holdMenuBar() void {
    if (clamp.isBypassActive()) {
        releaseMenuBar();
        return;
    }
    const cid = c.SLSMainConnectionID();
    _ = c.SLSSetMenuBarInsetAndAlpha(cid, 0, 0, 0);
    _ = c.SLSInterruptMenuBarReveal(cid);
    c._HIMenuBarPositionLock();
    menu_held = true;
}

fn releaseMenuBar() void {
    if (!menu_held) return;
    restoreMenuBar();
    menu_held = false;
}

fn restoreMenuBar() void {
    const cid = c.SLSMainConnectionID();
    c._HIMenuBarPositionUnlock();
    _ = c.SLSSetMenuBarInsetAndAlpha(cid, 0, 0, 1);
    _ = c.SLSInterruptMenuBarReveal(cid);
}

fn handleExit(_: std.posix.SIG) callconv(.c) void {
    _ = c.CGAssociateMouseAndMouseCursorPosition(1);
    restoreMenuBar();
    std.process.exit(0);
}

fn logState() void {
    printErr(if (clamp.isBypassActive()) "zapmenu: clamp OFF\n" else "zapmenu: clamp ON\n");
}

fn logPoint(tag: []const u8, y: f64) void {
    var buf: [80]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "zapmenu: {s} y={d:.2}\n", .{ tag, y }) catch return;
    printErr(msg);
}

fn requestControlAccess() void {
    logAccess("input-monitoring (listen)", c.IOHIDCheckAccess(c.kIOHIDRequestTypeListenEvent));
    const post = c.IOHIDCheckAccess(c.kIOHIDRequestTypePostEvent);
    logAccess("device-control (post)", post);
    if (post != c.kIOHIDAccessTypeGranted) requestPostEventAccess();

    const trusted = axClientTrusted();
    printErr(if (trusted) "zapmenu: device-control client trusted\n" else "zapmenu: device-control client not trusted\n");
}

fn requestPostEventAccess() void {
    _ = c.IOHIDRequestAccess(c.kIOHIDRequestTypePostEvent);
    if (!c.CGPreflightPostEventAccess()) _ = c.CGRequestPostEventAccess();
}

fn axClientTrusted() bool {
    const keys = [_]*anyopaque{c.kAXTrustedCheckOptionPrompt};
    const values = [_]*anyopaque{c.kCFBooleanTrue};
    const options = c.CFDictionaryCreate(
        null,
        &keys,
        &values,
        1,
        &c.kCFTypeDictionaryKeyCallBacks,
        &c.kCFTypeDictionaryValueCallBacks,
    );
    defer if (options) |dict| c.CFRelease(dict);
    return c.AXIsProcessTrustedWithOptions(options);
}

fn logAccess(tag: []const u8, access: c.IOHIDAccessType) void {
    const state = switch (access) {
        c.kIOHIDAccessTypeGranted => "granted",
        c.kIOHIDAccessTypeDenied => "denied",
        else => "unknown",
    };
    var buf: [96]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "zapmenu: {s} = {s}\n", .{ tag, state }) catch return;
    printErr(msg);
}

/// A terminal launch is judged as the parent app, so that app's Device Control
/// switch is what TCC checks. Start the bundle on its own when that happens.
/// Otherwise the tap was denied for this binary: name the macOS 27 pane and open it.
fn macos27Notification() noreturn {
    if (relaunchViaLaunchServices()) {
        printErr("zapmenu: a terminal launch is judged as the parent app, so the zapmenu switch is ignored.\n");
        printErr("zapmenu: started Zapmenu.app on its own. log: " ++ log_path ++ "\n");
        std.process.exit(0);
    }
    printErr("failed to create event tap.\n");
    printErr("macOS 27 renamed Accessibility to Device Control and Data Access.\n");
    printErr("Input Monitoring is not enough: moving the cursor needs that pane.\n");
    printErr("  System Settings → Privacy & Security → Device Control and Data Access\n");
    printErr("enable zapmenu there, then run it again.\n");
    _ = c.system("open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\"");
    std.process.exit(1);
}

fn relaunchViaLaunchServices() bool {
    if (skip_relaunch) return false;
    var path_buf: [1024]u8 = undefined;
    var size: u32 = path_buf.len;
    if (_NSGetExecutablePath(&path_buf, &size) != 0) return false;
    const exe_path = std.mem.sliceTo(&path_buf, 0);
    const marker = ".app/Contents/MacOS/";
    const idx = std.mem.indexOf(u8, exe_path, marker) orelse return false;
    const app = exe_path[0 .. idx + 4];
    var cmd_buf: [1200]u8 = undefined;
    const cmd = std.fmt.bufPrintZ(&cmd_buf, "open \"{s}\" --args --no-relaunch{s}", .{
        app,
        if (debug_enabled) " --debug" else "",
    }) catch return false;
    return c.system(cmd.ptr) == 0;
}

fn printErr(msg: []const u8) void {
    _ = std.posix.system.write(std.posix.STDERR_FILENO, msg.ptr, msg.len);
    if (log_fd < 0) {
        log_fd = std.c.open(log_path, .{
            .ACCMODE = .WRONLY,
            .CREAT = true,
            .APPEND = true,
        }, @as(c_uint, 0o644));
    }
    if (log_fd >= 0) _ = std.posix.system.write(log_fd, msg.ptr, msg.len);
}

fn readCursorY() ?f64 {
    const event = c.CGEventCreate(null) orelse return null;
    defer c.CFRelease(event);
    return c.CGEventGetLocation(event).y;
}

fn runProbe() void {
    printErr("zapmenu: probe — move to the top edge; Ctrl+C to stop\n");
    printErr("zapmenu: if Y reaches 0.00, the hardware cursor is not clamped\n");
    var last_bucket: i32 = -1;
    while (true) {
        if (readCursorY()) |y| {
            const bucket: i32 = @intFromFloat(@floor(y));
            if (bucket != last_bucket) {
                last_bucket = bucket;
                logPoint("probe", y);
            }
        } else {
            printErr("failed to read cursor position\n");
            std.process.exit(1);
        }
        _ = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 0.05, false);
    }
}

const Mode = enum { run, probe };

fn parseArgs(args: std.process.Args) Mode {
    var it = std.process.Args.Iterator.init(args);
    _ = it.skip();
    var mode: Mode = .run;
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--debug")) {
            debug_enabled = true;
        } else if (std.mem.eql(u8, arg, "--no-relaunch")) {
            skip_relaunch = true;
        } else if (std.mem.eql(u8, arg, "--probe")) {
            mode = .probe;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printErr("usage: zapmenu [--debug] [--probe]\n");
            std.process.exit(0);
        } else {
            printErr("unknown argument (try --help)\n");
            std.process.exit(1);
        }
    }
    return mode;
}

/// A warp otherwise swallows local mouse moves for 0.25s. The source has to
/// stay alive; releasing it drops the interval.
fn disableWarpSuppression() void {
    _ = c.CGSetLocalEventsSuppressionInterval(0);
    if (c.CGEventSourceCreate(c.kCGEventSourceStateHIDSystemState)) |src| {
        c.CGEventSourceSetLocalEventsSuppressionInterval(src, 0);
    }
}

fn installExitHandler() void {
    const exit_act = std.posix.Sigaction{
        .handler = .{ .handler = handleExit },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.RESTART,
    };
    std.posix.sigaction(std.posix.SIG.INT, &exit_act, null);
    std.posix.sigaction(std.posix.SIG.TERM, &exit_act, null);
}

fn createEventTap() c.CFMachPortRef {
    const event_mask: u64 = c.CGEventMaskBit(c.kCGEventMouseMoved) |
        c.CGEventMaskBit(c.kCGEventLeftMouseDragged) |
        c.CGEventMaskBit(c.kCGEventRightMouseDragged) |
        c.CGEventMaskBit(c.kCGEventOtherMouseDragged) |
        c.CGEventMaskBit(c.kCGEventKeyDown);
    return c.CGEventTapCreate(
        c.kCGHIDEventTap,
        c.kCGHeadInsertEventTap,
        c.kCGEventTapOptionDefault,
        event_mask,
        &eventTapCallback,
        null,
    );
}

fn installEventTap(event_tap: c.CFMachPortRef) void {
    tap_port = event_tap;
    const run_loop_source = c.CFMachPortCreateRunLoopSource(null, event_tap, 0);
    if (run_loop_source == null) {
        printErr("failed to create run loop source\n");
        std.process.exit(1);
    }
    c.CFRunLoopAddSource(c.CFRunLoopGetCurrent(), run_loop_source, c.kCFRunLoopDefaultMode);
    c.CGEventTapEnable(event_tap, true);
    if (!c.CGEventTapIsEnabled(event_tap)) {
        printErr("event tap disabled (grant Device Control and Data Access)\n");
        std.process.exit(1);
    }
    c.CFRelease(event_tap);
    c.CFRelease(run_loop_source);
}

fn runLoop() void {
    while (true) {
        if (clamp.isBypassActive()) releaseMenuBar() else holdMenuBar();
        _ = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 0.2, false);
    }
}

pub fn main(init: std.process.Init.Minimal) void {
    printErr("zapmenu: start (log " ++ log_path ++ ")\n");
    if (parseArgs(init.args) == .probe) {
        runProbe();
        return;
    }

    clamp.installSignalHandler();
    installExitHandler();
    requestControlAccess();
    disableWarpSuppression();

    const event_tap = createEventTap() orelse macos27Notification();
    installEventTap(event_tap);

    const bar_h: f64 = @floatFromInt(c.GetMBarHeight());
    if (bar_h > reveal_limit) reveal_limit = bar_h;
    holdMenuBar();
    printErr("zapmenu: clamp ON (top 4px)\n");
    runLoop();
}
