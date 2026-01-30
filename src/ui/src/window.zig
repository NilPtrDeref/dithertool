const std = @import("std");
const root = @import("root.zig");
const Color = root.Color;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const buffer = @import("buffer.zig");
const Array = buffer.Array;
const Buffer = buffer.Buffer;
const shader = @import("shader.zig");
const Program = shader.Program;
const Texture = @import("texture.zig");
const event = @import("event.zig");
const Event = event.Event;
const EventQueue = event.EventQueue;

const TEXTURE_VERTEX_SOURCE = @embedFile("shaders/texture.vert");
const TEXTURE_FRAGMENT_SOURCE = @embedFile("shaders/texture.frag");

// ErrorFun Has to stay callconv(.c) because it doesn't pass a reference to the window in order to wrap it properly
pub const ErrorFun = *const fn (error_code: c_int, description: [*c]const u8) callconv(.c) void;

pub const InitOptions = struct {
    error_callback: ?ErrorFun = null,
};

const Window = @This();
gpa: Allocator,
window: *glfw.GLFWwindow,
procs: gl.ProcTable,
events: EventQueue,
window_size_events: bool,

texture_array: *Array,
texture_buffer: Buffer,
texture_program: Program,

/// It is undefined behavior to create more that a single Window.
pub fn init(gpa: Allocator, width: comptime_int, height: comptime_int, title: [:0]const u8, options: InitOptions) !*Window {
    _ = glfw.glfwSetErrorCallback(options.error_callback);

    var window = try gpa.create(Window);
    errdefer gpa.destroy(window);
    window.gpa = gpa;
    window.events = EventQueue.init(gpa, {});
    window.window_size_events = false;

    if (glfw.glfwInit() != glfw.GLFW_TRUE) return error.GlfwInitError;
    errdefer glfw.glfwTerminate();
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    window.window = glfw.glfwCreateWindow(width, height, title, null, null) orelse {
        return error.WindowCreationFailure;
    };
    glfw.glfwMakeContextCurrent(window.window);
    glfw.glfwSwapInterval(1);
    glfw.glfwSetWindowUserPointer(window.window, window);
    _ = glfw.glfwSetWindowSizeCallback(window.window, WindowSizeCallback);

    // Initialize the procedure table.
    if (!window.procs.init(glfw.glfwGetProcAddress)) return error.InitFailed;

    // Make the procedure table current on the calling thread.
    gl.makeProcTableCurrent(&window.procs);
    gl.Viewport(0, 0, width, height);

    // Set up VertexArray and VertexBuffer for drawing textures.
    window.texture_array = try Array.init(gpa);
    window.texture_buffer = try window.texture_array.buffer();
    window.texture_buffer.set(&.{
        -1.0, 1.0,  0.0, 1.0,
        -1.0, -1.0, 0.0, 0.0,
        1.0,  -1.0, 1.0, 0.0,
        -1.0, 1.0,  0.0, 1.0,
        1.0,  -1.0, 1.0, 0.0,
        1.0,  1.0,  1.0, 1.0,
    }, .StaticDraw);
    window.texture_buffer.attrib_ptr(0, 2, 4 * @sizeOf(f32), 0);
    window.texture_buffer.attrib_ptr(1, 2, 4 * @sizeOf(f32), 2 * @sizeOf(f32));
    Buffer.unbind();

    var tvp = try shader.Shader.init(.Vertex, std.mem.span(@as([*c]const u8, @ptrCast(TEXTURE_VERTEX_SOURCE))));
    defer tvp.deinit();
    var tfp = try shader.Shader.init(.Fragment, std.mem.span(@as([*c]const u8, @ptrCast(TEXTURE_FRAGMENT_SOURCE))));
    defer tfp.deinit();

    window.texture_program = try Program.init(tvp, tfp);

    return window;
}

pub fn deinit(window: *Window) void {
    window.events.deinit();
    window.texture_program.deinit();
    window.texture_array.deinit();
    gl.makeProcTableCurrent(null);
    glfw.glfwDestroyWindow(window.window);
    glfw.glfwTerminate();
    window.gpa.destroy(window);
}

