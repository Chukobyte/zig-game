const std = @import("std");

const data_db = @import("engine/object_data_db.zig");
const ObjectsList = data_db.ObjectsList;
const Object = data_db.Object;
const Property = data_db.Property;

test "object data db read and write test" {
    var data_db_inst = data_db.ObjectDataDB.init(std.heap.page_allocator);
    defer data_db_inst.deinit();
    const temp_object = try data_db_inst.createObject("Test");
    try data_db_inst.writeProperty(temp_object, "age", i32, 8);
    if (data_db_inst.readProperty(temp_object, "age", i32)) |old_age| {
        try std.testing.expectEqual(8, old_age);
    } else {
        try std.testing.expect(false);
    }

    try data_db_inst.writeProperty(temp_object, "name", []const u8, "Daniel");
    if (data_db_inst.readProperty(temp_object, "name", []const u8)) |name| {
        try std.testing.expectEqualStrings("Daniel", name);
    } else {
        try std.testing.expect(false);
    }

    const temp_object2 = try data_db_inst.createObject("Test2");
    try data_db_inst.addAsSubObject(temp_object, temp_object2);
    try std.testing.expect(temp_object.subobjects.items.len == 1);
}

test "object data db json test" {
    const allocator = std.testing.allocator;
    const json_to_parse =
        \\{
        \\  "objects": [
        \\    {
        \\      "name": "Mike",
        \\      "id": 42,
        \\      "properties": [
        \\        {
        \\          "key": "title",
        \\          "value": "test_game"
        \\        },
        \\        {
        \\          "key": "time_dilation",
        \\          "value": 5e-1
        \\        }
        \\      ],
        \\      "subobjects": [
        \\        {
        \\          "name": "Gary",
        \\          "id": 28,
        \\          "properties": [],
        \\          "subobjects": []
        \\        }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    const parsed = try std.json.parseFromSlice(ObjectsList,allocator, json_to_parse, .{});
    defer parsed.deinit();

    var object_list: ObjectsList = parsed.value;
    defer object_list.deinit();

    const first_game_object: *Object = &object_list.objects[0];
    try std.testing.expectEqualStrings("Mike", first_game_object.name);
    try std.testing.expectEqual(42, first_game_object.id);
    try std.testing.expectEqual(1, object_list.objects.len);
    try std.testing.expectEqual(1, first_game_object.subobjects.items.len);
    // Test properties
    try std.testing.expectEqual(2, first_game_object.properties.items.len);
    const game_object_prop: *Property = &first_game_object.properties.items[0];
    try std.testing.expectEqual(.string, game_object_prop.type);
    try std.testing.expectEqualStrings("title",game_object_prop.key);
    try std.testing.expectEqualStrings("test_game",game_object_prop.value.string);
    const game_object_prop2: *Property = &first_game_object.properties.items[1];
    try std.testing.expectEqual(.float, game_object_prop2.type);
    try std.testing.expectEqualStrings("time_dilation",game_object_prop2.key);
    try std.testing.expectEqual(0.5,game_object_prop2.value.float);
    // Test subobject
    const subobject = first_game_object.subobjects.items[0];
    try std.testing.expectEqualStrings("Gary",subobject.name);
    try std.testing.expectEqual(28, subobject.id);
    try std.testing.expectEqual(0, subobject.subobjects.items.len);

    // Test stringify
    const json_string = try std.json.stringifyAlloc(allocator, object_list, .{.whitespace = .indent_2});
    defer allocator.free(json_string);
    try std.testing.expectEqualStrings(json_to_parse,json_string);
    std.debug.print("json_string = \n{s}\n", .{ json_string });
}
