const std = @import("std");
const root = @import("root.zig");
const Color = root.Color;
const Rect = root.Rect;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const gl = @import("gl");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const buffer = @import("buffer.zig");
const Array = buffer.Array;
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
    event_capacity: u32 = 1024,
    event_capabilities: ?EventCapabilities = null,
};

const Window = @This();
gpa: Allocator,
window: *glfw.GLFWwindow,
procs: gl.ProcTable,
events: EventQueue,
window_size_events: bool,

width: u32,
height: u32,

texture_array: Array,
texture_program: Program,

/// It is undefined behavior to create more that a single Window.
pub fn init(gpa: Allocator, width: comptime_int, height: comptime_int, title: [:0]const u8, options: InitOptions) !*Window {
    _ = glfw.glfwSetErrorCallback(options.error_callback);

    var window = try gpa.create(Window);
    errdefer gpa.destroy(window);
    window.gpa = gpa;
    window.width = width;
    window.height = height;
    window.events = .empty;
    try window.events.ensureTotalCapacity(gpa, options.event_capacity);
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
    if (options.event_capabilities != null) {
        window.SetEventCapabilities(options.event_capabilities.?);
    }

    // Initialize the procedure table.
    if (!window.procs.init(glfw.glfwGetProcAddress)) return error.InitFailed;

    // Make the procedure table current on the calling thread.
    gl.makeProcTableCurrent(&window.procs);
    gl.Viewport(0, 0, width, height);

    // Set up VertexArray and VertexBuffer for drawing textures.
    window.texture_array = Array.init(.{
        .data = &.{
            -1.0, -1.0, 0.0, 1.0,
            -1.0, 1.0,  0.0, 0.0,
            1.0,  -1.0, 1.0, 1.0,
            1.0,  1.0,  1.0, 0.0,
        },
    }, null);

    window.texture_array.bind();
    window.texture_array.vbo.attrib_ptr(0, 2, 4 * @sizeOf(f32), 0);
    window.texture_array.vbo.attrib_ptr(1, 2, 4 * @sizeOf(f32), 2 * @sizeOf(f32));
    window.texture_array.unbind();

    var tvp = try shader.Shader.init(.Vertex, std.mem.span(@as([*c]const u8, @ptrCast(TEXTURE_VERTEX_SOURCE))));
    defer tvp.deinit();
    var tfp = try shader.Shader.init(.Fragment, std.mem.span(@as([*c]const u8, @ptrCast(TEXTURE_FRAGMENT_SOURCE))));
    defer tfp.deinit();

    window.texture_program = try Program.init(tvp, tfp);

    return window;
}

pub fn deinit(window: *Window) void {
    window.events.deinit(window.gpa);
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
pub fn DrawTexture(window: Window, texture: Texture, src: Rect, dest: Rect) void {
    window.texture_program.use();
    window.texture_array.bind();
    defer window.texture_array.unbind();
    texture.set_active();
    texture.bind();

    // TODO: Move into program?
    gl.Uniform1i(gl.GetUniformLocation(window.texture_program.pid, "uTexture"), @intCast(texture.tunit - Texture.InitialTexture));

    // TODO: Decide if the buffer needs to be altered or if I can pass transforms to accomplish this.
    _ = .{ src, dest };
    // gl.Uniform4f(
    //     gl.GetUniformLocation(window.texture_program.pid, "sTransform"),
    // );
    // gl.Uniform4f(
    //     gl.GetUniformLocation(window.texture_program.pid, "dTransform"),
    // );

    gl.DrawArrays(glfw.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn SetErrorCallback(_: *Window, function: ?ErrorFun) void {
    _ = glfw.glfwSetErrorCallback(function);
}

pub const EventCapabilities = struct {
    WindowPos: ?bool = null,
    WindowSize: ?bool = null,
    WindowClose: ?bool = null,
    WindowRefresh: ?bool = null,
    WindowFocus: ?bool = null,
    WindowIconify: ?bool = null,
    WindowMaximize: ?bool = null,
    FrambufferSize: ?bool = null,
    WindowContentScale: ?bool = null,
    MouseButton: ?bool = null,
    CursorPos: ?bool = null,
    CursorEnter: ?bool = null,
    Scroll: ?bool = null,
    Key: ?bool = null,
    Char: ?bool = null,
    CharMods: ?bool = null,
    Drop: ?bool = null,
};

pub fn SetEventCapabilities(window: *Window, events: EventCapabilities) void {
    if (events.WindowPos) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowPosCallback(window.window, WindowPosCallback);
        } else {
            _ = glfw.glfwSetWindowPosCallback(window.window, null);
        }
    }

    if (events.WindowSize) |enable| {
        window.window_size_events = enable;
    }

    if (events.WindowClose) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowCloseCallback(window.window, WindowCloseCallback);
        } else {
            _ = glfw.glfwSetWindowCloseCallback(window.window, null);
        }
    }

    if (events.WindowRefresh) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowRefreshCallback(window.window, WindowRefreshCallback);
        } else {
            _ = glfw.glfwSetWindowRefreshCallback(window.window, null);
        }
    }

    if (events.WindowFocus) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowFocusCallback(window.window, WindowFocusCallback);
        } else {
            _ = glfw.glfwSetWindowFocusCallback(window.window, null);
        }
    }

    if (events.WindowIconify) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowIconifyCallback(window.window, WindowIconifyCallback);
        } else {
            _ = glfw.glfwSetWindowIconifyCallback(window.window, null);
        }
    }

    if (events.WindowMaximize) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowMaximizeCallback(window.window, WindowMaximizeCallback);
        } else {
            _ = glfw.glfwSetWindowMaximizeCallback(window.window, null);
        }
    }

    if (events.FrambufferSize) |enable| {
        if (enable) {
            _ = glfw.glfwSetFramebufferSizeCallback(window.window, FramebufferSizeCallback);
        } else {
            _ = glfw.glfwSetFramebufferSizeCallback(window.window, null);
        }
    }

    if (events.WindowContentScale) |enable| {
        if (enable) {
            _ = glfw.glfwSetWindowContentScaleCallback(window.window, WindowContentScaleCallback);
        } else {
            _ = glfw.glfwSetWindowContentScaleCallback(window.window, null);
        }
    }

    if (events.MouseButton) |enable| {
        if (enable) {
            _ = glfw.glfwSetMouseButtonCallback(window.window, MouseButtonCallback);
        } else {
            _ = glfw.glfwSetMouseButtonCallback(window.window, null);
        }
    }

    if (events.CursorPos) |enable| {
        if (enable) {
            _ = glfw.glfwSetCursorPosCallback(window.window, CursorPosCallback);
        } else {
            _ = glfw.glfwSetCursorPosCallback(window.window, null);
        }
    }

    if (events.CursorEnter) |enable| {
        if (enable) {
            _ = glfw.glfwSetCursorEnterCallback(window.window, CursorEnterCallback);
        } else {
            _ = glfw.glfwSetCursorEnterCallback(window.window, null);
        }
    }

    if (events.Scroll) |enable| {
        if (enable) {
            _ = glfw.glfwSetScrollCallback(window.window, ScrollCallback);
        } else {
            _ = glfw.glfwSetScrollCallback(window.window, null);
        }
    }

    if (events.Key) |enable| {
        if (enable) {
            _ = glfw.glfwSetKeyCallback(window.window, KeyCallback);
        } else {
            _ = glfw.glfwSetKeyCallback(window.window, null);
        }
    }

    if (events.Char) |enable| {
        if (enable) {
            _ = glfw.glfwSetCharCallback(window.window, CharCallback);
        } else {
            _ = glfw.glfwSetCharCallback(window.window, null);
        }
    }

    if (events.CharMods) |enable| {
        if (enable) {
            _ = glfw.glfwSetCharModsCallback(window.window, CharModsCallback);
        } else {
            _ = glfw.glfwSetCharModsCallback(window.window, null);
        }
    }

    if (events.Drop) |enable| {
        if (enable) {
            _ = glfw.glfwSetDropCallback(window.window, DropCallback);
        } else {
            _ = glfw.glfwSetDropCallback(window.window, null);
        }
    }
}

