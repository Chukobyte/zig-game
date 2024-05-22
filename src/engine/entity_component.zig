const std = @import("std");

const zeika = @import("zeika");

const Renderer = zeika.Renderer;

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

pub fn TypeList(comptime types: []const type) type {
    return struct {
        pub fn getType(index: comptime_int) type {
            if (index < 0 or index >= types.len) {
                @compileError("Passed in index is out of range");
            }
            return types[index];
        }

        pub fn getIndex(comptime T: type) usize {
            inline for (types, 0..types.len) |t, i| {
                if (t == T) {
                    return i;
                }
            }
            @compileError("No index found for type!");
        }
    };
}

/// cast anyopaque pointer to passed in type
pub inline fn ptrCompCast(comptime T: type, ptr: *anyopaque) *T {
    return @alignCast(@ptrCast(ptr));
}

/// cast comp pointer to anyopaque type
pub inline fn constCompCast(comptime T: type, comp: *const T) *anyopaque {
    return @as(*anyopaque, @constCast(@ptrCast(comp)));
}

fn EntityT(comptime IdType: type, comptime component_types: []const type, tag_max: comptime_int) type {

    return struct {
        const EntityTRef = @This();
        const ComponentTypeList = TypeList(component_types);

        pub const Component = struct {
            pub const Interface = struct {
                init: ?*const fn(*anyopaque, *EntityTRef) void = null,
                deinit: ?*const fn(*anyopaque, *EntityTRef) void = null,
                update: ?*const fn(*anyopaque, *EntityTRef) void = null,
                render: ?*const fn(*anyopaque, *EntityTRef) void = null,
            };

            pub const State = enum {
                inactive,
                active,
            };

            data: ?*anyopaque = null,
            interface: Component.Interface = .{},
            state: State = .inactive,

            pub fn createInterface(comptime T: type) Component.Interface {
                var interface: Component.Interface = .{};
                if (@hasDecl(T, "init")) {
                    interface.init = @field(T, "init");
                }
                if (@hasDecl(T, "deinit")) {
                    interface.deinit = @field(T, "deinit");
                }
                if (@hasDecl(T, "update")) {
                    interface.update = @field(T, "update");
                }
                if (@hasDecl(T, "render")) {
                    interface.render = @field(T, "render");
                }

                return interface;
            }
        };

        pub const Id = IdType;

        pub const Interface = struct {
            init: ?*const fn(self: *EntityTRef) void = null,
            deinit: ?*const fn(self: *EntityTRef) void = null,
            update: ?*const fn(self: *EntityTRef) void = null,
        };

        id: ?Id = null,
        allocator: std.mem.Allocator = undefined,

        tag_list: ?TagList(tag_max) = null,
        interface: Interface = .{},
        components: [component_types.len]Component = undefined,

        pub fn updateComponents(self: *@This()) void {
            for (&self.components) |*comp| {
                if (comp.data) |comp_data| {
                    if (comp.interface.update) |comp_update| {
                        comp_update(comp_data, self);
                    }
                }
            }
        }

        pub fn renderComponents(self: *@This()) void {
            for (&self.components) |*comp| {
                if (comp.data) |comp_data| {
                    if (comp.interface.render) |render| {
                        render(comp_data, self);
                    }
                }
            }
        }

        pub fn setComponent(self: *@This(), comptime T: type, component: *const T) !void {
            const comp_index: usize = ComponentTypeList.getIndex(T);
            if (!hasComponent(self, T)) {
                const new_comp: *T = try self.allocator.create(T);
                new_comp.* = component.*;
                self.components[comp_index].data = new_comp;
                if (self.components[comp_index].interface.init) |comp_init| {
                    comp_init(self.components[comp_index].data.?, self);
                }
            }
            // TODO: Set when has a component
        }

        pub fn setComponentByIndex(self: *@This(), index: comptime_int, component: *anyopaque) !void {
            if (self.components[index].data == null) {
                const T: type = ComponentTypeList.getType(index);
                const new_comp: *T = try self.allocator.create(T);
                const comp_ptr: *T = ptrCompCast(T, component);
                new_comp.* = comp_ptr.*;
                self.components[index].data = new_comp;
                if (self.components[index].interface.init) |comp_init| {
                    comp_init(self.components[index].data.?, self);
                }
            }
            // TODO: Set when has a component
        }

        pub fn getComponent(self: *@This(), comptime T: type) ?*T {
            const comp_index: usize = ComponentTypeList.getIndex(T);
            if (self.components[comp_index].data) |comp| {
                return ptrCompCast(T, comp);
            }
            return null;
        }

        pub fn removeComponent(self: *@This(), comptime T: type) void {
            if (hasComponent(self, T)) {
                const comp_index: usize = ComponentTypeList.getIndex(T);
                if (self.components[comp_index].interface.deinit) |comp_deinit| {
                    comp_deinit(self.components[comp_index].data.?, self);
                }
                const comp_ptr: *T = ptrCompCast(T, self.components[comp_index].data.?);
                self.allocator.destroy(comp_ptr);
                self.components[comp_index].data = null;
            }
        }

        pub fn hasComponent(self: *@This(), comptime T: type) bool {
            const comp_index: usize = ComponentTypeList.getIndex(T);
            return self.components[comp_index].data != null;
        }
    };
}


