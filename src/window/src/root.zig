const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});

/// Accepts rgba as ranges from 0-255
pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const Window = @This();
gpa: Allocator,
window: *glfw.GLFWwindow,
procs: gl.ProcTable,

/// It is undefined behavior to create more that a single Window.
pub fn init(gpa: Allocator, width: comptime_int, height: comptime_int, title: [:0]const u8) !*Window {
    _ = glfw.glfwSetErrorCallback(ErrorFun);

    var window = try gpa.create(Window);
    errdefer gpa.destroy(window);
    window.gpa = gpa;

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
    _ = glfw.glfwSetWindowPosCallback(window.window, WindowPosFun);
    _ = glfw.glfwSetWindowSizeCallback(window.window, WindowSizeFun);
    _ = glfw.glfwSetWindowCloseCallback(window.window, WindowCloseFun);
    _ = glfw.glfwSetWindowRefreshCallback(window.window, WindowRefreshFun);
    _ = glfw.glfwSetWindowFocusCallback(window.window, WindowFocusFun);
    _ = glfw.glfwSetWindowIconifyCallback(window.window, WindowIconifyFun);
    _ = glfw.glfwSetWindowMaximizeCallback(window.window, WindowMaximizeFun);
    _ = glfw.glfwSetFramebufferSizeCallback(window.window, FramebufferSizeFun);
    _ = glfw.glfwSetWindowContentScaleCallback(window.window, WindowContentScaleFun);
    _ = glfw.glfwSetMouseButtonCallback(window.window, MouseButtonFun);
    _ = glfw.glfwSetCursorPosCallback(window.window, CursorPosFun);
    _ = glfw.glfwSetCursorEnterCallback(window.window, CursorEnterFun);
    _ = glfw.glfwSetScrollCallback(window.window, ScrollFun);
    _ = glfw.glfwSetKeyCallback(window.window, KeyFun);
    _ = glfw.glfwSetCharCallback(window.window, CharFun);
    _ = glfw.glfwSetCharModsCallback(window.window, CharmodsFun);
    _ = glfw.glfwSetDropCallback(window.window, DropFun);

    // Initialize the procedure table.
    if (!window.procs.init(glfw.glfwGetProcAddress)) return error.InitFailed;

    // Make the procedure table current on the calling thread.
    gl.makeProcTableCurrent(&window.procs);
    gl.Viewport(0, 0, width, height);

    return window;
}

pub fn deinit(window: *Window) void {
    gl.makeProcTableCurrent(null);
    glfw.glfwDestroyWindow(window.window);
    glfw.glfwTerminate();
    window.gpa.destroy(window);
}

pub fn ShouldClose(window: *Window) bool {
    return glfw.glfwWindowShouldClose(window.window) == glfw.GLFW_TRUE;
}

pub fn Clear(_: *Window, color: Color) void {
    gl.ClearColor(color.r / 255.0, color.g / 255.0, color.b / 255.0, color.a / 255.0);
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn SwapBuffers(window: *Window) void {
    glfw.glfwSwapBuffers(window.window);
    glfw.glfwPollEvents();
}

pub fn ErrorFun(error_code: c_int, description: [*c]const u8) callconv(.c) void {
    std.log.err("Error ({d}): {s}\n", .{ error_code, std.mem.span(description) });
}

pub fn WindowPosFun(w: ?*glfw.GLFWwindow, xpos: c_int, ypos: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, xpos, ypos };
}

pub fn WindowSizeFun(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    // TODO: Decide if this is the user's responsibility
    gl.Viewport(0, 0, width, height);
    _ = .{ window, width, height };
}

pub fn WindowCloseFun(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = window;
}

pub fn WindowRefreshFun(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = window;
}

pub fn WindowFocusFun(w: ?*glfw.GLFWwindow, focused: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, focused };
}

pub fn WindowIconifyFun(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, iconified };
}

pub fn WindowMaximizeFun(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, iconified };
}

pub fn FramebufferSizeFun(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, width, height };
}

pub fn WindowContentScaleFun(w: ?*glfw.GLFWwindow, xscale: f32, yscale: f32) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, xscale, yscale };
}

pub fn MouseButtonFun(w: ?*glfw.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, button, action, mods };
}

pub fn CursorPosFun(w: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, xpos, ypos };
}

pub fn CursorEnterFun(w: ?*glfw.GLFWwindow, entered: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, entered };
}

pub fn ScrollFun(w: ?*glfw.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, xoffset, yoffset };
}

pub fn KeyFun(w: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, key, scancode, action, mods };
}

pub fn CharFun(w: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, codepoint };
}

pub fn CharmodsFun(w: ?*glfw.GLFWwindow, codepoint: c_uint, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, codepoint, mods };
}

pub fn DropFun(w: ?*glfw.GLFWwindow, path_count: c_int, paths: [*c][*c]const u8) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    _ = .{ window, path_count, paths };
}
