pub const Window = @import("window.zig");
pub const Texture = @import("texture.zig");
pub const Event = @import("event.zig").Event;
pub const Shader = @import("shader.zig");

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};
