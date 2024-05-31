const std = @import("std");

const engine = @import("engine");

const data_db = engine.data_db;

test "object data db read and write test" {
    const allocator = std.testing.allocator;
    var path_buffer: [1028]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &path_buffer);
    const temp_test_path = try std.mem.concat(allocator, u8, &.{ cwd, "/temp_test" });
    defer allocator.free(temp_test_path);

    std.fs.cwd().makeDir("temp_test") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Serialize test
    const SimpleStruct = struct {
        num: i32,
        text: []u8,
    };

    const binary_serialize_path = try std.mem.concat(allocator, u8, &.{ temp_test_path, "/save.data" });
    const json_serialize_path = try std.mem.concat(allocator, u8, &.{ temp_test_path, "/save.json" });
    defer allocator.free(binary_serialize_path);
    defer allocator.free(json_serialize_path);

    // Serialize
    {
        var data_db_inst = data_db.ObjectDataDB.init(allocator);
        defer data_db_inst.deinit();

        const test_message = try allocator.dupe(u8, "Message");
        defer allocator.free(test_message);

        var simple = SimpleStruct{ .num = 99, .text = test_message };
        const simple_object = try data_db_inst.createObject(.{ .name = "Simple" });
        try data_db_inst.copyObjectFromType(SimpleStruct, &simple, simple_object);
        const simple_object_prop = data_db_inst.findProperty(simple_object, "num");
        try std.testing.expect(simple_object_prop != null);
        try std.testing.expectEqual(99, simple_object_prop.?.value.integer);

        const simple_object2 = try data_db_inst.createObjectFromType(SimpleStruct, &.{ .num = 66, .text = test_message }, .{ .name = "Simple2" });
        try std.testing.expectEqual(66, data_db_inst.findProperty(simple_object2, "num").?.value.integer);

        try data_db_inst.serialize(.{ .file_path = binary_serialize_path, .mode = .binary });
        try data_db_inst.serialize(.{ .file_path = json_serialize_path, .mode = .json });
    }

    // Deserialize
    const params_to_test = [_]data_db.ObjectDataDB.DeserializeParams{
        .{ .file_path = binary_serialize_path, .mode = .binary },
        .{ .file_path = json_serialize_path, .mode = .json },
    };
    for (params_to_test) |params| {
        var data_db_inst = data_db.ObjectDataDB.init(allocator);
        defer data_db_inst.deinit();

        try data_db_inst.deserialize(.{ .file_path = params.file_path, .mode = params.mode });
        const simple_object = try data_db_inst.findOrAddObject(.{ .name = "Simple" });
        const simple_object_prop = data_db_inst.findProperty(simple_object, "num");
        try std.testing.expect(simple_object_prop != null);
        try std.testing.expectEqual(99, simple_object_prop.?.value.integer);

        const simple_object2 = try data_db_inst.findOrAddObject(.{ .name = "Simple2" });
        try std.testing.expectEqual(66, data_db_inst.findProperty(simple_object2, "num").?.value.integer);

        var simple = SimpleStruct{ .num = undefined, .text = undefined };
        try data_db_inst.copyTypeFromObject(simple_object, SimpleStruct, &simple);
        try std.testing.expectEqual(99, simple.num);
        try std.testing.expectEqualStrings("Message", simple.text);
        var simple2 = SimpleStruct{ .num = undefined, .text = undefined };
        try data_db_inst.copyTypeFromObject(simple_object2, SimpleStruct, &simple2);
        try std.testing.expectEqual(66, simple2.num);
        allocator.free(simple.text);
        allocator.free(simple2.text);
    }
}
