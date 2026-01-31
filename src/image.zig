const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const stbi = @cImport({
    @cInclude("stb_image.h");
});

const Image = @This();
width: u32 = 0,
height: u32 = 0,
bpp: u32 = 0,
data: []u8 = undefined,

pub fn load(gpa: Allocator, path: []const u8) !*Image {
    var image = try gpa.create(Image);
    errdefer gpa.destroy(image);
    image.* = .{};

    const cstr = try gpa.dupeZ(u8, path);
    defer gpa.free(cstr);

    // Per STB Documentation
    //     N=#comp     components
    //       1           grey
    //       2           grey, alpha
    //       3           red, green, blue
    //       4           red, green, blue, alpha
    const data = stbi.stbi_load(cstr, @ptrCast(&image.width), @ptrCast(&image.height), @ptrCast(&image.bpp), 4);
    if (data == null) return error.InvalidImage;

    image.data = std.mem.span(data);
    return image;
}

pub fn failure_reason() []const u8 {
    return std.mem.span(stbi.stbi_failure_reason());
}

pub fn deinit(image: *Image, gpa: Allocator) void {
    stbi.stbi_image_free(image.data.ptr);
    gpa.destroy(image);
}
