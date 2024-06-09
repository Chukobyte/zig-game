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
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine_module = b.addModule("engine", .{
        .root_source_file = b.path("src/engine/engine.zig"),
    });
    engine_module.addImport("zeika", zeika_module);

    const game_module = b.addModule("game", .{
        .root_source_file = b.path("src/game/game.zig"),
    });
    game_module.addImport("zeika", zeika_module);
    game_module.addImport("engine", engine_module);

    const assets_module = b.addModule("assets", .{
        .root_source_file = b.path("embed_assets.zig"),
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
    const TestDefinition = struct {
        name: []const u8,
        file_path: []const u8,
        description: []const u8,
    };

    const test_defs = [_]TestDefinition{
        .{ .name = "test", .description = "Run unit tests for the game", .file_path = "src/test/unit.zig" },
        .{ .name = "integration-test", .description = "Run integration tests for the game", .file_path = "src/test/integration.zig" },
        .{ .name = "perf-test", .description = "Run perf tests for the game", .file_path = "src/test/perf.zig" },
    };

    for (test_defs) |def| {
        const test_exe = b.addTest(.{
            .root_source_file = b.path(def.file_path),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        test_exe.root_module.addImport("zeika", zeika_module);
        test_exe.root_module.addImport("engine", engine_module);
        test_exe.root_module.addImport("game", game_module);

        const run_test = b.addRunArtifact(test_exe);
        run_test.has_side_effects = true;

        const test_step = b.step(def.name, def.description);
        test_step.dependOn(&run_test.step);
    }
}
