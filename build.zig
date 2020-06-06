const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var exe = b.addExecutable("triangle", "src/main.zig");
    exe.setBuildMode(mode);
    exe.addCSourceFile("src/glad/glad.c", &[_][]const u8{"-std=c99"});

    exe.addIncludeDir("src/glad");
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("glfw");
    exe.install();

    const play = b.step("play", "Play the game");
    const run = exe.run();
    run.step.dependOn(b.getInstallStep());
    play.dependOn(&run.step);
}