pub fn ECContext(comptime IdType: type, comptime component_types: []const type) type {
    const type_list = TypeList(component_types);
    const tag_max = 4;
    return struct {
        pub const Tags = TagList(tag_max);
        pub const Entity = EntityT(IdType, component_types, tag_max);

        pub const EntityTemplate = struct {
            tag_list: ?Tags = null,
            interface: Entity.Interface = .{},
            components: [component_types.len]?*anyopaque = undefined,
        };

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
        pub fn initEntity(self: *@This(), entity_template: *const EntityTemplate) !*Entity {
            const new_entity: *Entity = try self.entities.addOne();
            new_entity.allocator = self.allocator;
            new_entity.id = self.id_counter;
            new_entity.tag_list = entity_template.tag_list;
            new_entity.interface = entity_template.interface;
            // Setup components
            inline for (entity_template.components, 0..component_types.len) |component_optional, i| {
                const CompT = type_list.getType(i);
                new_entity.components[i] = Entity.Component{ .interface = Entity.Component.createInterface(CompT) };
                if (component_optional) |component| {
                    try new_entity.setComponentByIndex(i, component);
                }
            }
            self.id_counter += 1;
            // Initialize components before entity
            if (new_entity.interface.init) |entity_init| {
                entity_init(new_entity);
            }
            return new_entity;
        }

        pub inline fn deinitEntity(self: *@This(), entity: *Entity) void {
            self.deinitEntityById(entity.id.?);
        }

        pub fn deinitEntityById(self: *@This(), id: Entity.Id) void {
            if (self.getEntity(id)) |entity| {
                if (entity.interface.deinit) |entity_deinit| {
                    entity_deinit(entity);
                }
                // Attempt to remove all component
                inline for (component_types) |CompT| {
                    entity.removeComponent(CompT);
                }
                // TODO: Remove from entities array list
            }
        }

        pub fn updateEntities(self: *@This()) void {
            for (self.entities.items) |*entity| {
                if (entity.interface.update) |entity_update| {
                    entity_update(entity);
                }
                entity.updateComponents();
            }
        }

        pub fn renderEntities(self: *@This()) void {
            for (self.entities.items) |*entity| {
                entity.renderComponents();
            }
        }

        pub fn getEntity(self: *@This(), id: Entity.Id) ?*Entity {
            for (self.entities.items) |*entity| {
                if (id == entity.id.?) {
                    return entity;
                }
            }
            return null;
        }

        /// Returns first entity that matches a tag
        pub fn getEntityByTag(self: *@This(), tag: []const u8) ?*Entity {
            for (self.entities.items) |*entity| {
                if (entity.tag_list) |tag_list| {
                    if (tag_list.hasTag(tag)) {
                        return entity;
                    }
                }
            }
            return null;
        }
    };
}
