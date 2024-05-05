const std = @import("std");

// const zeika = @import("zeika");

pub fn ECS(types: anytype) void {
    comptime {
        // Validation
        if (types.len == 0) {
            @compileError("Can't pass an empty struct into ECS");
        }
        // switch(@typeInfo(types)) {
        // .Struct, .Union, .ErrorSet, .Enum => {},
        // else => @compileError("Can't pass an empty struct into ECS"),
        // }
        const fields = std.meta.fields(@TypeOf(types));
        if (fields.len == 0) {
            @compileError("Must pass in at least one type field!");
        }
        for (fields) |field| {
            // const value = @field(types, field.name);
            _ = @field(types, field.name);
            // @compileLog("value: {}", value);
            // if (!std.meta.trait.isType(field.field_type)) {
            //     @compileError("All fields must be types. Field '" ++ field.name ++ "' is not a type.");
            // }
        }
    }
}
