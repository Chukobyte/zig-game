const std = @import("std");

const math = @import("zeika").math;

const engine = @import("engine");
const game = @import("game");

const data_db = engine.data_db;
const core = engine.core;
const ecs = engine.ecs;
const string = engine.string;
const misc = engine.misc;

const ObjectsList = data_db.ObjectsList;
const Object = data_db.Object;
const Property = data_db.Property;

const DialogueComponent = struct {
    text: []const u8,
};

const TransformComponent = struct {
    transform: math.Transform2D,
};

const TestEntityInterface = struct {
    var has_called_init = false;
    var has_called_deinit = false;
    var has_called_tick = false;
    var has_called_idle_increment = false;

    default_num: i32 = 10,

    pub fn init(_: *TestEntityInterface, _: *ECSContext, _: ECSContext.Entity) void {
        has_called_init = true;
    }
    pub fn deinit(_: *TestEntityInterface, _: *ECSContext, _: ECSContext.Entity) void {
        has_called_deinit = true;
    }
    pub fn tick(_: *TestEntityInterface, _: *ECSContext, _: ECSContext.Entity) void {
        has_called_tick = true;
    }
    pub fn idleIncrement(_: *TestEntityInterface, _: *ECSContext, _: ECSContext.Entity) void {
        has_called_idle_increment = true;
    }
};

const TestECSystem = struct {
    var has_called_init = false;
    var has_called_deinit = false;
    var has_called_pre_context_tick = false;
    var has_called_post_context_tick = false;
    var has_called_render = false;
    var has_called_entity_registered = false;
    var has_called_entity_unregistered = false;

    pub fn init(self: *TestECSystem, context: *ECSContext) void {
        _ = self; _ = context;
        has_called_init = true;
    }
    pub fn deinit(self: *TestECSystem, context: *ECSContext) void {
        _ = self; _ = context;
        has_called_deinit = true;
    }
    pub fn preContextTick(self: *TestECSystem, context: *ECSContext) void {
        _ = self; _ = context;
        has_called_pre_context_tick = true;
    }
    pub fn postContextTick(self: *TestECSystem, context: *ECSContext) void {
        _ = self; _ = context;
        has_called_post_context_tick = true;
    }
    pub fn render(self: *TestECSystem, context: *ECSContext) void {
        _ = self; _ = context;
        has_called_render = true;
    }
    pub fn onEntityRegistered(self: *TestECSystem, context: *ECSContext, entity: ECSContext.Entity) void {
        _ = self; _ = context; _ = entity;
        has_called_entity_registered = true;
    }
    pub fn onEntityUnregistered(self: *TestECSystem, context: *ECSContext, entity: ECSContext.Entity) void {
        _ = self; _ = context; _ = entity;
        has_called_entity_unregistered = true;
    }
    pub fn getArchetype() []const type { return &.{ DialogueComponent, TransformComponent }; }
    };

const TestECSystem2 = struct {
    pub fn getArchetype() []const type { return &.{ TransformComponent, DialogueComponent }; }
};

test "archetype test" {
    const TestComp0 = struct {};
    const TestComp1 = struct {};
    const TestComp2 = struct {};

    const TestSystem0 = struct {
        pub fn getArchetype() []const type {
            return &.{ TestComp0, TestComp1 };
        }
    };
    const TestSystem1 = struct {
        pub fn getArchetype() []const type {
            return &.{ TestComp0, TestComp2 };
        }
    };
    const TestSystem2 = struct {
        pub fn getArchetype() []const type {
            return &.{ TestComp2, TestComp0 };
        }
    };

    const TestArchetype0 = &.{ TestComp0, TestComp1 };
    const TestArchetype1 = &.{ TestComp0, TestComp2 };

    const ArcList = ecs.ArchetypeList(&.{ TestSystem0, TestSystem1, TestSystem2 }, &.{ TestComp0, TestComp1, TestComp2 });
    try std.testing.expectEqual(2, ArcList.getArchetypeCount());
    try std.testing.expectEqual(0, ArcList.getIndex(TestArchetype0));
    try std.testing.expectEqual(1, ArcList.getIndex(TestArchetype1));
    try std.testing.expectEqual(0, ArcList.getSortIndex(TestArchetype0));
    try std.testing.expectEqual(0, ArcList.getSortIndex(TestArchetype1));
    try std.testing.expectEqual(1, ArcList.getSortIndex(&.{ TestComp2, TestComp0 }));
}

