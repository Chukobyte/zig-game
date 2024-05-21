const std = @import("std");

const math = @import("zeika").math;

const engine = @import("engine");
const game = @import("game");

const data_db = engine.data_db;
const core = engine.core;
const ec = engine.ec;

const ObjectsList = data_db.ObjectsList;
const Object = data_db.Object;
const Property = data_db.Property;

var has_test_entity_init = false;
var has_test_entity_deinit = false;
var has_test_entity_updated = false;

var dialogue_comp_init = false;
var dialogue_comp_deinit = false;
var dialogue_comp_update = false;

const DialogueComponent = struct {
    text: []const u8,

    pub fn init(comp: *anyopaque, entity: *ECContext.Entity) void {
        _ = entity;
        const dial_comp: *@This() = @alignCast(@ptrCast(comp));
        if (std.mem.eql(u8, "Test speech!", dial_comp.text)) {
            dialogue_comp_init = true;
        }
    }

    pub fn deinit(comp: *anyopaque, entity: *ECContext.Entity) void {
        _ = entity;
        const dial_comp: *@This() = @alignCast(@ptrCast(comp));
        if (std.mem.eql(u8, "Test speech!", dial_comp.text)) {
            dialogue_comp_deinit = true;
        }
    }

    pub fn update(comp: *anyopaque, entity: *ECContext.Entity) void {
        _ = entity;
        const dial_comp: *@This() = @alignCast(@ptrCast(comp));
        if (std.mem.eql(u8, "Test speech!", dial_comp.text)) {
            dialogue_comp_update = true;
        }
    }
};

const TransformComponent = struct {
    transform: math.Transform2D,
};

test "type list test" {
    const TestTypeList = ec.TypeList(&.{ DialogueComponent, TransformComponent });
    try std.testing.expectEqual(0, TestTypeList.getIndex(DialogueComponent));
    try std.testing.expectEqual(1, TestTypeList.getIndex(TransformComponent));
    try std.testing.expectEqual(DialogueComponent, TestTypeList.getType(0));
    try std.testing.expectEqual(TransformComponent, TestTypeList.getType(1));
}

const ECContext = ec.ECContext(u32, &.{ DialogueComponent, TransformComponent });

test "entity component test" {
    var ec_context = ECContext.init(std.testing.allocator);
    defer ec_context.deinit();

    const test_entity_template = ECContext.EntityTemplate{
        .interface = .{
            .init = struct {
                pub fn init(self: *ECContext.Entity) void {
                    _ = self;
                    has_test_entity_init = true;
                }
            }.init,
            .deinit = struct {
                pub fn deinit(self: *ECContext.Entity) void {
                    _ = self;
                    has_test_entity_deinit = true;
                }
            }.deinit,
            .update = struct {
                pub fn update(self: *ECContext.Entity) void {
                    _ = self;
                    has_test_entity_updated = true;
                }
            }.update,
        },
        // .components = .{ @as(*anyopaque, @constCast(@ptrCast(&DialogueComponent{ .text = "Test" }))), @as(*anyopaque, @constCast(@ptrCast(&TransformComponent{ .transform = math.Transform2D.Identity }))) }
        .components = .{ null, @as(*anyopaque, @constCast(@ptrCast(&TransformComponent{ .transform = math.Transform2D.Identity }))) }
    };
    var test_entity = try ec_context.initEntity(&test_entity_template);
    try std.testing.expect(test_entity.hasComponent(TransformComponent));
    try std.testing.expect(!test_entity.hasComponent(DialogueComponent));
    try test_entity.setComponent(DialogueComponent, &.{ .text = "Test speech!" });
    try std.testing.expect(test_entity.hasComponent(DialogueComponent));

    if (test_entity.getComponent(DialogueComponent)) |found_comp| {
        try std.testing.expectEqualStrings("Test speech!", found_comp.text);
    }

    ec_context.updateEntities();

    test_entity.removeComponent(DialogueComponent);
    try std.testing.expect(!test_entity.hasComponent(DialogueComponent));


    ec_context.deinitEntity(test_entity);

    try std.testing.expect(dialogue_comp_init);
    try std.testing.expect(dialogue_comp_deinit);
    try std.testing.expect(dialogue_comp_update);

    try std.testing.expect(has_test_entity_init);
    try std.testing.expect(has_test_entity_deinit);
    try std.testing.expect(has_test_entity_updated);
}

test "tag list test" {
    const Tags = ec.TagList(2);
    const tag_list = Tags.initFromSlice(&.{ "test", "okay" });
    try std.testing.expectEqual(2, tag_list.tag_count);
    try std.testing.expectEqualStrings("test", tag_list.tags[0]);
    try std.testing.expect(tag_list.hasTag("test"));
    try std.testing.expectEqualStrings("okay", tag_list.tags[1]);
    try std.testing.expect(tag_list.hasTag("okay"));
}

test "object data db read and write test" {
    const allocator = std.testing.allocator;
    var data_db_inst = data_db.ObjectDataDB.init(allocator);
    defer data_db_inst.deinit();
    const temp_object = try data_db_inst.createObject("Test");
    defer allocator.free(temp_object.name);
    try data_db_inst.writeProperty(temp_object, "age", i32, 8);
    const age_property_optional = data_db_inst.findProperty(temp_object, "age");
    const age_property = age_property_optional.?;
    try std.testing.expectEqual(8, age_property.value.integer);
    defer data_db_inst.removeProperty(temp_object, age_property);
    const old_age = try data_db_inst.readProperty(temp_object, "age", i32);
    try std.testing.expectEqual(8, old_age);

    try data_db_inst.writeProperty(temp_object, "name", []const u8, "Daniel");
    defer data_db_inst.removePropertyByKey(temp_object, "name");
    const name = try data_db_inst.readProperty(temp_object, "name", []const u8);
    try std.testing.expectEqualStrings("Daniel", name);

    const temp_object2 = try data_db_inst.createObject("Test2");
    defer allocator.free(temp_object2.name);
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
    const json_string = try std.json.stringifyAlloc(allocator, object_list, .{ .whitespace = .indent_2 });
    defer allocator.free(json_string);
    try std.testing.expectEqualStrings(json_to_parse,json_string);
    // std.debug.print("json_string = \n{s}\n", .{ json_string });
}
