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
            .Array => return PropertyType.string, // TODO: Handle strings
            else => { @compileError("Unsupported type"); },
        }
    }
};

const PropertyValue = union(PropertyType) {
    boolean: bool,
    integer: i32,
    float: f64,
    string: []const u8,
};

const Property = struct {
    name: []const u8,
    type: PropertyType,
    value: PropertyValue,
};

const Object = struct {
    id: u32,
    name: []const u8,
    properties: std.ArrayList(Property),
    sub_objects: std.ArrayList(Object),
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
            object.sub_objects.deinit();
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
        new_object.name = name;
        new_object.properties = std.ArrayList(Property).init(self.allocator);
        new_object.sub_objects = std.ArrayList(Object).init(self.allocator);
        self.object_ids_index += 1;
        return new_object;
    }

    pub fn writeProperty(self: *@This(), object: *Object, name: []const u8, comptime T: type, value: T) !void {
        _ = self;
        if (!isValidPropertyType(T)) {
            @compileError("value is not a value property type!");
        }

        const currentProperty: *Property = try findOrAddProperty(T, object, name);
        switch (comptime @typeInfo(T)) {
            .Bool => currentProperty.value = PropertyValue{ .boolean = value },
            .Int => currentProperty.value = PropertyValue{ .integer = value },
            .Float => currentProperty.value = PropertyValue{ .float = value },
            .Array => {}, // TODO: Handle strings
            else => {},
        }
    }

    // pub fn readProperty(self: *@This(), object: *Object, name: []const u8, comptime T: type) !T {
    //     _ = self;
    //     if (!isValidPropertyType(T)) {
    //         @compileError("value is not a value property type!");
    //     }
    //
    //     if (findProperty(object, name)) |property| {
    //         const propertyType: PropertyType = PropertyType.getTypeFromRealType(T);
    //         switch (propertyType) {
    //         .boolean => return property.value.boolean,
    //         .integer => return property.value.integer,
    //         .float => return property.value.float,
    //         .string => return property.value.string,
    //         }
    //     }
    //     return null;
    // }

    fn findProperty(object: *Object, name: []const u8) ?*Property {
        for (object.properties.items) |*property| {
            if (std.mem.eql(u8, property.name, name)) {
                return property;
            }
        }
        return null;
    }

    fn findOrAddProperty(comptime T: type, object: *Object, name: []const u8) !*Property {
        var property: ?*Property = findProperty(object, name);
        if (property == null) {
            property = try object.properties.addOne();
            property.?.name = name;
            property.?.type = PropertyType.getTypeFromRealType(T);
        }
        return property.?;
    }

    inline fn isValidPropertyType(comptime T: type) bool {
        return T == i32 or T == bool or T == f32 or T == []const u8;
    }
};