test "type list test" {
    const TestType0 = struct {};
    const TestType1 = struct {};
    const TestType2 = struct {};

    const TestTypeList = misc.TypeList(&.{ TestType0, TestType1, TestType2 });
    try std.testing.expectEqual(0, TestTypeList.getIndex(TestType0));
    try std.testing.expectEqual(1, TestTypeList.getIndex(TestType1));
    try std.testing.expectEqual(TestType0, TestTypeList.getType(0));
    try std.testing.expectEqual(TestType1, TestTypeList.getType(1));
    try std.testing.expectEqual(3, TestTypeList.getFlags(&.{ TestType0, TestType1 }));
    try std.testing.expectEqual(3, TestTypeList.getFlags(&.{ TestType1, TestType0 }));
}

const ECSContext = ecs.ECSContext(.{
    .entity_type = usize,
    .entity_interfaces = &.{ TestEntityInterface },
    .components = &.{ DialogueComponent, TransformComponent },
    .systems = &.{ TestECSystem, TestECSystem2 },
});

test "ecs test" {
    const Entity = ECSContext.Entity;
    const WeakEntityRef = ECSContext.WeakEntityRef;

    var ecs_context = try ECSContext.init(std.testing.allocator);

    try std.testing.expectEqual(false, ecs_context.isEntityValid(0));
    const new_entity: Entity = try ecs_context.initEntity(.{ .interface = TestEntityInterface });
    try std.testing.expectEqual(true, ecs_context.isEntityValid(0));

    // Test component state
    try std.testing.expectEqual(false, ecs_context.hasComponent(new_entity, DialogueComponent));
    try std.testing.expectEqual(false, ecs_context.isComponentEnabled(new_entity, DialogueComponent));
    try ecs_context.setComponent(new_entity, DialogueComponent, &.{ .text = "Testing things!" });
    try std.testing.expectEqual(true, ecs_context.hasComponent(new_entity, DialogueComponent));
    try std.testing.expectEqual(true, ecs_context.isComponentEnabled(new_entity, DialogueComponent));
    ecs_context.setComponentEnabled(new_entity, DialogueComponent, false);
    try std.testing.expectEqual(false, ecs_context.isComponentEnabled(new_entity, DialogueComponent));

    // Test before adding component for entity to register to test system
    try std.testing.expectEqual(false, TestECSystem.has_called_entity_registered);
    try std.testing.expectEqual(false, ecs_context.isComponentEnabled(new_entity, TransformComponent));
    try ecs_context.setComponent(new_entity, TransformComponent, &.{ .transform = math.Transform2D.Identity });
    try std.testing.expectEqual(true, ecs_context.isComponentEnabled(new_entity, TransformComponent));
    try std.testing.expectEqual(true, TestECSystem.has_called_entity_registered);

    try std.testing.expectEqual(1, ecs_context.getArchetypeEntities(&.{ DialogueComponent, TransformComponent }).len);

    // Component iterator tests
    const ComponentIterator = ECSContext.ArchetypeComponentIterator;
    var comp_iterator = ComponentIterator(&.{ DialogueComponent, TransformComponent }).init(&ecs_context);
    try std.testing.expectEqual(true, comp_iterator.peek() != null);
    try std.testing.expectEqual(true, comp_iterator.next() != null);
    try std.testing.expectEqual(true, comp_iterator.peek() == null);
    try std.testing.expectEqual(true, comp_iterator.next() == null);

    comp_iterator = ComponentIterator(&.{ DialogueComponent, TransformComponent }).init(&ecs_context);
    try std.testing.expectEqual(0, comp_iterator.getSlot(DialogueComponent));
    try std.testing.expectEqual(1, comp_iterator.getSlot(TransformComponent));
    while (comp_iterator.next()) |iter| {
        const iter_dialogue_comp = iter.getValue(0);
        const iter_dialogue_comp2 = iter.getComponent(DialogueComponent);
        const iter_trans_comp = iter.getValue(1);
        const iter_trans_comp2 = iter.getComponent(TransformComponent);
        try std.testing.expectEqual(iter_dialogue_comp, iter_dialogue_comp2);
        try std.testing.expectEqual(iter_trans_comp, iter_trans_comp2);
    }
    // Changing order
    var comp_iterator2 = ComponentIterator(&.{ TransformComponent, DialogueComponent }).init(&ecs_context);
    try std.testing.expectEqual(0, comp_iterator2.getSlot(TransformComponent));
    try std.testing.expectEqual(1, comp_iterator2.getSlot(DialogueComponent));
    while (comp_iterator2.next()) |iter| {
        const iter_trans_comp = iter.getValue(0);
        const iter_trans_comp2 = iter.getComponent(TransformComponent);
        const iter_dialogue_comp = iter.getValue(1);
        const iter_dialogue_comp2 = iter.getComponent(DialogueComponent);
        try std.testing.expectEqual(iter_trans_comp, iter_trans_comp2);
        try std.testing.expectEqual(iter_dialogue_comp, iter_dialogue_comp2);
        try std.testing.expectEqual(0, iter.getEntity());
    }

    // Using context to generate iterator
    var comp_iterator3 = ecs_context.compIter(&.{ TransformComponent, DialogueComponent });
    while (comp_iterator3.next()) |iter| {
        const iter_trans_comp = iter.getValue(0);
        const iter_trans_comp2 = iter.getComponent(TransformComponent);
        const iter_dialogue_comp = iter.getValue(1);
        const iter_dialogue_comp2 = iter.getComponent(DialogueComponent);
        try std.testing.expectEqual(iter_trans_comp, iter_trans_comp2);
        try std.testing.expectEqual(iter_dialogue_comp, iter_dialogue_comp2);
    }


    // Test entity interface
    const test_entity_interface_ptr: ?*TestEntityInterface = ecs_context.getEntityInterfacePtr(TestEntityInterface, new_entity);
    try std.testing.expectEqual(true, test_entity_interface_ptr != null);
    try std.testing.expectEqual(10, test_entity_interface_ptr.?.default_num);

    try std.testing.expectEqual(0, new_entity);
    try std.testing.expectEqual(true, TestEntityInterface.has_called_init);
    try std.testing.expectEqual(false, TestEntityInterface.has_called_tick);
    ecs_context.event(.tick);
    try std.testing.expectEqual(true, TestEntityInterface.has_called_tick);
    try std.testing.expectEqual(false, TestEntityInterface.has_called_idle_increment);
    ecs_context.event(.idle_increment);
    try std.testing.expectEqual(true, TestEntityInterface.has_called_idle_increment);
    ecs_context.deinitEntity(new_entity);
    try std.testing.expectEqual(false, ecs_context.isEntityValid(new_entity));
    try std.testing.expectEqual(false, TestEntityInterface.has_called_deinit);
    ecs_context.newFrame();
    try std.testing.expectEqual(true, TestEntityInterface.has_called_deinit);

    ecs_context.event(.render);

    // Test weak entity ref
    const new_entity2: Entity = try ecs_context.initEntity(.{});
    var weak_entity2_ref = WeakEntityRef{ .id = new_entity2, .context = &ecs_context };
    try std.testing.expectEqual(true, weak_entity2_ref.isValid());
    try std.testing.expectEqual(false, weak_entity2_ref.hasComponent(TransformComponent));
    try weak_entity2_ref.setComponent(TransformComponent, &.{ .transform = .{} });
    try std.testing.expectEqual(true, weak_entity2_ref.hasComponent(TransformComponent));
    const entity2_transform_comp = weak_entity2_ref.getComponent(TransformComponent);
    try std.testing.expectEqual(true, entity2_transform_comp != null);
    try weak_entity2_ref.removeComponent(TransformComponent);
    try std.testing.expectEqual(false, weak_entity2_ref.hasComponent(TransformComponent));
    weak_entity2_ref.deinit();
    try std.testing.expectEqual(false, weak_entity2_ref.isValid());

    // Test system interface
    ecs_context.deinit();
    try std.testing.expectEqual(true, TestECSystem.has_called_init);
    try std.testing.expectEqual(true, TestECSystem.has_called_deinit);
    try std.testing.expectEqual(true, TestECSystem.has_called_pre_context_tick);
    try std.testing.expectEqual(true, TestECSystem.has_called_post_context_tick);
    try std.testing.expectEqual(true, TestECSystem.has_called_render);
    try std.testing.expectEqual(true, TestECSystem.has_called_entity_registered);
    try std.testing.expectEqual(true, TestECSystem.has_called_entity_unregistered);
}

