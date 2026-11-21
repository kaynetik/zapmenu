//! Cached display bounds for the per-event clamp. `refresh` and the event tap
//! both run on the main run loop, so no locking.
const c = @import("cg.zig");
const clamp = @import("clamp.zig");

const max_displays = 32;

var rects: [max_displays]clamp.Rect = undefined;
var count: usize = 0;
var single_menu_bar: ?bool = null;

pub fn slice() []const clamp.Rect {
    return rects[0..count];
}

pub fn topAt(x: f64, y: f64) ?f64 {
    return clamp.exposedTop(slice(), x, y);
}

/// True when "Displays have separate Spaces" is off. Read once: the stored value
/// can change mid-session, but macOS only applies it at login.
pub fn singleMenuBar() bool {
    if (single_menu_bar) |v| return v;
    const v = c.CFPreferencesGetAppBooleanValue(
        c.__CFStringMakeConstantString("spans-displays"),
        c.__CFStringMakeConstantString("com.apple.spaces"),
        null,
    ) != 0;
    single_menu_bar = v;
    return v;
}

/// Keeps the previous list if CoreGraphics fails.
pub fn refresh() usize {
    var ids: [max_displays]c.CGDirectDisplayID = undefined;
    var n: u32 = 0;
    if (c.CGGetActiveDisplayList(max_displays, &ids, &n) != 0) return count;
    count = @min(n, max_displays);
    const main_id = c.CGMainDisplayID();
    const every_display_has_bar = !singleMenuBar();
    for (ids[0..count], rects[0..count]) |id, *r| {
        const b = c.CGDisplayBounds(id);
        r.* = .{
            .x = b.origin.x,
            .y = b.origin.y,
            .w = b.size.width,
            .h = b.size.height,
            .menu_bar = every_display_has_bar or id == main_id,
        };
    }
    return count;
}