fn WindowPosCallback(w: ?*glfw.GLFWwindow, xpos: c_int, ypos: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowPos = .{ .xpos = @intCast(xpos), .ypos = @intCast(ypos) } }) catch {};
}

fn WindowSizeCallback(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    // TODO: Decide if this is the user's responsibility
    gl.Viewport(0, 0, width, height);

    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.width = @intCast(width);
    window.height = @intCast(height);
    if (window.window_size_events) {
        window.events.pushBackBounded(.{ .WindowSize = .{ .width = @intCast(width), .height = @intCast(height) } }) catch {};
    }
}

fn WindowCloseCallback(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowClose = {} }) catch {};
}

fn WindowRefreshCallback(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowRefresh = {} }) catch {};
}

fn WindowFocusCallback(w: ?*glfw.GLFWwindow, focused: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowFocus = .{ .focused = focused == glfw.GLFW_TRUE } }) catch {};
}

fn WindowIconifyCallback(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowIconify = .{ .iconified = iconified == glfw.GLFW_TRUE } }) catch {};
}

fn WindowMaximizeCallback(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowMaximize = .{ .iconified = iconified == glfw.GLFW_TRUE } }) catch {};
}

fn FramebufferSizeCallback(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .FramebufferSize = .{ .width = @intCast(width), .height = @intCast(height) } }) catch {};
}

fn WindowContentScaleCallback(w: ?*glfw.GLFWwindow, xscale: f32, yscale: f32) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .WindowContentScale = .{ .xscale = xscale, .yscale = yscale } }) catch {};
}

fn MouseButtonCallback(w: ?*glfw.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .MouseButton = .{
        .button = @enumFromInt(button),
        .action = @enumFromInt(action),
        .mods = @bitCast(@as(u32, @intCast(mods))),
    } }) catch {};
}

fn CursorPosCallback(w: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .CursorPos = .{ .xpos = xpos, .ypos = ypos } }) catch {};
}

fn CursorEnterCallback(w: ?*glfw.GLFWwindow, entered: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .CursorEnter = .{ .entered = entered == glfw.GLFW_TRUE } }) catch {};
}

fn ScrollCallback(w: ?*glfw.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .Scroll = .{ .xoffset = xoffset, .yoffset = yoffset } }) catch {};
}

fn KeyCallback(w: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .Key = .{
        .key = @enumFromInt(key),
        .scancode = @intCast(scancode),
        .action = @enumFromInt(action),
        .mods = @bitCast(@as(u32, @intCast(mods))),
    } }) catch {};
}

fn CharCallback(w: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .Char = .{ .codepoint = @intCast(codepoint) } }) catch {};
}

fn CharModsCallback(w: ?*glfw.GLFWwindow, codepoint: c_uint, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    window.events.pushBackBounded(.{ .Charmods = .{ .codepoint = @intCast(codepoint), .mods = @bitCast(@as(u32, @intCast(mods))) } }) catch {};
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
    window.events.pushBackBounded(e) catch {
        e.deinit();
    };
}
