const std = @import("std");
const root = @import("root.zig");
const Color = root.Color;
const Allocator = std.mem.Allocator;
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

const TEXTURE_VERTEX_SOURCE = @embedFile("shaders/texture.vert");
const TEXTURE_FRAGMENT_SOURCE = @embedFile("shaders/texture.frag");

// ErrorFun Has to stay callconv(.c) because it doesn't pass a reference to the window in order to wrap it properly
pub const ErrorFun = *const fn (error_code: c_int, description: [*c]const u8) callconv(.c) void;
pub const WindowPosFun = *const fn (window: *Window, xpos: c_int, ypos: c_int) void;
pub const WindowSizeFun = *const fn (window: *Window, width: c_int, height: c_int) void;
pub const WindowCloseFun = *const fn (window: *Window) void;
pub const WindowRefreshFun = *const fn (window: *Window) void;
pub const WindowFocusFun = *const fn (window: *Window, focused: c_int) void;
pub const WindowIconifyFun = *const fn (window: *Window, iconified: c_int) void;
pub const WindowMaximizeFun = *const fn (window: *Window, iconified: c_int) void;
pub const FramebufferSizeFun = *const fn (window: *Window, width: c_int, height: c_int) void;
pub const WindowContentScaleFun = *const fn (window: *Window, xscale: f32, yscale: f32) void;
pub const MouseButtonFun = *const fn (window: *Window, button: c_int, action: c_int, mods: c_int) void;
pub const CursorPosFun = *const fn (window: *Window, xpos: f64, ypos: f64) void;
pub const CursorEnterFun = *const fn (window: *Window, entered: c_int) void;
pub const ScrollFun = *const fn (window: *Window, xoffset: f64, yoffset: f64) void;
pub const KeyFun = *const fn (window: *Window, key: c_int, scancode: c_int, action: c_int, mods: c_int) void;
pub const CharFun = *const fn (window: *Window, codepoint: c_uint) void;
pub const CharmodsFun = *const fn (window: *Window, codepoint: c_uint, mods: c_int) void;
pub const DropFun = *const fn (window: *Window, path_count: c_int, paths: [*c][*c]const u8) void;

pub const InitOptions = struct {
    error_callback: ?ErrorFun = null,
    userdata: ?*anyopaque = null,
};

pub const Callbacks = struct {
    error_callback: ?ErrorFun = null,
    window_pos_callback: ?WindowPosFun = null,
    window_size_callback: ?WindowSizeFun = null,
    window_close_callback: ?WindowCloseFun = null,
    window_refresh_callback: ?WindowRefreshFun = null,
    window_focus_callback: ?WindowFocusFun = null,
    window_iconify_callback: ?WindowIconifyFun = null,
    window_maximize_callback: ?WindowMaximizeFun = null,
    framebuffer_size_callback: ?FramebufferSizeFun = null,
    window_content_scale_callback: ?WindowContentScaleFun = null,
    mouse_button_callback: ?MouseButtonFun = null,
    cursor_pos_callback: ?CursorPosFun = null,
    cursor_enter_callback: ?CursorEnterFun = null,
    scroll_callback: ?ScrollFun = null,
    key_callback: ?KeyFun = null,
    char_callback: ?CharFun = null,
    charmods_callback: ?CharmodsFun = null,
    drop_callback: ?DropFun = null,
};

const Window = @This();
gpa: Allocator,
window: *glfw.GLFWwindow,
procs: gl.ProcTable,
callbacks: Callbacks,
userdata: ?*anyopaque,

texture_array: *Array,
texture_buffer: Buffer,
texture_program: Program,

/// It is undefined behavior to create more that a single Window.
pub fn init(gpa: Allocator, width: comptime_int, height: comptime_int, title: [:0]const u8, options: InitOptions) !*Window {
    _ = glfw.glfwSetErrorCallback(options.error_callback);

    var window = try gpa.create(Window);
    errdefer gpa.destroy(window);
    window.gpa = gpa;
    window.callbacks = .{ .error_callback = options.error_callback };
    window.userdata = options.userdata;

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

    // NOTE: Need to keep window size callback bound for Viewport resizing. If that responsibility is moved to the user,
    // this line can be removed
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

pub fn SetErrorCallback(window: *Window, function: ?ErrorFun) void {
    _ = glfw.glfwSetErrorCallback(function);
    window.callbacks.error_callback = function;
}

pub fn SetWindowPosCallback(window: *Window, function: ?WindowPosFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowPosCallback(window.window, WindowPosCallback);
    } else {
        _ = glfw.glfwSetWindowPosCallback(window.window, null);
    }
    window.callbacks.window_pos_callback = function;
}