pub fn ShouldClose(window: *Window) bool {
    return glfw.glfwWindowShouldClose(window.window) == glfw.GLFW_TRUE;
}

pub fn SetUserData(window: *Window, userdata: *anyopaque) void {
    window.userdata = userdata;
}

pub fn Clear(_: *Window, color: Color) void {
    gl.ClearColor(color.r / 255.0, color.g / 255.0, color.b / 255.0, color.a / 255.0);
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn SwapBuffers(window: *Window) void {
    glfw.glfwSwapBuffers(window.window);
    glfw.glfwPollEvents();
}

// FIXME: Expand to take src/dest rectangles.
pub fn DrawTexture(window: Window, texture: Texture) void {
    window.texture_program.use();
    window.texture_buffer.bind();
    texture.set_active();
    texture.bind();

    // TODO: Move into program?
    gl.Uniform1i(gl.GetUniformLocation(window.texture_program.pid, "uTexture"), @intCast(texture.tunit - Texture.InitialTexture));

    // TODO: Move into Array?
    gl.BindVertexArray(window.texture_array.vao);

    gl.DrawArrays(glfw.GL_TRIANGLES, 0, 6);
}

pub fn SetErrorCallback(_: *Window, function: ?ErrorFun) void {
    _ = glfw.glfwSetErrorCallback(function);
}

pub fn WindowPosEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowPosCallback(window.window, WindowPosCallback);
    } else {
        _ = glfw.glfwSetWindowPosCallback(window.window, null);
    }
}

fn WindowPosCallback(w: ?*glfw.GLFWwindow, xpos: c_int, ypos: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowPos = .{ .xpos = @intCast(xpos), .ypos = @intCast(ypos) } }) catch {};
}

pub fn WindowSizeEvents(window: *Window, enable: bool) void {
    window.window_size_events = enable;
}

fn WindowSizeCallback(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    // TODO: Decide if this is the user's responsibility
    gl.Viewport(0, 0, width, height);

    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.window_size_events) {
        window.events.add(.{ .WindowSize = .{ .width = @intCast(width), .height = @intCast(height) } }) catch {};
    }
}

pub fn WindowCloseEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowCloseCallback(window.window, WindowCloseCallback);
    } else {
        _ = glfw.glfwSetWindowCloseCallback(window.window, null);
    }
}

fn WindowCloseCallback(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowClose = {} }) catch {};
}

pub fn WindowRefreshEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowRefreshCallback(window.window, WindowRefreshCallback);
    } else {
        _ = glfw.glfwSetWindowRefreshCallback(window.window, null);
    }
}

fn WindowRefreshCallback(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowRefresh = {} }) catch {};
}

pub fn WindowFocusEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowFocusCallback(window.window, WindowFocusCallback);
    } else {
        _ = glfw.glfwSetWindowFocusCallback(window.window, null);
    }
}

fn WindowFocusCallback(w: ?*glfw.GLFWwindow, focused: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowFocus = .{ .focused = focused == glfw.GLFW_TRUE } }) catch {};
}

pub fn WindowIconifyEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowIconifyCallback(window.window, WindowIconifyCallback);
    } else {
        _ = glfw.glfwSetWindowIconifyCallback(window.window, null);
    }
}

fn WindowIconifyCallback(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowIconify = .{ .iconified = iconified == glfw.GLFW_TRUE } }) catch {};
}

pub fn WindowMaximizeEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowMaximizeCallback(window.window, WindowMaximizeCallback);
    } else {
        _ = glfw.glfwSetWindowMaximizeCallback(window.window, null);
    }
}

fn WindowMaximizeCallback(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowMaximize = .{ .iconified = iconified == glfw.GLFW_TRUE } }) catch {};
}

pub fn FramebufferSizeEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetFramebufferSizeCallback(window.window, FramebufferSizeCallback);
    } else {
        _ = glfw.glfwSetFramebufferSizeCallback(window.window, null);
    }
}

