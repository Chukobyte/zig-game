///! A generic data base to store data and serialize it

const std = @import("std");

const misc = @import("misc.zig");

const ArrayListUtils = misc.ArrayListUtils;

inline fn isValidPropertyType(comptime T: type) bool {
    return T == i32 or T == bool or T == f32 or T == []const u8 or T == []u8;
}

const ObjectError = error{
    FailedToFindProperty,
};

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

    pub fn Handle(comptime T: type) type {
        if (!isValidPropertyType(T)) {
            @compileError("Didn't pass in valid type to property handle!");
        }
        return struct {
            property: *Property,
            key: []const u8,
            data_db: *ObjectDataDB,
            object: *Object = undefined,

            pub inline fn write(self: *@This(), value: T) !void {
                try self.data_db.writeProperty(self.object, self.key, T, value);
            }

            pub inline fn read(self: *const @This()) !T {
                return try self.data_db.readProperty(self.object, self.key, T);
            }
        };
    }
};

pub const Object = struct {
    id: u32,
    name: []u8,
    properties: std.ArrayList(Property),
    subobjects: std.ArrayList(*Object),
    parent: ?*Object = null,

    pub const Handle = struct {
        object: *Object,
        data_db: *ObjectDataDB,

        pub inline fn writeProperty(self: *@This(), key: []const u8, comptime T: type, value: T) !void {
            try self.data_db.writeProperty(self.object, key, T, value);
        }

        pub inline fn readProperty(self: *@This(), key: []const u8, comptime T: type) !T {
            try self.data_db.readProperty(self.object, key, T);
        }
    };
};

