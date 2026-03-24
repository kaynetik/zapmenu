// Extern declarations for macOS CoreGraphics / CoreFoundation symbols used by zapmenu.
// Hand-written to avoid depending on system headers at build time.

pub const CGEventRef = ?*opaque {};
pub const CGEventTapProxy = ?*opaque {};
pub const CFMachPortRef = ?*opaque {};
pub const CFRunLoopSourceRef = ?*opaque {};
pub const CFRunLoopRef = ?*opaque {};
pub const CFAllocatorRef = ?*opaque {};
pub const CFRunLoopMode = ?*opaque {};
pub const CFIndex = i64;
pub const CGEventType = u32;
pub const CGEventFlags = u64;
pub const CGEventMask = u64;
pub const CGEventField = u32;

pub const CGPoint = extern struct {
    x: f64,
    y: f64,
};

pub const kCGEventMouseMoved: CGEventType = 5;
pub const kCGEventKeyDown: CGEventType = 10;
pub const kCGEventTapDisabledByTimeout: CGEventType = 0xFFFFFFFE;
pub const kCGEventTapDisabledByUserInput: CGEventType = 0xFFFFFFFF;

pub const kCGEventFlagMaskCommand: CGEventFlags = 0x00100000;
pub const kCGEventFlagMaskAlternate: CGEventFlags = 0x00080000;

pub const kCGKeyboardEventKeycode: CGEventField = 9;

pub const kCGHIDEventTap: u32 = 0;
pub const kCGHeadInsertEventTap: u32 = 0;
pub const kCGEventTapOptionDefault: u32 = 0;

pub inline fn CGEventMaskBit(event_type: CGEventType) CGEventMask {
    return @as(CGEventMask, 1) << @intCast(event_type);
}

pub const CGEventTapCallBack = *const fn (
    CGEventTapProxy,
    CGEventType,
    CGEventRef,
    ?*anyopaque,
) callconv(.c) CGEventRef;

pub extern "CoreGraphics" fn CGEventTapCreate(
    tap: u32,
    place: u32,
    options: u32,
    events_of_interest: CGEventMask,
    callback: CGEventTapCallBack,
    user_info: ?*anyopaque,
) callconv(.c) CFMachPortRef;

pub extern "CoreGraphics" fn CGEventTapEnable(
    tap: CFMachPortRef,
    enable: bool,
) callconv(.c) void;

pub extern "CoreGraphics" fn CGEventGetLocation(
    event: CGEventRef,
) callconv(.c) CGPoint;

pub extern "CoreGraphics" fn CGEventSetLocation(
    event: CGEventRef,
    point: CGPoint,
) callconv(.c) void;

pub extern "CoreGraphics" fn CGEventGetFlags(
    event: CGEventRef,
) callconv(.c) CGEventFlags;

pub extern "CoreGraphics" fn CGEventGetIntegerValueField(
    event: CGEventRef,
    field: CGEventField,
) callconv(.c) i64;

pub extern "CoreFoundation" fn CFMachPortCreateRunLoopSource(
    allocator: CFAllocatorRef,
    port: CFMachPortRef,
    order: CFIndex,
) callconv(.c) CFRunLoopSourceRef;

pub extern "CoreFoundation" fn CFRunLoopGetCurrent() callconv(.c) CFRunLoopRef;

pub extern "CoreFoundation" fn CFRunLoopAddSource(
    rl: CFRunLoopRef,
    source: CFRunLoopSourceRef,
    mode: CFRunLoopMode,
) callconv(.c) void;

pub extern "CoreFoundation" fn CFRunLoopRun() callconv(.c) void;

pub extern "CoreFoundation" fn CFRelease(cf: ?*anyopaque) callconv(.c) void;

pub extern "CoreFoundation" var kCFRunLoopDefaultMode: CFRunLoopMode;