test "tag list test" {
    const Tags = misc.TagList(2);
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
    const temp_object = try data_db_inst.createObject(.{ .name = "Test" });
    try std.testing.expectEqual(true, data_db_inst.hasObject("Test"));
    try data_db_inst.writeProperty(temp_object, "age", i32, 8);
    const age_property_optional = data_db_inst.findProperty(temp_object, "age");
    const age_property = age_property_optional.?;
    try std.testing.expectEqual(8, age_property.value.integer);
    const old_age = try data_db_inst.readProperty(temp_object, "age", i32);
    try std.testing.expectEqual(8, old_age);

    try data_db_inst.writeProperty(temp_object, "name", []const u8, "Daniel");
    const name = try data_db_inst.readProperty(temp_object, "name", []const u8);
    try std.testing.expectEqualStrings("Daniel", name);

    // Test adding subobject
    _ = try data_db_inst.createObject(.{ .name = "Test2", .parent = temp_object });
    try std.testing.expect(temp_object.subobjects.items.len == 1);

    var age_handle = try data_db_inst.createPropertyHandle(temp_object, i32, "age");
    try std.testing.expectEqual(8, age_handle.read());
    try age_handle.write(32);
    try std.testing.expectEqual(32, age_handle.read());

    data_db_inst.deleteObjectByName("Test");
    try std.testing.expectEqual(false, data_db_inst.hasObject("Test"));
    try std.testing.expectEqual(false, data_db_inst.hasObject("Test2"));

    // Serialize test
    const SimpleStruct = struct {
        num: i32,
    };

    var simple = SimpleStruct{ .num = 99 };
    const simple_object = try data_db_inst.createObject(.{ .name = "Simple" });
    try data_db_inst.copyObjectFromType(SimpleStruct, &simple, simple_object);
    const simple_object_prop = data_db_inst.findProperty(simple_object, "num");
    try std.testing.expect(simple_object_prop != null);
    try std.testing.expectEqual(99, simple_object_prop.?.value.integer);

    const simple_object2 = try data_db_inst.createObjectFromType(SimpleStruct, &.{ .num = 66 }, .{ .name = "Simple2" });
    try std.testing.expectEqual(66, data_db_inst.findProperty(simple_object2, "num").?.value.integer);

    var simple_copy = SimpleStruct{ .num = undefined };
    try data_db_inst.copyTypeFromObject(simple_object, SimpleStruct, &simple_copy);
    try std.testing.expectEqual(99, simple_copy.num);
    var simple2 = SimpleStruct{ .num = undefined };
    try data_db_inst.copyTypeFromObject(simple_object2, SimpleStruct, &simple2);
    try std.testing.expectEqual(66, simple2.num);
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

test "string test" {
    const allocator = std.testing.allocator;
    var test_string = string.String8.init(allocator);
    defer test_string.deinit();
    try std.testing.expectEqual(true, test_string.isEmpty());
    try test_string.set("StackOk", .{});
    try std.testing.expectEqual(false, test_string.isEmpty());
    try std.testing.expectEqual(.stack, test_string.mode);
    try std.testing.expectEqualStrings("StackOk", test_string.get());
    try test_string.set("String on heap!", .{});
    try std.testing.expectEqual(.heap, test_string.mode);
    try std.testing.expectEqualStrings("String on heap!", test_string.buffer);

    const test_string2 = try string.String16.initAndSet(allocator, "Some nice text", .{});
    defer test_string2.deinit();
    try std.testing.expectEqual(.stack, test_string2.mode);
    try std.testing.expectEqualStrings("Some nice text", test_string2.get());

    var test_string3 = string.String16.init(allocator);
    defer test_string3.deinit();
    try std.testing.expectEqualStrings("", test_string3.buffer);
    try test_string3.set("More text yay!", .{});
    try std.testing.expectEqualStrings("More text yay!", test_string3.buffer);
    try test_string3.set("One more", .{});
    try std.testing.expectEqualStrings("One more", test_string3.buffer);
}

test "persistent state test" {
    const PersistentState = game.state.PersistentState;
    const allocator = std.testing.allocator;

    const state = PersistentState.init(allocator);
    defer state.deinit();

    const BigInt = PersistentState.BigInt;

    var other = BigInt.init(allocator);
    var result = BigInt.init(allocator);
    defer other.deinit();
    defer result.deinit();

    try state.food.setString("3000");
    try other.setString("1000");
    try result.add(&state.food, &other);
    var result_string = try result.toString(allocator);
    try state.food.setString(result_string);
    try std.testing.expectEqualStrings("4000", result_string);
    allocator.free(result_string);

    try result.addScalar(&state.food, 8000);
    result_string = try result.toString(allocator);
    try std.testing.expectEqualStrings("12000", result_string);
    allocator.free(result_string);
}

test "array list utils test" {
    const ArrayListUtils = misc.ArrayListUtils;

    const allocator = std.testing.allocator;
    var num_list = std.ArrayList(i32).init(allocator);
    defer num_list.deinit();

    for ([_]i32{ 1, 2, 3 }) |i| {
        try num_list.append(i);
    }
    const not_found_index = ArrayListUtils.findIndexByValue(i32, &num_list, &-1);
    try std.testing.expectEqual(true, not_found_index == null);
    const three_index = ArrayListUtils.findIndexByValue(i32, &num_list, &3);
    try std.testing.expectEqual(true, three_index != null);

    const one_index = ArrayListUtils.findIndexByPred(i32, &num_list, &1, struct {
        pub fn isEqual(a: *const i32, b: *const i32) bool {
            return a.* == b.*;
        }
    }.isEqual);
    try std.testing.expectEqual(true, one_index != null);
}
