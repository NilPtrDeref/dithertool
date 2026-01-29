const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
pub const png = @import("png.zig");

const Image = @This();
width: u32,
height: u32,
/// Stride represents the size of the pixel values, there are only a few supported values:
/// 1: Greyscale
/// 2: Greyscale w/ Alpha
/// 3: RGB
/// 4: RGBA
stride: u8,
data: []u8,

pub fn load(gpa: Allocator, io: Io, path: []const u8) !*Image {
    var file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var buf: [1024]u8 = undefined;
    var reader = file.reader(io, &buf);

    return switch (try reader.interface.peekInt(u64, .big)) {
        png.PngSignature => try Image.png.parse(gpa, &reader.interface),
        else => return error.UnsupportedImageType,
    };
}

pub fn deinit(image: *Image, gpa: Allocator) void {
    gpa.free(image.data);
    gpa.destroy(image);
}
