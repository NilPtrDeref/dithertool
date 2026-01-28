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
};

pub const Shader = struct {
    sid: u32 = 0,

    const ShaderType = enum(u32) {
        Vertex = glfw.GL_VERTEX_SHADER,
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
