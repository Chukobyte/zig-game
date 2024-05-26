const std = @import("std");

const math = @import("zeika").math;

const engine = @import("engine");
const game = @import("game");

const data_db = engine.data_db;
const core = engine.core;
const ecs = engine.ecs;
const string = engine.string;

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

    pub fn init(self: *TestEntityInterface, context: *ECSContext, entity: ECSContext.Entity) void {
        _ = self; _ = context; _ = entity;
        has_called_init = true;
    }
    pub fn deinit(self: *TestEntityInterface, context: *ECSContext, entity: ECSContext.Entity) void {
        _ = self; _ = context; _ = entity;
        has_called_deinit = true;
    }
    pub fn tick(self: *TestEntityInterface, context: *ECSContext, entity: ECSContext.Entity) void {
        _ = self; _ = context; _ = entity;
        has_called_tick = true;
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
    pub fn getComponentTypes() []const type { return &.{ DialogueComponent, TransformComponent }; }
};

pub fn ArchetypeList(system_types: []const type, comp_types: []const type) type {
    const CompTypeList = ecs.TypeList(comp_types);
    return struct {

        pub fn getIndex(component_types: []const type) comptime_int {
            const types_sig = CompTypeList.getFlags(component_types);
            const archetype_list_data: []ArchetypeListData = generateArchetypeListData();
            for (0..archetype_list_data.len) |i| {
                const list_data = archetype_list_data[i];
                if (types_sig == list_data.signature) {
                    return i;
                }
            }
            @compileError("Didn't pass in valid component types!");
        }

        pub fn getSortIndex(component_types: []const type) comptime_int {
            const arch_index = getIndex(component_types);
            const archetype_list_data: []ArchetypeListData = generateArchetypeListData();
            const list_data = &archetype_list_data[arch_index];
            main: for (0..list_data.num_of_sorted_components) |i| {
                for (0..list_data.num_of_components) |comp_i| {
                    if (comp_types[comp_i] != list_data.sorted_components[i][comp_i]) {
                        continue :main;
                    }
                }
                return i;
            }
            @compileError("Didn't pass in valid component types for sort index!");
        }

        pub fn getArchetypeCount() comptime_int {
            const archetype_list_data: []ArchetypeListData = generateArchetypeListData();
            return archetype_list_data.len;
        }

        const ArchetypeListData = struct {
            const sorted_components_max = 4;
            const components_max = 16;

            signature: usize,
            num_of_components: usize,
            num_of_sorted_components: usize = 0,
            sorted_components: [sorted_components_max][components_max] type = undefined,
        };

        inline fn generateArchetypeListData() []ArchetypeListData {
            var archetypes_count: usize = 0;
            var archetype_list_data: [comp_types.len * comp_types.len]ArchetypeListData = undefined;

            main: for (system_types) |T| {
                if (@hasDecl(T, "getArchetype")) {
                    const component_types = T.getArchetype();
                    const archetype_sig = CompTypeList.getFlags(component_types);

                    // Check if signature exists
                    var add_new_archetype = true;
                    for (0..archetypes_count) |arch_i| {
                        const list_data = &archetype_list_data[arch_i];
                        // It does exist, now determine if we need to add new sorted components
                        if (archetype_sig == list_data.signature) {
                            add_new_archetype = false;
                            for (0..list_data.num_of_sorted_components) |i| {
                                var is_duplicate = true;
                                for (0..list_data.num_of_components) |comp_i| {
                                    if (component_types[comp_i] != list_data.sorted_components[i][comp_i]) {
                                        is_duplicate = false;
                                        break;
                                    }
                                }
                                // If it's a duplicate skip
                                if (is_duplicate) {
                                    continue :main;
                                }
                            }
                            // No duplicates found, create new sorted comps row
                            for (0..list_data.num_of_sorted_components) |i| {
                                list_data.sorted_components[list_data.num_of_sorted_components][i] = component_types[i];
                            }
                            list_data.num_of_sorted_components += 1;
                            continue :main;
                        }
                    }

                    // Now that it doesn't exist add it
                    archetype_list_data[archetypes_count] = ArchetypeListData{ .signature = archetype_sig, .num_of_components = component_types.len, .num_of_sorted_components = 1 };
                    for (0..component_types.len) |i| {
                        archetype_list_data[archetypes_count].sorted_components[0][i] = component_types[i];
                    }

                    archetypes_count += 1;
                }
            }
            return archetype_list_data[0..archetypes_count];
        }
    };
}

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

    const ArcList = ArchetypeList(&.{ TestSystem0, TestSystem1, TestSystem2 }, &.{ TestComp0, TestComp1, TestComp2 });
    try std.testing.expectEqual(2, ArcList.getArchetypeCount());
    try std.testing.expectEqual(0, ArcList.getIndex(TestArchetype0));
    try std.testing.expectEqual(1, ArcList.getIndex(TestArchetype1));
    try std.testing.expectEqual(0, ArcList.getSortIndex(TestArchetype0));
    // try std.testing.expectEqual(0, ArcList.getSortIndex(TestArchetype1));
}

test "type list test" {
    const TestType0 = struct {};
    const TestType1 = struct {};
    const TestType2 = struct {};

    const TestTypeList = ecs.TypeList(&.{ TestType0, TestType1, TestType2 });
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
    .systems = &.{ TestECSystem },
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

    // Test entity interface
    try std.testing.expectEqual(0, new_entity);
    try std.testing.expectEqual(true, TestEntityInterface.has_called_init);
    try std.testing.expectEqual(false, TestEntityInterface.has_called_tick);
    ecs_context.tick();
    try std.testing.expectEqual(true, TestEntityInterface.has_called_tick);
    ecs_context.deinitEntity(new_entity);
    try std.testing.expectEqual(false, ecs_context.isEntityValid(new_entity));
    try std.testing.expectEqual(true, TestEntityInterface.has_called_deinit);

    ecs_context.render();

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
    const Tags = ecs.TagList(2);
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
    try std.testing.expectEqual(.stack, test_string2.mode);
    try std.testing.expectEqualStrings("Some nice text", test_string2.get());
    defer test_string2.deinit();
}
