const std = @import("std");

const data_db = @import("engine/object_data_db.zig");

test "object data db test" {
    var data_db_inst = data_db.ObjectDataDB.init(std.heap.page_allocator);
    defer data_db_inst.deinit();
    const temp_object = try data_db_inst.createObject("Test");
    try data_db_inst.writeProperty(temp_object, "age", i32, 8);
    if (data_db_inst.readProperty(temp_object, "age", i32)) |old_age| {
        try std.testing.expect(old_age == 8);
    }

    const temp_object2 = try data_db_inst.createObject("Test2");
    try data_db_inst.addAsSubObject(temp_object, temp_object2);
    try std.testing.expect(temp_object.sub_objects.items.len == 1);
}

test "json test" {
    const allocator = std.testing.allocator;
    const GameObject = struct {
        name: []u8 = undefined,
        id: i32 = undefined,
        subobjects: []const @This() = undefined,
    };

    const GameObjectList = struct {
        objects: []GameObject,

        // TODO: Clean up memory
        pub fn deinit(self: *const @This()) void {
            _ = self;
        }

        pub fn jsonStringify(self: *const @This(), out: anytype) !void {
            const json_fmt =
                \\{
                \\    "objects": [
                \\        {
                \\            "name": "{s}",
                \\            "id": {d},
                \\            "subobjects": []
                \\        }
                \\    ]
                \\}}
            ;
            return out.print(json_fmt, .{ self.name, self.id });
        }

        // Recursive
        fn jsonParseNextObjectsArray(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) ![]GameObject {
            const ObjectBuffer = struct {
                data: [24]GameObject = undefined,
                len: usize = 0,

                pub fn add(self: *@This(), object: GameObject) void {
                    self.data[self.len] = object;
                    self.len += 1;
                }

                pub fn allocateSlice(self: *@This(), a: std.mem.Allocator) ![]GameObject {
                    const new_slice = try a.alloc(GameObject, self.len);
                    std.mem.copyForwards(GameObject, new_slice, self.data[0..self.len]);
                    return new_slice;
                }
            };

            var object_buffer = ObjectBuffer{};
            const objects_key_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
            if (!(objects_key_token == .string or objects_key_token == .allocated_string)) { unreachable; }
            switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                .array_begin => {
                    std.debug.print("expected objects array begin\n", .{});
                },
                else => unreachable,
            }
            while (true) {
                // Object begin
                switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                    .object_begin => {
                        std.debug.print("expected object begin\n", .{});
                    },
                    .array_end => {
                        std.debug.print("no objects in array, skipping\n", .{});
                        return &[_]GameObject{};
                    },
                    else => unreachable,
                }
                // Parse Name
                var object_name: []u8 = undefined;
                const name_key_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
                if (!(name_key_token == .string or name_key_token == .allocated_string)) { unreachable; }
                const name_value_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
                switch (name_value_token) {
                    .string, .allocated_string => |v| {
                        object_name = try alloc.dupe(u8, v);
                    },
                    else => unreachable,
                }
                std.debug.print("Object name = {s}\n", .{ object_name });
                // Parse Id
                var object_id: i32 = undefined;
                const id_key_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
                if (!(id_key_token == .string or name_key_token == .allocated_string)) { unreachable; }
                const id_value_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
                switch (id_value_token) {
                    .number, .partial_number, .allocated_number => |v| { object_id = try std.fmt.parseInt(i32, v, 10); },
                    else => unreachable,
                }
                std.debug.print("Object id = {d}\n", .{ object_id });

                // Parse subobjects
                const subobjects_slice = try jsonParseNextObjectsArray(alloc, source, options);

                // Create game object and add to buffer
                object_buffer.add(GameObject{ .name = object_name, .id = object_id, .subobjects = subobjects_slice});

                // Object End
                switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                    .object_end => {
                        std.debug.print("expected object end\n", .{});
                    },
                    .array_end => {
                        std.debug.print("expected array end only for top most object list\n", .{});
                    },
                    else => |v| {
                        std.debug.print("v = {any}", .{ v });
                        unreachable;
                    },
                }
                break;
            }
            return object_buffer.allocateSlice(alloc);
        }

        pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
            if (.object_begin != try source.next()) { return error.UnexpectedToken; }

            const objects = try jsonParseNextObjectsArray(alloc, source, options);

            // Verify we parse all tokens
            while (true) {
                switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                    .end_of_document => { break; },
                    else => {},
                }
            }

            return @This(){ .objects = objects };
        }
    };

    const jsonToParse =
        \\{
        \\    "objects": [
        \\        { "name": "Mike", "id": 42, "subobjects": [ { "name": "Gary", "id": 28, "subobjects": [] } ] }
        \\    ]
        \\}
        ;
    const parsed = try std.json.parseFromSlice(GameObjectList,allocator, jsonToParse, .{});
    defer parsed.deinit();

    const game_object_list: GameObjectList = parsed.value;
    defer game_object_list.deinit();
    const first_game_object: *GameObject = &game_object_list.objects[0];
    try std.testing.expect(std.mem.eql(u8, first_game_object.name, "Mike"));
    try std.testing.expect(first_game_object.id == 42);
    try std.testing.expect(game_object_list.objects.len == 1);
    try std.testing.expect(first_game_object.subobjects.len == 1);
    const game_subobject = first_game_object.subobjects[0];
    try std.testing.expect(std.mem.eql(u8, game_subobject.name, "Gary"));
    try std.testing.expect(game_subobject.id == 28);
    try std.testing.expect(game_subobject.subobjects.len == 0);
}
