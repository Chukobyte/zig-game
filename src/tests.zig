const std = @import("std");

const math = @import("zeika").math;

const data_db = @import("engine/object_data_db.zig");
const ec = @import("engine/entity_component/entity_component.zig");
const core = @import("game/core.zig");
const game = @import("game/game.zig");

const World = core.World;
const Entity = core.Entity;
const ObjectsList = data_db.ObjectsList;
const Object = data_db.Object;
const Property = data_db.Property;

var entity_has_entered_scene = false;
var entity_has_exited_scene = false;

const DialogueComponent = struct {
    text: []const u8,
};

const TransformComponent = struct {
    transform: math.Transform2D,
};

var has_test_entity_init = false;
var has_test_entity_deinit = false;
var has_test_entity_updated = false;

test "type list test" {
    const TestTypeList = ec.TypeList(&.{ DialogueComponent, TransformComponent });
    try std.testing.expectEqual(0, TestTypeList.getIndex(DialogueComponent));
    try std.testing.expectEqual(1, TestTypeList.getIndex(TransformComponent));
    try std.testing.expectEqual(DialogueComponent, TestTypeList.getType(0));
    try std.testing.expectEqual(TransformComponent, TestTypeList.getType(1));
}

test "entity component test" {
    const TestECContext = ec.ECContext(u32, &.{ DialogueComponent, TransformComponent });
    var ec_context = TestECContext.init(std.testing.allocator);
    defer ec_context.deinit();

    const test_entity_template = TestECContext.Entity{
        .interface = .{
            .init = struct {
                pub fn init(self: *TestECContext.Entity) void {
                    _ = self;
                    has_test_entity_init = true;
                }
            }.init,
            .deinit = struct {
                pub fn deinit(self: *TestECContext.Entity) void {
                    _ = self;
                    has_test_entity_deinit = true;
                }
            }.deinit,
            .update = struct {
                pub fn update(self: *TestECContext.Entity) void {
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
    var dialogue_comp = DialogueComponent{ .text = "Test speech!" };
    try std.testing.expect(!test_entity.hasComponent(DialogueComponent));
    try test_entity.setComponent(DialogueComponent, &dialogue_comp);
    try std.testing.expect(test_entity.hasComponent(DialogueComponent));

    if (test_entity.getComponent(DialogueComponent)) |found_comp| {
        try std.testing.expectEqualStrings("Test speech!", found_comp.text);
    }

    test_entity.removeComponent(DialogueComponent);
    try std.testing.expect(!test_entity.hasComponent(DialogueComponent));

    ec_context.updateEntities();

    ec_context.deinitEntity(test_entity.id.?);

    try std.testing.expect(has_test_entity_init);
    try std.testing.expect(has_test_entity_deinit);
    try std.testing.expect(has_test_entity_updated);
}

test "world test" {
    var world = World.init(std.testing.allocator);
    const entity_id = try world.registerEntity(
        .{
            .tag_list = Entity.Tags.initFromSlice(&.{ "test" }),
            .interface = .{
                .on_enter_scene = struct {
                    pub fn on_enter_scene(self: *Entity) void { _ = self; entity_has_entered_scene = true; }
                }.on_enter_scene,
                .on_exit_scene = struct {
                    pub fn on_exit_scene(self: *Entity) void { _ = self; entity_has_exited_scene = true; }
                }.on_exit_scene,
            },
        }
    );
    const test_entity = world.getEntityByTag("test").?;
    try std.testing.expectEqual(entity_id, test_entity.id.?);
    world.unregisterEntity(entity_id);
    defer world.deinit();

    try std.testing.expect(entity_has_entered_scene);
    try std.testing.expect(entity_has_exited_scene);
}

test "tag list test" {
    const tag_list = Entity.Tags.initFromSlice(&.{ "test", "okay" });
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