pub const ObjectDataDB = struct {

    objects: std.ArrayList(Object), // All objects
    root_objects: std.ArrayList(*Object), // All top level root objects (no parents)
    allocator: std.mem.Allocator,
    object_ids_index: u32 = 1,

    pub const ReadWriteMode = enum {
        binary,
        json,
    };

    pub const SerializeParams = struct {
        file_path: []const u8,
        mode: ReadWriteMode,
    };

    pub const DeserializeParams = struct {
        file_path: []const u8,
        mode: ReadWriteMode,
    };

    pub const CreateObjectParams = struct {
        name: []const u8,
        parent: ?*Object = null,
    };

    pub fn init(allocator: std.mem.Allocator) @This() {
        return ObjectDataDB{
            .objects = std.ArrayList(Object).initCapacity(allocator, 100) catch unreachable,
            .root_objects = std.ArrayList(*Object).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.objects.items) |*object| {
            self.deleteObject(object); // TODO: Can use a more efficient code path but this if fine for now...
        }
        self.objects.deinit();
        self.root_objects.deinit();
    }

    pub fn serialize(self: *@This(), params: SerializeParams) !void {
        const SizeT = usize;
        const file_path = params.file_path;
        const write_mode = params.mode;

        const objects_list = ObjectsListT(*Object){ .objects = self.root_objects.items[0..] };
        const file = try std.fs.createFileAbsolute(file_path, .{});
        defer file.close();

        const json_string = try std.json.stringifyAlloc(self.allocator, objects_list, .{ .whitespace = .indent_2 });
        defer self.allocator.free(json_string);

        switch (write_mode) {
            .binary => {
                var bytes = try self.allocator.alloc(u8, @sizeOf(SizeT) + json_string.len);
                defer self.allocator.free(bytes);
                std.mem.writeInt(SizeT, bytes[0..@sizeOf(SizeT)], json_string.len, .little); // Serialize the length
                std.mem.copyForwards(u8, bytes[@sizeOf(SizeT)..], json_string); // Serialize the json string
                _ = try file.write(bytes);
            },
            .json => try file.writeAll(json_string),
        }
    }

    pub fn deserialize(self: *@This(), params: SerializeParams) !void {
        const SizeT = usize;
        const file_path = params.file_path;
        const read_mode = params.mode;

        const file = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_only });
        defer file.close();

        const bytes = try file.readToEndAlloc(self.allocator, 2048);
        defer self.allocator.free(bytes);

        const json_string = switch (read_mode) {
            .binary => bytes[@sizeOf(SizeT)..],
            .json => bytes,
        };

        // std.debug.print("file_contents = \n--------------------------------\n{s}\n--------------------------------\n", .{ json_string });

        const parsed = try std.json.parseFromSlice(ObjectsList,self.allocator, json_string, .{});
        defer parsed.deinit();
        const object_list: ObjectsList = parsed.value;
        try self.importObjects(object_list.objects);
    }

    pub fn createObject(self: *@This(), params: CreateObjectParams) std.mem.Allocator.Error!*Object {
        var new_object: *Object = try self.objects.addOne(); // TODO: Check for resize and update root_objects ArrayList
        new_object.id = self.object_ids_index;
        new_object.name = try self.allocator.dupe(u8, params.name);
        new_object.properties = std.ArrayList(Property).init(self.allocator);
        new_object.subobjects = std.ArrayList(*Object).init(self.allocator);
        new_object.parent = params.parent;
        if (new_object.parent) |parent| {
            try parent.subobjects.append(new_object);
        } else {
            try self.root_objects.append(new_object);
        }
        self.object_ids_index += 1;
        return new_object;
    }

    pub fn createObjectFromType(self: *@This(), comptime T: type, value: *const T, params: CreateObjectParams) std.mem.Allocator.Error!*Object {
        const obj: *Object = self.findObject(params.name) orelse try self.createObject(params);
        try self.copyObjectFromType(T, value, obj);
        return obj;
    }

    pub fn copyObjectFromType(self: *@This(), comptime T: type, value: *const T, object: *Object) !void {
        self.clearObject(object);
        inline for (@typeInfo(T).Struct.fields) |field| {
            if (comptime isValidPropertyType(field.type)) {
                try self.writeProperty(object, field.name, field.type, @field(value, field.name));
            }
        }
    }

    pub fn copyTypeFromObject(self: *@This(), object: *const Object, comptime T: type, value: *T) !void {
        inline for (@typeInfo(T).Struct.fields) |field| {
            if (comptime isValidPropertyType(field.type)) {
                if (self.readProperty(object, field.name, field.type) catch null) |read_value| {
                    if (comptime field.type == []u8) {
                        @field(value, field.name) = try self.allocator.dupe(u8, read_value);
                    } else {
                        @field(value, field.name) = read_value;
                    }
                }
            }
        }
    }

    pub fn importObjects(self: *@This(), objects: []const Object) !void {
        for (objects) |*obj| {
            const imported_object = try self.findOrAddObject(.{ .name = obj.name });
            try self.copyObject(imported_object, obj);
        }
    }

    pub fn copyObject(self: *@This(), dest: *Object, src: *const Object) !void {
        dest.id = src.id;
        for (src.properties.items) |prop| {
            try dest.properties.append(prop);
            dest.properties.items[dest.properties.items.len - 1].key = try self.allocator.dupe(u8, prop.key);
            if (dest.properties.items[dest.properties.items.len - 1].type == .string) {
                dest.properties.items[dest.properties.items.len - 1].value.string = try self.allocator.dupe(u8, prop.value.string);
            }
        }
        // TODO: Copy subobjects
        // for (src.subobjects) |subobj| {}
    }

    /// Finds the first object by name
    pub fn findObject(self: *@This(), name: []const u8) ?*Object {
        for (self.objects.items) |*object| {
            if (std.mem.eql(u8, name, object.name)) {
                return object;
            }
        }
        return null;
    }

    pub fn findOrAddObject(self: *@This(), params: CreateObjectParams) !*Object {
        if (self.findObject(params.name)) |object| {
            return object;
        }
        return try self.createObject(params);
    }

    /// Recursive function to delete an object and all its subobjects
    pub fn deleteObject(self: *@This(), object: *Object) void {
        for (object.subobjects.items) |subobj| {
            self.deleteObject(subobj);
        }
        for (object.properties.items) |*prop| {
            self.removeProperty(object, prop);
        }
        object.properties.deinit();
        object.subobjects.deinit();
        self.allocator.free(object.name);
        if (object.parent != null) {
            var found_index: ?u32 = null;
            for (self.root_objects.items) |obj| {
                if (obj.id == object.id) {
                    found_index = obj.id;
                }
            }
            if (found_index) |index| {
                _ = self.root_objects.swapRemove(index);
            }
        }
        ArrayListUtils.removeByValue(Object, &self.objects, object);
    }

    /// Clears all properties and subobjects from an object
    pub fn clearObject(self: *@This(), object: *Object) void {
        for (object.subobjects.items) |subobj| {
            self.deleteObject(subobj);
        }
        for (object.properties.items) |*prop| {
            self.removeProperty(object, prop);
        }
        object.properties.clearAndFree();
        object.subobjects.clearAndFree();
    }

    /// Finds the first object by name
    pub fn deleteObjectByName(self: *@This(), name: []const u8) void {
        if (ArrayListUtils.findIndexByPred2(
            Object,
            []const u8,
            &self.objects,
            &name,
            struct { pub fn removeIf(obj_name: *const []const u8, obj: *const Object) bool { return std.mem.eql(u8, obj_name.*, obj.name); } }.removeIf
        )) |i| {
            self.deleteObject(&self.objects.items[i]);
        }
    }

    /// Checks if there is atleast one object with the passed in name
    pub fn hasObject(self: *@This(), name: []const u8) bool {
        return ArrayListUtils.findIndexByPred2(
            Object,
            []const u8,
            &self.objects,
            &name,
            struct { pub fn removeIf(obj_name: *const []const u8, obj: *const Object) bool { return std.mem.eql(u8, obj_name.*, obj.name); } }.removeIf
        ) != null;
    }

    pub fn writeProperty(self: *@This(), object: *Object, key: []const u8, comptime T: type, value: T) !void {
        if (!isValidPropertyType(T)) { @compileError("value is not a valid property type!"); }

        const currentProperty: *Property = try findOrAddProperty(self, T, object, key);
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

    pub fn readProperty(self: *@This(), object: *const Object, key: []const u8, comptime T: type) ObjectError!T {
        if (!isValidPropertyType(T)) { @compileError("value is not a value property type!"); }

        if (findProperty(self, object, key)) |property| {
            switch (comptime @typeInfo(T)) {
                .Bool => return property.value.boolean,
                .Int => return property.value.integer,
                .Float => return property.value.float,
                .Pointer => return property.value.string,
                else => {},
            }
        }
        return ObjectError.FailedToFindProperty;
    }

    pub fn readPropertyUnchecked(self: *@This(), object: *const Object, key: []const u8, comptime T: type) ?T {
        return self.readProperty(object, key, T) catch return null;
    }

    pub fn findProperty(self: *@This(), object: *const Object, key: []const u8) ?*Property {
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

    pub fn removeProperty(self: *@This(), object: *Object, property: *Property) void {
        self.removePropertyByKey(object, property.key);
    }

    pub fn removePropertyByKey(self: *@This(), object: *Object, key: []const u8) void {
        var remove_index: ?usize = null;
        var i: usize = 0;
        while (i < object.properties.items.len) : (i += 1) {
            if (std.mem.eql(u8, key, object.properties.items[i].key)) {
                remove_index = i;
                break;
            }
        }
        if (remove_index) |index| {
            const removed_prop = object.properties.items[index];
            if (removed_prop.type == .string) {
                self.allocator.free(removed_prop.value.string);
            }
            self.allocator.free(removed_prop.key);
            _ = object.properties.swapRemove(index);
        }
    }

    pub fn createPropertyHandle(self: *@This(), object: *Object, comptime T: type, key: []const u8) !Property.Handle(T) {
        const HandleT = Property.Handle(T);
        const prop = try self.findOrAddProperty(T, object, key);
        const handle = HandleT{
            .property = prop,
            .key = key,
            .data_db = self,
            .object = object,
        };
        return handle;
    }
};

pub fn ObjectsListT(comptime ObjectT: type) type {
    return struct {
        objects: []ObjectT = undefined,

        pub fn jsonStringify(self: *const @This(), out: anytype) !void {
            try out.beginObject();
            try out.objectField("objects");
            try out.beginArray();
            for (self.objects) |*object| {
                if (comptime ObjectT == *Object) {
                    try jsonWriteObject(object.*, out);
                } else {
                    try jsonWriteObject(object, out);
                }
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

        fn jsonNextAlloc(comptime T: type, alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !T {
            if (!isValidPropertyType(T) and T != []u8 and T != u32) { @compileError("value is not a value property type!"); }

            const token: std.json.Token = try source.nextAlloc(alloc, options.allocate orelse .alloc_always);
            switch (@typeInfo(T)) {
                .Bool => {
                    switch (token) {
                        .true => return true,
                        .false => return false,
                        else => unreachable,
                    }
                },
                .Int => {
                    switch (token) {
                        .number, .partial_number, .allocated_number => |v| {
                            const parsedInt = try std.fmt.parseInt(T, v, 10);
                            if (token == .allocated_number) {
                                alloc.free(token.allocated_number);
                            }
                            return parsedInt;
                        },
                        else => unreachable,
                    }
                },
                .Float => {
                    switch (token) {
                        .number, .partial_number, .allocated_number => |v| {
                            const parsedFloat = try std.fmt.parseFloat(T, v, 10);
                            if (token == .allocated_number) {
                                alloc.free(token.allocated_number);
                            }
                            return parsedFloat;
                        },
                        else => unreachable,
                    }
                },
                .Pointer => {
                    switch (token) {
                        .string, .allocated_string => |v| {
                            const parsedString = try alloc.dupe(u8, v);
                            if (token == .allocated_string) {
                                alloc.free(token.allocated_string);
                            }
                            return parsedString;
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            }
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
                .array_begin => {},
                else => unreachable,
            }
            while (true) {
                // Object begin
                switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                    .object_begin => {},
                    .array_end => return object_buffer.allocateSlice(alloc), // Empty object array
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
                // Parse Id
                const id_key: []u8 = try jsonNextAlloc([]u8, alloc, source, options);
                std.debug.assert(std.mem.eql(u8, "id", id_key));
                defer alloc.free(id_key);
                const object_id: u32 = try jsonNextAlloc(u32, alloc, source, options);

                // Parse properties
                var properties_array: [16]Property = undefined;
                var properties_count: usize = 0;
                {
                    // First parse properties key token
                    const prop_array_key: []u8 = try jsonNextAlloc([]u8, alloc, source, options);
                    std.debug.assert(std.mem.eql(u8, "properties", prop_array_key));
                    defer alloc.free(prop_array_key);
                    // Now parse array
                    switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                        .array_begin => {},
                        else => unreachable,
                    }
                    // Now parse properties
                    parse_objects: while (true) {
                        switch (try source.nextAlloc(alloc, options.allocate orelse .alloc_always)) {
                            .object_begin => {},
                            .array_end => break :parse_objects, // Stop parsing properties since we reached end of array
                            else => unreachable,
                        }
                        var property: Property = Property{ .key = undefined, .type = undefined, .value = undefined };
                        // Parse key key
                        const prop_key_key: []u8 = try jsonNextAlloc([]u8, alloc, source, options);
                        std.debug.assert(std.mem.eql(u8, "key", prop_key_key));
                        defer alloc.free(prop_key_key);
                        // Parse key value
                        property.key = try jsonNextAlloc([]u8, alloc, source, options);
                        // Parse value key
                        const prop_key_value: []u8 = try jsonNextAlloc([]u8, alloc, source, options);
                        std.debug.assert(std.mem.eql(u8, "value", prop_key_value));
                        defer alloc.free(prop_key_value);
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
                            .object_end => {},
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
                    .object_end => {},
                    .array_end => break,
                    else => unreachable,
                }
            }
            return object_buffer.allocateSlice(alloc);
        }
    };
}

pub const ObjectsList = ObjectsListT(Object);
