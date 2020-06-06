const std = @import("std");
const warn = @import("std").debug.warn;
const panic = @import("std").debug.panic;
const c = @import("c.zig");

const WINSIZE = comptime [2]c_int{ 1024, 768 };
const WINTITLE = comptime "OpenGL Triangle Example!";

/// Shader struct
pub const Shader = struct {
    id: c_uint = 0,

    fn compile(source: [*c]const u8, shaderType: c_uint, alloc: *std.mem.Allocator) !c_uint {
        var result = c.glCreateShader(shaderType);
        c.glShaderSource(result, 1, &source, null);
        c.glCompileShader(result);

        var whu: c_int = undefined;
        c.glGetShaderiv(result, c.GL_COMPILE_STATUS, &whu);
        if (whu == c.GL_FALSE) {
            var length: c_int = undefined;
            c.glGetShaderiv(result, c.GL_INFO_LOG_LENGTH, &length);
            var message = try alloc.alloc(u8, @intCast(usize, length));
            defer alloc.free(message);
            c.glGetShaderInfoLog(result, length, &length, @ptrCast([*c]u8, message));

            const mtype: *const [4:0]u8 = if (shaderType == c.GL_VERTEX_SHADER) "VERT" else "FRAG";

            std.debug.warn("Failed to compile shader(Type: {})!\nError: {}\n", .{
                mtype,
                message,
            });

            c.glDeleteShader(result);
        }

        return result;
    }

    /// Creates a shader from vertex and fragment source
    pub fn create(vertexShader: [*c]const u8, fragShader: [*c]const u8, alloc: *std.mem.Allocator) !Shader {
        const vx = try Shader.compile(vertexShader, c.GL_VERTEX_SHADER, alloc);
        const fg = try Shader.compile(fragShader, c.GL_FRAGMENT_SHADER, alloc);

        var result = Shader{};
        result.id = c.glCreateProgram();
        c.glAttachShader(result.id, vx);
        c.glAttachShader(result.id, fg);
        c.glLinkProgram(result.id);

        var ok: c_int = 0;
        c.glGetProgramiv(result.id, c.GL_LINK_STATUS, &ok);
        if (ok == c.GL_FALSE) {
            var error_size: c_int = undefined;
            c.glGetProgramiv(result.id, c.GL_INFO_LOG_LENGTH, &error_size);

            var message = try alloc.alloc(u8, @intCast(usize, error_size));
            defer alloc.free(message);

            c.glGetProgramInfoLog(result.id, error_size, &error_size, @ptrCast([*c]u8, message));
            std.debug.warn("Error occured while linking shader program:\n\t{}\n", .{message});

            c.glDeleteProgram(result.id);
        }
        c.glValidateProgram(result.id);

        c.glDeleteShader(vx);
        c.glDeleteShader(fg);

        return result;
    }

    /// Destroys the shader
    pub fn destroy(self: Shader) Shader {
        c.glDeleteProgram(self.id);
        return Shader{};
    }

    /// Attachs the shader
    pub fn attach(self: Shader) void {
        c.glUseProgram(self.id);
    }
};

const vertex = struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
};

const vertices = comptime [3]vertex{
    vertex{ .x = -0.6, .y = -0.4, .r = 1.0, .g = 0.0, .b = 0.0 },
    vertex{ .x = 0.6, .y = -0.4, .r = 0.0, .g = 1.0, .b = 0.0 },
    vertex{ .x = 0.0, .y = 0.6, .r = 0.0, .g = 0.0, .b = 1.0 },
};

const vertex_shader_t =
    \\#version 330 core
    \\layout(location = 0) in vec2 vPos;
    \\layout(location = 1) in vec3 vCol;
    \\out vec4 outCol;
    \\void main() {
    \\  gl_Position = vec4(vPos, 0.0, 1.0);
    \\  outCol = vec4(vCol, 1.0);
    \\}
;
const fragment_shader_t =
    \\#version 330 core
    \\in vec4 outCol;
    \\void main() {
    \\  gl_FragColor = outCol; 
    \\}
;

pub fn main() anyerror!void {
    if (c.glfwInit() == 0) {
        panic("Failed to initialize GLFW!\n", .{});
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_RESIZABLE, 0);

    var window = c.glfwCreateWindow(WINSIZE[0], WINSIZE[1], WINTITLE, null, null);

    c.glfwMakeContextCurrent(window);
    if (c.gladLoadGLLoader(@ptrCast(fn ([*c]const u8) callconv(.C) ?*c_void, c.glfwGetProcAddress)) == 0) {
        std.debug.panic("Failed to load OpenGL/GLAD!\n", .{});
    }
    c.glfwSwapInterval(1);

    var vbo: c_uint = undefined;
    var vao: c_uint = undefined;

    var program = try Shader.create(vertex_shader_t, fragment_shader_t, std.heap.page_allocator);

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glBindVertexArray(vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(vertex) * 3, @ptrCast(*const c_void, &vertices), c.GL_STATIC_DRAW);

    var stride: c_int = @sizeOf(f32) * 2;

    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(vertex), null);
    c.glEnableVertexAttribArray(1);
    c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(vertex), @ptrCast(*const c_void, &stride));

    c.glBindVertexArray(0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

    while (c.glfwWindowShouldClose(window) == 0) {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(window, &w, &h);
        c.glViewport(0, 0, w, h);

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        program.attach();
        c.glBindVertexArray(vao);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    program = program.destroy();
    c.glDeleteVertexArrays(1, &vao);
    c.glDeleteBuffers(1, &vbo);
    c.glfwDestroyWindow(window);
}