fn WindowPosCallback(w: ?*glfw.GLFWwindow, xpos: c_int, ypos: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_pos_callback) |callback| {
        callback(window, xpos, ypos);
    }
}

pub fn SetWindowSizeCallback(window: *Window, function: ?WindowSizeFun) void {
    _ = glfw.glfwSetWindowSizeCallback(window.window, WindowSizeCallback);
    window.callbacks.window_size_callback = function;
}

fn WindowSizeCallback(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));

    // TODO: Decide if this is the user's responsibility
    gl.Viewport(0, 0, width, height);

    if (window.callbacks.window_size_callback) |callback| {
        callback(window, width, height);
    }
}

pub fn SetWindowCloseCallback(window: *Window, function: ?WindowCloseFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowCloseCallback(window.window, WindowCloseCallback);
    } else {
        _ = glfw.glfwSetWindowCloseCallback(window.window, null);
    }
    window.callbacks.window_close_callback = function;
}

fn WindowCloseCallback(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_close_callback) |callback| {
        callback(window);
    }
}

pub fn SetWindowRefreshCallback(window: *Window, function: ?WindowRefreshFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowRefreshCallback(window.window, WindowRefreshCallback);
    } else {
        _ = glfw.glfwSetWindowRefreshCallback(window.window, null);
    }
    window.callbacks.window_refresh_callback = function;
}

fn WindowRefreshCallback(w: ?*glfw.GLFWwindow) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_refresh_callback) |callback| {
        callback(window);
    }
}

pub fn SetWindowFocusCallback(window: *Window, function: ?WindowFocusFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowFocusCallback(window.window, WindowFocusCallback);
    } else {
        _ = glfw.glfwSetWindowFocusCallback(window.window, null);
    }
    window.callbacks.window_focus_callback = function;
}

fn WindowFocusCallback(w: ?*glfw.GLFWwindow, focused: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_focus_callback) |callback| {
        callback(window, focused);
    }
}

pub fn SetWindowIconifyCallback(window: *Window, function: ?WindowIconifyFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowIconifyCallback(window.window, WindowIconifyCallback);
    } else {
        _ = glfw.glfwSetWindowIconifyCallback(window.window, null);
    }
    window.callbacks.window_iconify_callback = function;
}

fn WindowIconifyCallback(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_iconify_callback) |callback| {
        callback(window, iconified);
    }
}

pub fn SetWindowMaximizeCallback(window: *Window, function: ?WindowMaximizeFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowMaximizeCallback(window.window, WindowMaximizeCallback);
    } else {
        _ = glfw.glfwSetWindowMaximizeCallback(window.window, null);
    }
    window.callbacks.window_maximize_callback = function;
}

fn WindowMaximizeCallback(w: ?*glfw.GLFWwindow, iconified: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_maximize_callback) |callback| {
        callback(window, iconified);
    }
}

pub fn SetFramebufferSizeCallback(window: *Window, function: ?FramebufferSizeFun) void {
    if (function != null) {
        _ = glfw.glfwSetFramebufferSizeCallback(window.window, FramebufferSizeCallback);
    } else {
        _ = glfw.glfwSetFramebufferSizeCallback(window.window, null);
    }
    window.callbacks.framebuffer_size_callback = function;
}

fn FramebufferSizeCallback(w: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.framebuffer_size_callback) |callback| {
        callback(window, width, height);
    }
}

pub fn SetWindowContentScaleCallback(window: *Window, function: ?WindowContentScaleFun) void {
    if (function != null) {
        _ = glfw.glfwSetWindowContentScaleCallback(window.window, WindowContentScaleCallback);
    } else {
        _ = glfw.glfwSetWindowContentScaleCallback(window.window, null);
    }
    window.callbacks.window_content_scale_callback = function;
}

