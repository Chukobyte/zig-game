const std = @import("std");

const engine = @import("engine");

const ecs = engine.ecs;

test "ecs perf test" {
    const entities_to_test = 100_000;
    const test_iterations = 10;

    const TestReport = struct {
        accumalated_normal: u64 = 0,
        accumalated_iter_ordered: u64 = 0,
        accumalated_iter_unordered: u64 = 0,
        };

    const TestComp0 = struct { size: usize = 0, };
    const TestComp1 = struct { size: usize = 0, };
    const TestComp2 = struct { size: usize = 0, };

    const TestSystem0 = struct { pub fn getArchetype() []const type { return &.{ TestComp0, TestComp1, TestComp2 }; } };
    const TestSystem1 = struct { pub fn getArchetype() []const type { return &.{ TestComp2, TestComp1, TestComp0 }; } };
    const TestSystem2 = struct { pub fn getArchetype() []const type { return &.{ TestComp1, TestComp2, TestComp0 }; } };

    const Context = ecs.ECSContext(.{
        .entity_type = usize,
        .components = &.{ TestComp0, TestComp1, TestComp2 },
        .systems = &.{ TestSystem0, TestSystem1, TestSystem2 },
    });
    const ComponentIterator = Context.ArchetypeComponentIterator;

    var report = TestReport{};

    var context = try Context.init(std.testing.allocator);
    defer context.deinit();

    for (0..entities_to_test) |i| {
        _ = i;
        const new_entity = try context.initEntity(.{});
        try context.setComponent(new_entity, TestComp0, &.{});
        try context.setComponent(new_entity, TestComp1, &.{});
        try context.setComponent(new_entity, TestComp2, &.{});
    }

    std.debug.print("=====================================================\n", .{});
    std.debug.print("Starting testing ecs perf with '{d}' entities with {d} test iterations\n", .{ entities_to_test, test_iterations });

    for (0..test_iterations) |i| {
        std.debug.print("=====================================================\n", .{});
        std.debug.print("Test Iteration {d}\n\n", .{ i });

        var timer = try std.time.Timer.start();

        // Normal get duration
        {
            defer timer.reset();
            for (0..entities_to_test) |entity| {
                _ = context.getComponent(entity, TestComp0);
                _ = context.getComponent(entity, TestComp1);
                _ = context.getComponent(entity, TestComp2);
            }

            const normal_get_duration = timer.read();
            report.accumalated_normal += normal_get_duration;
            std.debug.print("normal get duration: {d}ns\n", .{ normal_get_duration });
        }

        // Iter ordered get duration
        {
            defer timer.reset();
            var comp_iterator = ComponentIterator(&.{ TestComp0, TestComp1, TestComp2 }).init(&context);

            while (comp_iterator.next()) |iter| {
                _ = iter.getValue(0);
                _ = iter.getValue(1);
                _ = iter.getValue(2);
            }

            const iter_ordered_get_duration = timer.read();
            report.accumalated_iter_ordered += iter_ordered_get_duration;
            std.debug.print("iterator get duration: {d}ns\n", .{ iter_ordered_get_duration });
        }

        // Iter unordered get duration
        {
            defer timer.reset();
            var comp_iterator = ComponentIterator(&.{ TestComp0, TestComp1, TestComp2 }).init(&context);

            while (comp_iterator.next()) |iter| {
                _ = iter.getValue(2);
                _ = iter.getValue(1);
                _ = iter.getValue(0);
            }
            const iter_unordered_get_duration = timer.read();
            report.accumalated_iter_unordered += iter_unordered_get_duration;
            std.debug.print("iterator unordered get duration: {d}ns\n", .{ iter_unordered_get_duration });
        }


        std.debug.print("=====================================================\n", .{});
    }

    std.debug.print("Averaged Results\n\n", .{});
    std.debug.print("average normal get duration: {d}ns\n", .{ report.accumalated_normal / test_iterations });
    std.debug.print("average iterator get duration: {d}ns\n", .{ report.accumalated_iter_ordered / test_iterations });
    std.debug.print("average iterator unordered get duration: {d}ns\n", .{ report.accumalated_iter_unordered / test_iterations });
    std.debug.print("=====================================================\n", .{});
}
