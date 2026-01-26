const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @cImport(@cInclude("glad/gl.h"));
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});

const Window = @This();
gpa: Allocator,
window: *glfw.GLFWwindow,

/// It is undefined behavior to create more that a single Window.
pub fn init(gpa: Allocator, width: comptime_int, height: comptime_int, title: [:0]const u8) !*Window {
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

    if (gl.gladLoadGL(glfw.glfwGetProcAddress) == 0) return error.GladLoadError;

    // TODO: Register Callbacks for:
    // * Window Position
    // * Window Size
    // * Window Focus
    // * Window Maximize
    // * Frame Buffer Size
    // * Key
    // * Mouse Button
    // * Cursor Position
    // * Scroll
    // * Error

    return window;
}

pub fn deinit(window: *Window) void {
    glfw.glfwDestroyWindow(window.window);
    glfw.glfwTerminate();
    window.gpa.destroy(window);
}

pub fn ShouldClose(window: *Window) bool {
    return glfw.glfwWindowShouldClose(window.window) == glfw.GLFW_TRUE;
}

pub fn Clear(_: *Window) void {
    gl.glClear(gl.GL_COLOR_BUFFER_BIT);
}

pub fn SwapBuffers(window: *Window) void {
    glfw.glfwSwapBuffers(window.window);
    glfw.glfwPollEvents();
}
