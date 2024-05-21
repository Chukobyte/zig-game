const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zeika_dep = b.dependency("zeika", .{
        .target = target,
        .optimize = optimize,
    });
    const zeika_module = zeika_dep.module("zeika");

    const exe = b.addExecutable(.{
        .name = "game",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const engine_module = b.addModule("engine", .{
        .root_source_file = .{ .path = "src/engine/engine.zig" },
    });
    engine_module.addImport("zeika", zeika_module);

    const game_module = b.addModule("game", .{
        .root_source_file = .{ .path = "src/game/game.zig" },
    });
    game_module.addImport("zeika", zeika_module);

    const assets_module = b.addModule("assets", .{
        .root_source_file = .{ .path = "embed_assets.zig" },
    });

    exe.linkLibC();
    const seika_lib: *std.Build.Step.Compile = zeika_dep.artifact("seika");
    exe.linkLibrary(seika_lib);
    exe.installLibraryHeaders(seika_lib);
    exe.root_module.addImport("zeika", zeika_module);
    exe.root_module.addImport("engine", engine_module);
    exe.root_module.addImport("game", game_module);
    exe.root_module.addImport("assets", assets_module);
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);

    // Test
    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "src/test/tests.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_exe.root_module.addImport("zeika", zeika_module);
    test_exe.root_module.addImport("engine", engine_module);
    test_exe.root_module.addImport("game", game_module);
    const run_test = b.addRunArtifact(test_exe);
    run_test.has_side_effects = true;
    const test_step = b.step("test", "Run tests for the game");
    test_step.dependOn(&run_test.step);
}
