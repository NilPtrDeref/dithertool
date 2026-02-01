const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const Program = struct {
    pid: u32 = 0,

    pub fn init(vertex: Shader, fragment: Shader) !Program {
        var program: Program = .{};
        program.pid = gl.CreateProgram();
        gl.AttachShader(program.pid, vertex.sid);
        gl.AttachShader(program.pid, fragment.sid);
        gl.LinkProgram(program.pid);

        var success: i32 = undefined;
        gl.GetProgramiv(program.pid, glfw.GL_LINK_STATUS, @ptrCast(&success));
        if (success != 1) {
            var log: [512]u8 = undefined;
            var loglen: u32 = undefined;
            gl.GetProgramInfoLog(program.pid, 512, @ptrCast(&loglen), &log);
            std.log.err("Program Linking Error :: {s}\n", .{log[0..loglen]});
            return error.ProgramLinkingError;
        }

        return program;
    }

    pub fn deinit(program: Program) void {
        gl.DeleteProgram(program.pid);
    }

    pub fn use(program: Program) void {
        gl.UseProgram(program.pid);
    }

    pub fn Uniform1f(program: Program, name: [*c]const u8, v1: f32) void {
        program.use();
        gl.Uniform1f(gl.GetUniformLocation(program.pid, name), v1);
    }

    pub fn Uniform2f(program: Program, name: [*c]const u8, v1: f32, v2: f32) void {
        program.use();
        gl.Uniform2f(gl.GetUniformLocation(program.pid, name), v1, v2);
    }

    pub fn Uniform3f(program: Program, name: [*c]const u8, v1: f32, v2: f32, v3: f32) void {
        program.use();
        gl.Uniform3f(gl.GetUniformLocation(program.pid, name), v1, v2, v3);
    }

    pub fn Uniform4f(program: Program, name: [*c]const u8, v1: f32, v2: f32, v3: f32, v4: f32) void {
        program.use();
        gl.Uniform4f(gl.GetUniformLocation(program.pid, name), v1, v2, v3, v4);
    }

    pub fn Uniform1i(program: Program, name: [*c]const u8, v1: i32) void {
        program.use();
        gl.Uniform1i(gl.GetUniformLocation(program.pid, name), v1);
    }

    pub fn Uniform2i(program: Program, name: [*c]const u8, v1: i32, v2: i32) void {
        program.use();
        gl.Uniform2i(gl.GetUniformLocation(program.pid, name), v1, v2);
    }

    pub fn Uniform3i(program: Program, name: [*c]const u8, v1: i32, v2: i32, v3: i32) void {
        program.use();
        gl.Uniform3i(gl.GetUniformLocation(program.pid, name), v1, v2, v3);
    }

    pub fn Uniform4i(program: Program, name: [*c]const u8, v1: i32, v2: i32, v3: i32, v4: i32) void {
        program.use();
        gl.Uniform4i(gl.GetUniformLocation(program.pid, name), v1, v2, v3, v4);
    }

    pub fn Uniform1u(program: Program, name: [*c]const u8, v1: u32) void {
        program.use();
        gl.Uniform1u(gl.GetUniformLocation(program.pid, name), v1);
    }

    pub fn Uniform2u(program: Program, name: [*c]const u8, v1: u32, v2: u32) void {
        program.use();
        gl.Uniform2u(gl.GetUniformLocation(program.pid, name), v1, v2);
    }

    pub fn Uniform3u(program: Program, name: [*c]const u8, v1: u32, v2: u32, v3: u32) void {
        program.use();
        gl.Uniform3u(gl.GetUniformLocation(program.pid, name), v1, v2, v3);
    }

    pub fn Uniform4u(program: Program, name: [*c]const u8, v1: u32, v2: u32, v3: u32, v4: u32) void {
        program.use();
        gl.Uniform4u(gl.GetUniformLocation(program.pid, name), v1, v2, v3, v4);
    }
};

pub const Shader = struct {
    sid: u32 = 0,

    const ShaderType = enum(u32) {
        Vertex = glfw.GL_VERTEX_SHADER,
        Geometry = glfw.GL_GEOMETRY_SHADER,
        Fragment = glfw.GL_FRAGMENT_SHADER,
    };

    pub fn init(T: ShaderType, source: []const u8) !Shader {
        var shader: Shader = .{};
        shader.sid = gl.CreateShader(@intFromEnum(T));
        gl.ShaderSource(shader.sid, 1, @ptrCast(&source.ptr), @ptrCast(&source.len));
        gl.CompileShader(shader.sid);

        var success: i32 = undefined;
        gl.GetShaderiv(shader.sid, glfw.GL_COMPILE_STATUS, @ptrCast(&success));
        if (success != 1) {
            var log: [512]u8 = undefined;
            var loglen: u32 = undefined;
            gl.GetShaderInfoLog(shader.sid, 512, @ptrCast(&loglen), &log);
            std.log.err("Shader Compilation Error :: {s}\n", .{log[0..loglen]});
            return error.ShaderCompilationError;
        }

        return shader;
    }

    pub fn deinit(shader: Shader) void {
        gl.DeleteShader(shader.sid);
    }
};
