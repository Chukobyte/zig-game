///! A generic data base to store data and serialize it

const std = @import("std");

pub const PropertyType = enum {
    boolean,
    integer,
    float,
    string,
    // buffer,
    // sub_objects,

    pub fn getTypeFromRealType(real_type: type) PropertyType {
        switch (@typeInfo(real_type)) {
            .Bool => return PropertyType.boolean,
            .Int => return PropertyType.integer,
            .Float => return PropertyType.float,
            .Pointer => return PropertyType.string,
            else => { @compileError("Unsupported type"); },
        }
    }
};

pub const PropertyValue = union(PropertyType) {
    boolean: bool,
    integer: i32,
    float: f32,
    string: []u8,
};

pub const Property = struct {
    key: []u8,
    type: PropertyType,
    value: PropertyValue,
    has_ever_been_written_to: bool = false,
};

pub const Object = struct {
    //{
    //  "name": "object_name",
    //  "properties": [],
    //  "subobjects": []
    //{

    id: u32,
    name: []u8,
    properties: std.ArrayList(Property),
    subobjects: std.ArrayList(*Object),
};

pub const ObjectDataDB = struct {
    objects: std.ArrayList(Object),
    allocator: std.mem.Allocator,
    object_ids_index: u32 = 1,

    pub const FileOutputType = enum {
        binary,
        json,
    };

    pub const FileReadConfig = struct {
        file_path: []const u8,
    };

    pub const FileWriteConfig = struct {
        file_path: []const u8,
        output_type: FileOutputType = FileOutputType.json,
    };

    pub fn init(allocator: std.mem.Allocator) @This() {
        return ObjectDataDB{
            .objects = std.ArrayList(Object).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.objects.items) |object| {
            object.properties.deinit();
            object.subobjects.deinit();
        }
        self.objects.deinit();
    }

    pub fn readFromFile(self: *@This(), read_config: FileReadConfig) void {
        _ = self;
        _ = read_config;
    }

    pub fn writeToFile(self: *@This(), write_config: FileWriteConfig) void {
        _ = self;
        _ = write_config;
    }

    pub fn createObject(self: *@This(), name: []const u8) std.mem.Allocator.Error!*Object {
        var new_object: *Object = try self.objects.addOne();
        new_object.id = self.object_ids_index;
        new_object.name = try self.allocator.dupe(u8, name);
        new_object.properties = std.ArrayList(Property).init(self.allocator);
        new_object.subobjects = std.ArrayList(*Object).init(self.allocator);
        self.object_ids_index += 1;
        return new_object;
    }

    pub fn addAsSubObject(self: *@This(), object: *Object, sub_object: *Object) !void {
        _ = self;
        try object.subobjects.append(sub_object);
    }

    pub fn writeProperty(self: *@This(), object: *Object, name: []const u8, comptime T: type, value: T) !void {
        if (!isValidPropertyType(T)) { @compileError("value is not a value property type!"); }

        const currentProperty: *Property = try findOrAddProperty(self, T, object, name);
        switch (comptime @typeInfo(T)) {
            .Bool => currentProperty.value = PropertyValue{ .boolean = value },
            .Int => currentProperty.value = PropertyValue{ .integer = value },
            .Float => currentProperty.value = PropertyValue{ .float = value },
            .Pointer => {
                if (currentProperty.has_ever_been_written_to) {
                    self.allocator.free(currentProperty.value.string);
                }
                currentProperty.value = PropertyValue{ .string = try self.allocator.dupe(u8, value) };
            },
            else => { unreachable; },
        }
        currentProperty.has_ever_been_written_to = true;
    }

    pub fn readProperty(self: *@This(), object: *Object, name: []const u8, comptime T: type) ?T {
        if (!isValidPropertyType(T)) { @compileError("value is not a value property type!"); }

        if (findProperty(self, object, name)) |property| {
            switch (comptime @typeInfo(T)) {
                .Bool => return property.value.boolean,
                .Int => return property.value.integer,
                .Float => return property.value.float,
                .Pointer => return property.value.string,
                else => {},
            }
        }
        return null;
    }

    fn findProperty(self: *@This(), object: *Object, key: []const u8) ?*Property {
        _ = self;
        for (object.properties.items) |*property| {
            if (std.mem.eql(u8, property.key, key)) {
                return property;
            }
        }
        return null;
    }

    fn findOrAddProperty(self: *@This(), comptime T: type, object: *Object, key: []const u8) !*Property {
        if (!isValidPropertyType(T)) { @compileError("value is not a value property type!"); }

        var property: ?*Property = findProperty(self, object, key);
        if (property == null) {
            property = try object.properties.addOne();
            property.?.key = try self.allocator.dupe(u8, key);
            property.?.type = PropertyType.getTypeFromRealType(T);
        }
        return property.?;
    }

    inline fn isValidPropertyType(comptime T: type) bool {
        return T == i32 or T == bool or T == f32 or T == []const u8;
    }
};

