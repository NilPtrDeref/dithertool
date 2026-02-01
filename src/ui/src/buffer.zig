const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const Usage = enum(u32) {
    StreamDraw = glfw.GL_STREAM_DRAW,
    StreamRead = glfw.GL_STREAM_READ,
    StreamCopy = glfw.GL_STREAM_COPY,
    StaticDraw = glfw.GL_STATIC_DRAW,
    StaticRead = glfw.GL_STATIC_READ,
    StaticCopy = glfw.GL_STATIC_COPY,
    DynamicDraw = glfw.GL_DYNAMIC_DRAW,
    DynamicRead = glfw.GL_DYNAMIC_READ,
    DynamicCopy = glfw.GL_DYNAMIC_COPY,
};

pub const VertexBufferOptions = struct {
    data: []const f32,
    usage: Usage = .StaticDraw,
};

pub const ElementBufferOptions = struct {
    data: []const u32,
    usage: Usage = .StaticDraw,
};

// TODO: Add error checking all the way down.
pub const Array = struct {
    vao: u32,
    vbo: VertexBuffer,
    ebo: ?ElementBuffer,

    pub fn init(vertices: VertexBufferOptions, indices: ?ElementBufferOptions) Array {
        var vao: u32 = 0;

        gl.GenVertexArrays(1, @ptrCast(&vao));
        gl.BindVertexArray(vao);
        defer gl.BindVertexArray(0);

        const vbo = VertexBuffer.init(vertices);
        const ebo = if (indices) |i|
            ElementBuffer.init(i)
        else
            null;

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
        };
    }

    pub fn deinit(vao: Array) void {
        vao.vbo.deinit();
        if (vao.ebo) |ebo| {
            ebo.deinit();
        }
        gl.DeleteVertexArrays(1, @ptrCast(&vao.vao));
    }

    pub fn bind(vao: Array) void {
        gl.BindVertexArray(vao.vao);
    }

    pub fn unbind(_: Array) void {
        gl.BindVertexArray(0);
    }
};

pub const VertexBuffer = struct {
    vbo: u32,
    len: usize,

    pub fn init(options: VertexBufferOptions) VertexBuffer {
        var vbo: u32 = 0;

        gl.GenBuffers(1, @ptrCast(&vbo));
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, vbo);
        gl.BufferData(glfw.GL_ARRAY_BUFFER, @intCast(@sizeOf(f32) * options.data.len), options.data.ptr, @intFromEnum(options.usage));

        return .{ .vbo = vbo, .len = options.data.len };
    }

    pub fn deinit(vbo: VertexBuffer) void {
        gl.DeleteBuffers(1, @ptrCast(&vbo.vbo));
    }

    pub fn bind(vbo: VertexBuffer) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, vbo.vbo);
    }

    pub fn unbind(_: VertexBuffer) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, 0);
    }

    pub fn attrib_ptr(vbo: VertexBuffer, index: u32, size: i32, stride: i32, offset: u32) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, vbo.vbo);
        gl.VertexAttribPointer(index, size, glfw.GL_FLOAT, glfw.GL_FALSE, stride, offset);
        gl.EnableVertexAttribArray(index);
    }

    pub fn enable_attrib(vbo: VertexBuffer, index: u32) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, vbo.vbo);
        gl.EnableVertexAttribArray(index);
    }

    pub fn disable_attrib(vbo: VertexBuffer, index: u32) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, vbo.vbo);
        gl.DisableVertexAttribArray(index);
    }
};

pub const ElementBuffer = struct {
    ebo: u32,
    len: usize,

    pub fn init(options: ElementBufferOptions) ElementBuffer {
        var ebo: u32 = 0;

        gl.GenBuffers(1, @ptrCast(&ebo));
        gl.BindBuffer(glfw.GL_ELEMENT_ARRAY_BUFFER, ebo);
        gl.BufferData(glfw.GL_ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * options.data.len), options.data.ptr, @intFromEnum(options.usage));

        return .{ .ebo = ebo, .len = options.data.len };
    }

    pub fn deinit(ebo: ElementBuffer) void {
        gl.DeleteBuffers(1, @ptrCast(&ebo.ebo));
    }

    pub fn bind(ebo: ElementBuffer) void {
        gl.BindBuffer(glfw.GL_ELEMENT_ARRAY_BUFFER, ebo.ebo);
    }

    pub fn unbind(_: ElementBuffer) void {
        gl.BindBuffer(glfw.GL_ELEMENT_ARRAY_BUFFER, 0);
    }
};
