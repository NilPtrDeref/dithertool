const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const InitialTexture: u32 = glfw.GL_TEXTURE0;
var CurrentTexture: u32 = glfw.GL_TEXTURE0;
const MaxTextures: u32 = glfw.GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS;

const Texture = @This();
tid: u32,
tunit: u32,

pub fn init(width: i32, height: i32, data: []const u8) Texture {
    var tid: u32 = undefined;
    gl.GenTextures(1, @ptrCast(&tid));
    gl.ActiveTexture(CurrentTexture);
    gl.BindTexture(glfw.GL_TEXTURE_2D, tid);
    gl.TexImage2D(glfw.GL_TEXTURE_2D, 0, glfw.GL_RGBA, width, height, 0, glfw.GL_RGBA, glfw.GL_UNSIGNED_BYTE, data.ptr);

    const texture: Texture = .{
        .tid = tid,
        .tunit = CurrentTexture,
    };
    CurrentTexture += 1;

    return texture;
}

pub fn deinit(texture: Texture) void {
    gl.DeleteTextures(1, @ptrCast(&texture.tid));
}
