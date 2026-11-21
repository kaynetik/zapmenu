//! Cache of active display bounds, so the per-event clamp does not call into
//! CoreGraphics. Both `refresh` callers (startup and the reconfiguration
//! callback) and the event tap run on the main run loop thread, so the cache
//! needs no locking.
const c = @import("cg.zig");
const clamp = @import("clamp.zig");

const max_displays = 32;

var rects: [max_displays]clamp.Rect = undefined;
var count: usize = 0;
var single_menu_bar: ?bool = null;

pub fn slice() []const clamp.Rect {
    return rects[0..count];
}

/// Top edge to clamp against at (x, y); see `clamp.exposedTop`.
pub fn topAt(x: f64, y: f64) ?f64 {
    return clamp.exposedTop(slice(), x, y);
}

/// True when "Displays have separate Spaces" is off, so only the main display
/// has a menu bar. The setting only takes effect at login, so it is read once:
/// the stored value can change mid-session while the behaviour does not.
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

/// Re-read the active displays. Keeps the previous list if CoreGraphics fails.
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
