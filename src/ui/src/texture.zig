const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const InitialTexture: u32 = glfw.GL_TEXTURE0;
var CurrentTexture: u32 = glfw.GL_TEXTURE0;
const MaxTextures: u32 = glfw.GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS;

const Texture = @This();
tid: u32 = 0,
tunit: u32,
width: u32,
height: u32,

// TODO: Take in options struct for things like texture type, TexParameter, etc.
pub fn init(width: i32, height: i32, data: []const u8) Texture {
    var texture: Texture = .{ .tunit = CurrentTexture, .width = @intCast(width), .height = @intCast(height) };
    CurrentTexture += 1;

    gl.GenTextures(1, @ptrCast(&texture.tid));
    gl.ActiveTexture(texture.tunit);
    gl.BindTexture(glfw.GL_TEXTURE_2D, texture.tid);

    // TODO: Determine if wrap needs to be set
    // gl.TexParameteri(glfw.GL_TEXTURE_2D, glfw.GL_TEXTURE_WRAP_S, glfw.GL_REPEAT);

    // gl.TexParameteri(glfw.GL_TEXTURE_2D, glfw.GL_TEXTURE_MIN_FILTER, glfw.GL_LINEAR);
    // gl.TexParameteri(glfw.GL_TEXTURE_2D, glfw.GL_TEXTURE_MAG_FILTER, glfw.GL_LINEAR);
    gl.TexParameteri(glfw.GL_TEXTURE_2D, glfw.GL_TEXTURE_MIN_FILTER, glfw.GL_NEAREST);
    gl.TexParameteri(glfw.GL_TEXTURE_2D, glfw.GL_TEXTURE_MAG_FILTER, glfw.GL_NEAREST);

    gl.PixelStorei(glfw.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(glfw.GL_TEXTURE_2D, 0, glfw.GL_RGBA, width, height, 0, glfw.GL_RGBA, glfw.GL_UNSIGNED_BYTE, data.ptr);
    gl.GenerateMipmap(glfw.GL_TEXTURE_2D);

    return texture;
}

pub fn deinit(texture: Texture) void {
    gl.DeleteTextures(1, @ptrCast(&texture.tid));
}

pub fn index(texture: Texture) u32 {
    return texture.tunit - InitialTexture;
}

pub fn set_active(texture: Texture) void {
    gl.ActiveTexture(texture.tunit);
}

pub fn bind(texture: Texture) void {
    gl.BindTexture(glfw.GL_TEXTURE_2D, texture.tid);
}
