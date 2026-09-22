// Extern declarations for macOS CoreGraphics / CoreFoundation symbols used by zapmenu.
// Hand-written to avoid depending on system headers at build time.

pub const CGEventRef = ?*opaque {};
pub const CGEventTapProxy = ?*opaque {};
pub const CGEventSourceRef = ?*opaque {};
pub const CFMachPortRef = ?*opaque {};
pub const CFRunLoopSourceRef = ?*opaque {};
pub const CFRunLoopRef = ?*opaque {};
pub const CFAllocatorRef = ?*opaque {};
pub const CFRunLoopMode = ?*opaque {};
pub const CFIndex = i64;
pub const CGError = i32;
pub const CGEventType = u32;
pub const CGEventFlags = u64;
pub const CGEventMask = u64;
pub const CGEventField = u32;
pub const CGEventSourceStateID = i32;

pub const CGPoint = extern struct {
    x: f64,
    y: f64,
};

pub const kCGEventMouseMoved: CGEventType = 5;
pub const kCGEventLeftMouseDragged: CGEventType = 6;
pub const kCGEventRightMouseDragged: CGEventType = 7;
pub const kCGEventKeyDown: CGEventType = 10;
pub const kCGEventOtherMouseDragged: CGEventType = 27;
pub const kCGEventTapDisabledByTimeout: CGEventType = 0xFFFFFFFE;
pub const kCGEventTapDisabledByUserInput: CGEventType = 0xFFFFFFFF;

pub const kCGEventFlagMaskCommand: CGEventFlags = 0x00100000;
pub const kCGEventFlagMaskAlternate: CGEventFlags = 0x00080000;

pub const kCGKeyboardEventKeycode: CGEventField = 9;
pub const kCGMouseEventDeltaX: CGEventField = 4;
pub const kCGMouseEventDeltaY: CGEventField = 5;

pub const kCGHIDEventTap: u32 = 0;
pub const kCGHeadInsertEventTap: u32 = 0;
pub const kCGEventTapOptionDefault: u32 = 0;
pub const kCGEventSourceStateHIDSystemState: CGEventSourceStateID = 1;

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

pub extern "CoreGraphics" fn CGEventTapIsEnabled(
    tap: CFMachPortRef,
) callconv(.c) bool;

pub extern "CoreGraphics" fn CGPreflightPostEventAccess() callconv(.c) bool;
pub extern "CoreGraphics" fn CGRequestPostEventAccess() callconv(.c) bool;

pub extern "CoreGraphics" fn CGPreflightListenEventAccess() callconv(.c) bool;
pub extern "CoreGraphics" fn CGRequestListenEventAccess() callconv(.c) bool;

// IOKit HID access. On macOS 13+ a HID event tap is gated by "Input Monitoring"
// (kIOHIDRequestTypeListenEvent). Modifying events additionally needs
// PostEvent ("Accessibility").
pub const IOHIDRequestType = u32;
pub const kIOHIDRequestTypePostEvent: IOHIDRequestType = 0;
pub const kIOHIDRequestTypeListenEvent: IOHIDRequestType = 1;

pub const IOHIDAccessType = u32;
pub const kIOHIDAccessTypeGranted: IOHIDAccessType = 0;
pub const kIOHIDAccessTypeDenied: IOHIDAccessType = 1;
pub const kIOHIDAccessTypeUnknown: IOHIDAccessType = 2;

pub extern "IOKit" fn IOHIDCheckAccess(
    request_type: IOHIDRequestType,
) callconv(.c) IOHIDAccessType;

pub extern "IOKit" fn IOHIDRequestAccess(
    request_type: IOHIDRequestType,
) callconv(.c) bool;

pub const CFStringRef = *anyopaque;
pub const CFBooleanRef = *anyopaque;
pub const CFDictionaryRef = *anyopaque;
pub const CFDictionaryCallBacks = opaque {};

pub extern "CoreFoundation" var kCFBooleanTrue: CFBooleanRef;
pub extern "CoreFoundation" var kCFTypeDictionaryKeyCallBacks: CFDictionaryCallBacks;
pub extern "CoreFoundation" var kCFTypeDictionaryValueCallBacks: CFDictionaryCallBacks;

pub extern "CoreFoundation" fn CFDictionaryCreate(
    allocator: CFAllocatorRef,
    keys: [*]const *anyopaque,
    values: [*]const *anyopaque,
    num_values: CFIndex,
    key_call_backs: *const CFDictionaryCallBacks,
    value_call_backs: *const CFDictionaryCallBacks,
) callconv(.c) ?CFDictionaryRef;

/// Prompts for the permission System Settings calls "Device Control and Data Access"
/// (kTCCServiceAccessibility). The prompt is asynchronous.
pub extern "ApplicationServices" var kAXTrustedCheckOptionPrompt: CFStringRef;
pub extern "ApplicationServices" fn AXIsProcessTrustedWithOptions(
    options: ?CFDictionaryRef,
) callconv(.c) bool;

pub extern "c" fn system(command: [*:0]const u8) callconv(.c) c_int;

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

pub extern "CoreGraphics" fn CGEventCreate(
    source: CGEventSourceRef,
) callconv(.c) CGEventRef;

pub extern "CoreGraphics" fn CGEventSourceCreate(
    state_id: CGEventSourceStateID,
) callconv(.c) CGEventSourceRef;

pub extern "CoreGraphics" fn CGEventSourceSetLocalEventsSuppressionInterval(
    source: CGEventSourceRef,
    seconds: f64,
) callconv(.c) void;

pub extern "CoreGraphics" fn CGWarpMouseCursorPosition(
    point: CGPoint,
) callconv(.c) CGError;

pub extern "CoreGraphics" fn CGAssociateMouseAndMouseCursorPosition(
    connected: u8,
) callconv(.c) CGError;

pub extern "CoreGraphics" fn CGSetLocalEventsSuppressionInterval(
    seconds: f64,
) callconv(.c) CGError;

pub extern "Carbon" fn GetMBarHeight() callconv(.c) i16;
pub extern "Carbon" fn _HIMenuBarPositionLock() callconv(.c) void;
pub extern "Carbon" fn _HIMenuBarPositionUnlock() callconv(.c) void;

pub extern "SkyLight" fn SLSMainConnectionID() callconv(.c) i32;
pub extern "SkyLight" fn SLSSetMenuBarInsetAndAlpha(cid: i32, top: f64, bottom: f64, alpha: f32) callconv(.c) i32;
pub extern "SkyLight" fn SLSInterruptMenuBarReveal(cid: i32) callconv(.c) i32;

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

pub extern "CoreFoundation" fn CFRunLoopRunInMode(
    mode: CFRunLoopMode,
    seconds: f64,
    return_after_source_handled: bool,
) callconv(.c) i32;

pub extern "CoreFoundation" fn CFRelease(cf: ?*anyopaque) callconv(.c) void;

pub extern "CoreFoundation" var kCFRunLoopDefaultMode: CFRunLoopMode;