fn WindowContentScaleCallback(w: ?*glfw.GLFWwindow, xscale: f32, yscale: f32) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.window_content_scale_callback) |callback| {
        callback(window, xscale, yscale);
    }
}

pub fn SetMouseButtonCallback(window: *Window, function: ?MouseButtonFun) void {
    if (function != null) {
        _ = glfw.glfwSetMouseButtonCallback(window.window, MouseButtonCallback);
    } else {
        _ = glfw.glfwSetMouseButtonCallback(window.window, null);
    }
    window.callbacks.mouse_button_callback = function;
}

fn MouseButtonCallback(w: ?*glfw.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.mouse_button_callback) |callback| {
        callback(window, button, action, mods);
    }
}

pub fn SetCursorPosCallback(window: *Window, function: ?CursorPosFun) void {
    if (function != null) {
        _ = glfw.glfwSetCursorPosCallback(window.window, CursorPosCallback);
    } else {
        _ = glfw.glfwSetCursorPosCallback(window.window, null);
    }
    window.callbacks.cursor_pos_callback = function;
}

fn CursorPosCallback(w: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.cursor_pos_callback) |callback| {
        callback(window, xpos, ypos);
    }
}

pub fn SetCursorEnterCallback(window: *Window, function: ?CursorEnterFun) void {
    if (function != null) {
        _ = glfw.glfwSetCursorEnterCallback(window.window, CursorEnterCallback);
    } else {
        _ = glfw.glfwSetCursorEnterCallback(window.window, null);
    }
    window.callbacks.cursor_enter_callback = function;
}

fn CursorEnterCallback(w: ?*glfw.GLFWwindow, entered: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.cursor_enter_callback) |callback| {
        callback(window, entered);
    }
}

pub fn SetScrollCallback(window: *Window, function: ?ScrollFun) void {
    if (function != null) {
        _ = glfw.glfwSetScrollCallback(window.window, ScrollCallback);
    } else {
        _ = glfw.glfwSetScrollCallback(window.window, null);
    }
    window.callbacks.scroll_callback = function;
}

fn ScrollCallback(w: ?*glfw.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.scroll_callback) |callback| {
        callback(window, xoffset, yoffset);
    }
}

pub fn SetKeyCallback(window: *Window, function: ?KeyFun) void {
    if (function != null) {
        _ = glfw.glfwSetKeyCallback(window.window, KeyCallback);
    } else {
        _ = glfw.glfwSetKeyCallback(window.window, null);
    }
    window.callbacks.key_callback = function;
}

fn KeyCallback(w: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.key_callback) |callback| {
        callback(window, key, scancode, action, mods);
    }
}

pub fn SetCharCallback(window: *Window, function: ?CharFun) void {
    if (function != null) {
        _ = glfw.glfwSetCharCallback(window.window, CharCallback);
    } else {
        _ = glfw.glfwSetCharCallback(window.window, null);
    }
    window.callbacks.char_callback = function;
}

fn CharCallback(w: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.char_callback) |callback| {
        callback(window, codepoint);
    }
}

pub fn SetCharmodsCallback(window: *Window, function: ?CharmodsFun) void {
    if (function != null) {
        _ = glfw.glfwSetCharModsCallback(window.window, CharmodsCallback);
    } else {
        _ = glfw.glfwSetCharModsCallback(window.window, null);
    }
    window.callbacks.charmods_callback = function;
}

fn CharmodsCallback(w: ?*glfw.GLFWwindow, codepoint: c_uint, mods: c_int) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.charmods_callback) |callback| {
        callback(window, codepoint, mods);
    }
}

pub fn SetDropCallback(window: *Window, function: ?DropFun) void {
    if (function != null) {
        _ = glfw.glfwSetDropCallback(window.window, DropCallback);
    } else {
        _ = glfw.glfwSetDropCallback(window.window, null);
    }
    window.callbacks.drop_callback = function;
}

fn DropCallback(w: ?*glfw.GLFWwindow, path_count: c_int, paths: [*c][*c]const u8) callconv(.c) void {
    const window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(w)));
    if (window.callbacks.drop_callback) |callback| {
        callback(window, path_count, paths);
    }
}
