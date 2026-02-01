const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const image = @import("image.zig");
const ui = @import("ui");
const Window = ui.Window;
const Texture = ui.Texture;
const Event = ui.Event;

const background: ui.Color = .{ .r = 0x18, .g = 0x18, .b = 0x18, .a = 0xFF };

const State = struct {
    gpa: Allocator,
    w: *Window = undefined,
    texture: ?Texture = undefined,

    fn start(state: *State) !void {
        state.w = try Window.init(state.gpa, 800, 640, "Dithertool", .{
            .error_callback = ErrorCallback,
            .event_capabilities = .{ .Key = true, .Drop = true },
        });
        defer state.w.deinit();

        try state.UpdateTexture("tm.png");
        defer state.texture.?.deinit();

        while (!state.w.ShouldClose()) {
            state.w.Clear(background);

            while (state.w.events.popFront()) |e| {
                defer e.deinit();
                switch (e) {
                    .Drop => |drop| {
                        try state.UpdateTexture(drop.paths.items[0]);
                    },
                    .Key => |key| {
                        if (key.key == .Q) return;
                    },
                    else => {},
                }
            }

            if (state.texture) |texture| {
                const tw: f32 = @floatFromInt(texture.width);
                const th: f32 = @floatFromInt(texture.height);
                const ww: f32 = @floatFromInt(state.w.width);
                const wh: f32 = @floatFromInt(state.w.height);
                const maxw = @min(ww, tw);
                const maxh = @min(wh, th);
                const hspacing = (ww - maxw) / 2;
                const vspacing = (wh - maxh) / 2;
                const hmod = if (tw >= ww and tw < th) ((tw / th) * ww) else 0;
                const vmod = if (th >= wh and th < tw) ((th / tw) * wh) else 0;

                state.w.DrawTexture2D(texture, null, .{
                    .x = hspacing + hmod,
                    .y = vspacing + vmod,
                    .w = ww - hspacing - hmod,
                    .h = wh - vspacing - vmod,
                });
            }

            state.w.SwapBuffers();
        }
    }

    fn UpdateTexture(state: *State, path: []const u8) !void {
        var img = image.load(state.gpa, path) catch |e| {
            std.log.info("{s}", .{image.failure_reason()});
            return e;
        };
        defer img.deinit(state.gpa);

        const texture = Texture.init(@intCast(img.width), @intCast(img.height), img.data);
        var old: ?Texture = state.texture;
        state.texture = texture;

        if (old) |*ot| {
            ot.deinit();
        }

        std.log.info("Got here: {s}!", .{path});
    }

    fn ErrorCallback(error_code: c_int, description: [*c]const u8) callconv(.c) void {
        std.log.err("Error ({d}): {s}\n", .{ error_code, std.mem.span(description) });
    }
};

pub fn main(init: std.process.Init) !void {
    var state: State = .{ .gpa = init.gpa };
    try state.start();
}