pub const ObjectsList = struct {
    objects: []Object = undefined,

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    pub fn jsonStringify(self: *const @This(), out: anytype) !void {
        try out.beginObject();
        try out.objectField("objects");
        try out.beginArray();
        for (self.objects) |*object| {
            try jsonWriteObject(object, out);
        }
        try out.endArray();
        try out.endObject();
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

    // Recursive
    fn jsonWriteObject(object: *Object, out: anytype) !void {
        try out.beginObject();

        try out.objectField("name");
        try out.write(object.name);
        try out.objectField("id");
        try out.write(object.id);
        // Properties
        try out.objectField("properties");
        try out.beginArray();
        for (object.properties.items) |*property| {
            try out.beginObject();
            try out.objectField("key");
            try out.write(property.key);
            try out.objectField("value");
            switch (property.type) {
            .boolean => try out.write(property.value.boolean),
            .integer => try out.write(property.value.integer),
            .float => try out.write(property.value.float),
            .string => try out.write(property.value.string),
            }
            try out.endObject();
        }
        try out.endArray();

        // Subobjects
        try out.objectField("subobjects");
        try out.beginArray();
        for (object.subobjects.items) |subobject| {
            try jsonWriteObject(subobject, out);
        }
        try out.endArray();

        try out.endObject();
    }

    // Recursive
    fn jsonParseNextObjectsArray(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) ![]Object {
        const ObjectBuffer = struct {
            data: [24]Object = undefined,
            len: usize = 0,

            pub fn add(self: *@This(), object: Object) void {
                self.data[self.len] = object;
                self.len += 1;
            }

            pub fn allocateSlice(self: *@This(), a: std.mem.Allocator) ![]Object {
                const new_slice = try a.alloc(Object, self.len);
                std.mem.copyForwards(Object, new_slice, self.data[0..self.len]);
                return new_slice;
            }
        };

        var object_buffer = ObjectBuffer{};
        const objects_key_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
        if (!(objects_key_token == .string or objects_key_token == .allocated_string)) { std.debug.print("objects_key_token {any}\n", .{ objects_key_token }); unreachable; }
        switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
            .array_begin => { std.debug.print("expected objects array begin\n", .{}); },
            else => unreachable,
        }
        while (true) {
            // Object begin
            switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                .object_begin => { std.debug.print("expected object begin\n", .{}); },
                .array_end => {
                    std.debug.print("no objects in array, skipping\n", .{});
                    return object_buffer.allocateSlice(alloc);
                },
                else => unreachable,
            }
            // Parse Name
            var object_name: []u8 = undefined;
            const name_key_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
            if (!(name_key_token == .string or name_key_token == .allocated_string)) { unreachable; }
            const name_value_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
            switch (name_value_token) {
                .string, .allocated_string => |v| { object_name = try alloc.dupe(u8, v); },
                else => unreachable,
            }
            std.debug.print("Object name = {s}\n", .{ object_name });
            // Parse Id
            var object_id: u32 = undefined;
            const id_key_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
            if (!(id_key_token == .string or name_key_token == .allocated_string)) { unreachable; }
            const id_value_token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
            switch (id_value_token) {
                .number, .partial_number, .allocated_number => |v| { object_id = try std.fmt.parseInt(u32, v, 10); },
                else => unreachable,
            }
            std.debug.print("Object id = {d}\n", .{ object_id });

            // Parse properties
            var properties_array: [16]Property = undefined;
            var properties_count: usize = 0;
            {
                // First parse properties key token
                switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                    .string, .allocated_string => { std.debug.print("expected property key\n", .{}); },
                    else => unreachable,
                }
                // Now parse array
                switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                    .array_begin => { std.debug.print("expected property array begin\n", .{}); },
                    else => unreachable,
                }
                // Now parse property
                parse_objects: while (true) {
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .object_begin => { std.debug.print("expected property object begin\n", .{}); },
                        .array_end => { std.debug.print("expected property array end, breaking...\n", .{}); break :parse_objects; },
                        else => unreachable,
                    }
                    var property: Property = Property{ .key = undefined, .type = undefined, .value = undefined };
                    // Parse key key
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .string, .allocated_string => { std.debug.print("expected key string\n", .{}); },
                        else => unreachable,
                    }
                    // Parse key value
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .string, .allocated_string => |v| { property.key = try alloc.dupe(u8, v); },
                        else => unreachable,
                    }
                    // Parse value key
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .string, .allocated_string => { std.debug.print("expected value string\n", .{}); },
                        else => unreachable,
                    }
                    // Parse value value
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .true => {
                            property.type = .boolean;
                            property.value = PropertyValue{ .boolean = true };
                        },
                        .false => {
                            property.type = .boolean;
                            property.value = PropertyValue{ .boolean = false };
                        },
                        .string, .allocated_string => |v| {
                            property.type = .string;
                            property.value = PropertyValue{ .string = try alloc.dupe(u8, v) };
                        },
                        .number, .partial_number, .allocated_number => |v| {
                            if(std.json.isNumberFormattedLikeAnInteger(v)) {
                                property.type = .integer;
                                property.value = PropertyValue{ .integer = try std.fmt.parseInt(i32, v, 10) };
                            } else {
                                property.type = .float;
                                property.value = PropertyValue{ .float = try std.fmt.parseFloat(f32, v) };
                            }
                        },
                        else => unreachable,
                    }
                    property.has_ever_been_written_to = true;
                    properties_array[properties_count] = property;
                    properties_count += 1;
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .object_end => { std.debug.print("expected property object end\n", .{}); },
                        else => unreachable,
                    }
                }
            }
            const properties_slice = properties_array[0..properties_count];

            // Parse subobjects
            const subobjects_slice = try jsonParseNextObjectsArray(alloc, source, options);

            // Create game object and add to buffer
            var new_object = Object{ .name = object_name, .id = object_id, .properties = std.ArrayList(Property).init(alloc), .subobjects = std.ArrayList(*Object).init(alloc) };
            // Add properties
            for (properties_slice) |prop| {
                // const copied_prop = try alloc.create(Property);
                // copied_prop.* = prop;
                try new_object.properties.append(prop);
            }
            // Add subobjects
            for (subobjects_slice) |object| {
                const copied_object = try alloc.create(Object);
                copied_object.* = object;
                try new_object.subobjects.append(copied_object);
            }
            object_buffer.add(new_object);

            // Object End
            switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                .object_end => {
                    std.debug.print("expected object end\n", .{});
                },
                .array_end => {
                    std.debug.print("expected array end only for top most object list\n", .{});
                    break;
                },
                else => |v| {
                    std.debug.print("v = {any}", .{ v });
                    unreachable;
                },
            }
        }
        return object_buffer.allocateSlice(alloc);
    }
};
