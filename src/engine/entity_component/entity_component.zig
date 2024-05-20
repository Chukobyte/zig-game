const std = @import("std");

pub fn TagList(max_tags: comptime_int) type {
    return struct {
        tags: [max_tags][]const u8 = undefined,
        tag_count: usize = 0,

        pub fn initFromSlice(tags: []const []const u8) @This() {
            var tag_list = @This(){};
            for (tags) |tag| {
                tag_list.addTag(tag) catch { std.debug.print("Skipping adding tag due to being at the limit '{d}'", .{ max_tags }); };
            }
            return tag_list;
        }

        pub fn addTag(self: *@This(), tag: []const u8) !void {
            if (self.tag_count >= max_tags) {
                return error.OutOfTagSpace;
            }
            self.tags[self.tag_count] = tag;
            self.tag_count += 1;
        }

        pub fn getTags(self: *const @This()) [][]const u8 {
            return self.tags[0..self.tag_count];
        }

        pub fn hasTag(self: *const @This(), tag: []const u8) bool {
            for (self.tags) |current_tag| {
                if (std.mem.eql(u8, tag, current_tag)) {
                    return true;
                }
            }
            return false;
        }
    };
}

pub fn EntityT(comptime IdType: type, comptime ComponentInterface: anytype, tag_max: comptime_int, component_max: comptime_int) type {

    return struct {
        const EntityTRef = @This();

        const Interface = struct {
            init: ?*const fn(self: *EntityTRef) void = null,
            deinit: ?*const fn(self: *EntityTRef) void = null,
            update: ?*const fn(self: *EntityTRef) void = null,
        };

        id: ?IdType = null,
        tag_list: ?TagList(tag_max) = null,
        allocator: std.mem.Allocator = undefined,

        components: [component_max]?*anyopaque = undefined,
        interface: Interface = .{},

        pub inline fn setComponent(self: *@This(), comptime T: type, component: *T) !void {
            try ComponentInterface.setComponent(self, self.allocator, T, component);
        }

        pub inline fn getComponent(self: *@This(), comptime T: type) ?*T {
            return ComponentInterface.getComponent(self, T);
        }

        pub inline fn removeComponent(self: *@This(), comptime T: type) void {
            ComponentInterface.removeComponent(self, self.allocator, T);
        }

        pub inline fn hasComponent(self: *@This(), comptime T: type) bool {
            return ComponentInterface.hasComponent(self, T);
        }
    };
}


pub fn ECContext(comptime IdType: type, comptime ComponentInterface: anytype, comptime component_types: []const type) type {
    return struct {
        pub const total_components: comptime_int = component_types.len;

        pub const Entity = EntityT(IdType, ComponentInterface, 4, total_components);

        allocator: std.mem.Allocator,
        entities: std.ArrayList(Entity),
        id_counter: IdType = 0,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return @This(){
                .allocator = allocator,
                .entities = std.ArrayList(Entity).init(allocator),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.entities.deinit();
        }

        /// Creates an entity using the passed in template, only really copying components for now
        pub fn initEntity(self: *@This(), entity_template: *const Entity) !*Entity {
            const new_entity: *Entity = try self.entities.addOne();
            new_entity.* = entity_template.*;
            new_entity.allocator = self.allocator;
            new_entity.id = self.id_counter;
            self.id_counter += 1;
            if (new_entity.interface.init) |entity_init| {
                entity_init(new_entity);
            }
            return new_entity;
        }

        pub fn deinitEntity(self: *@This(), id: IdType) void {
            if (self.getEntity(id)) |entity| {
                if (entity.interface.deinit) |entity_deinit| {
                    entity_deinit(entity);
                }
            }
        }

        pub fn updateEntities(self: *@This()) void {
            for (self.entities.items) |*entity| {
                if (entity.interface.update) |entity_update| {
                    entity_update(entity);
                }
            }
        }

        pub fn getEntity(self: *@This(), id: IdType) ?*Entity {
            for (self.entities.items) |*entity| {
                if (id == entity.id.?) {
                    return entity;
                }
            }
            return null;
        }
    };
}