fn FramebufferSizeCallback(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .FramebufferSize = .{ .width = @intCast(width), .height = @intCast(height) } }) catch {};
}

pub fn WindowContentScaleEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetWindowContentScaleCallback(window.window, WindowContentScaleCallback);
    } else {
        _ = glfw.glfwSetWindowContentScaleCallback(window.window, null);
    }
}

fn WindowContentScaleCallback(w: ?*glfw.GLFWwindow, xscale: f32, yscale: f32) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .WindowContentScale = .{ .xscale = xscale, .yscale = yscale } }) catch {};
}

pub fn MouseButtonEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetMouseButtonCallback(window.window, MouseButtonCallback);
    } else {
        _ = glfw.glfwSetMouseButtonCallback(window.window, null);
    }
}

fn MouseButtonCallback(w: ?*glfw.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .MouseButton = .{
        .button = @enumFromInt(button),
        .action = @enumFromInt(action),
        .mods = @bitCast(@as(u32, @intCast(mods))),
    } }) catch {};
}

pub fn CursorPosEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetCursorPosCallback(window.window, CursorPosCallback);
    } else {
        _ = glfw.glfwSetCursorPosCallback(window.window, null);
    }
}

fn CursorPosCallback(w: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .CursorPos = .{ .xpos = xpos, .ypos = ypos } }) catch {};
}

pub fn CursorEnterEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetCursorEnterCallback(window.window, CursorEnterCallback);
    } else {
        _ = glfw.glfwSetCursorEnterCallback(window.window, null);
    }
}

fn CursorEnterCallback(w: ?*glfw.GLFWwindow, entered: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .CursorEnter = .{ .entered = entered == glfw.GLFW_TRUE } }) catch {};
}

pub fn ScrollEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetScrollCallback(window.window, ScrollCallback);
    } else {
        _ = glfw.glfwSetScrollCallback(window.window, null);
    }
}

fn ScrollCallback(w: ?*glfw.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .Scroll = .{ .xoffset = xoffset, .yoffset = yoffset } }) catch {};
}

pub fn KeyCallbackEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetKeyCallback(window.window, KeyCallback);
    } else {
        _ = glfw.glfwSetKeyCallback(window.window, null);
    }
}

fn KeyCallback(w: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .Key = .{
        .key = @enumFromInt(key),
        .scancode = @intCast(scancode),
        .action = @enumFromInt(action),
        .mods = @bitCast(@as(u32, @intCast(mods))),
    } }) catch {};
}

pub fn CharCallbackEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetCharCallback(window.window, CharCallback);
    } else {
        _ = glfw.glfwSetCharCallback(window.window, null);
    }
}

fn CharCallback(w: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .Char = .{ .codepoint = @intCast(codepoint) } }) catch {};
}

pub fn CharmodsCallbackEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetCharModsCallback(window.window, CharmodsCallback);
    } else {
        _ = glfw.glfwSetCharModsCallback(window.window, null);
    }
}

fn CharmodsCallback(w: ?*glfw.GLFWwindow, codepoint: c_uint, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.add(.{ .Charmods = .{ .codepoint = @intCast(codepoint), .mods = @bitCast(@as(u32, @intCast(mods))) } }) catch {};
}

pub fn DropCallbackEvents(window: *Window, enable: bool) void {
    if (enable) {
        _ = glfw.glfwSetDropCallback(window.window, DropCallback);
    } else {
        _ = glfw.glfwSetDropCallback(window.window, null);
    }
}

fn DropCallback(w: ?*glfw.GLFWwindow, path_count: c_int, paths: [*c][*c]const u8) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    var list: ArrayList([]const u8) = .empty;
    for (0..@intCast(path_count)) |i| {
        const dupe = window.gpa.dupe(u8, std.mem.span(paths[i])) catch continue;
        list.append(window.gpa, dupe) catch {
            window.gpa.free(dupe);
            continue;
        };
    }
    var e: Event = .{ .Drop = .{ .window = window, .paths = list } };
    window.events.add(e) catch {
        e.deinit();
    };
}
