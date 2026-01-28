const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const Array = struct {
    gpa: Allocator,
    vao: u32 = 0,
    buffers: std.ArrayList(Buffer),

    pub fn init(gpa: Allocator) !*Array {
        var arr = try gpa.create(Array);
        arr.gpa = gpa;
        arr.buffers = .empty;

        gl.GenVertexArrays(1, @ptrCast(&arr.vao));

        return arr;
    }

    pub fn deinit(arr: *Array) void {
        for (arr.buffers.items) |buf| {
            gl.DeleteBuffers(1, @ptrCast(&buf.vbo));
        }
        arr.buffers.deinit(arr.gpa);

        gl.DeleteVertexArrays(1, @ptrCast(&arr.vao));
        arr.gpa.destroy(arr);
    }

    pub fn buffer(arr: *Array) !Buffer {
        var buf: Buffer = .{ .vao = arr.vao };
        gl.GenBuffers(1, @ptrCast(&buf.vbo));
        gl.BindVertexArray(arr.vao);
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, buf.vbo);

        try arr.buffers.append(arr.gpa, buf);

        return buf;
    }
};

// TODO: Track max size to realloc buffer on update > max
pub const Buffer = struct {
    vao: u32,
    vbo: u32 = 0,

    const Usage = enum(u32) {
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

    pub fn set(buf: Buffer, data: []const f32, usage: Usage) void {
        gl.BindVertexArray(buf.vao);
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, buf.vbo);
        gl.BufferData(glfw.GL_ARRAY_BUFFER, @intCast(@sizeOf(f32) * data.len), data.ptr, @intFromEnum(usage));
    }

    // TODO: Implement
    pub fn update(buf: Buffer, data: []f32, offset: u32) void {
        _ = .{ buf, data, offset };
        unreachable;
    }

    pub fn bind(buf: Buffer) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, buf.vbo);
    }

    pub fn unbind() void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, 0);
    }

    pub fn attrib_ptr(buf: Buffer, index: u32, size: i32, stride: i32, offset: u32) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, buf.vbo);
        gl.VertexAttribPointer(index, size, glfw.GL_FLOAT, glfw.GL_FALSE, stride, offset);
        gl.EnableVertexAttribArray(index);
    }

    pub fn enable_attrib(buf: Buffer, index: u32) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, buf.vbo);
        gl.EnableVertexAttribArray(index);
    }

    pub fn disable_attrib(buf: Buffer, index: u32) void {
        gl.BindBuffer(glfw.GL_ARRAY_BUFFER, buf.vbo);
        gl.DisableVertexAttribArray(index);
    }
};
