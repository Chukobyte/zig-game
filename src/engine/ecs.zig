///! Entity Component System module

const std = @import("std");

pub fn TagList(max_tags: comptime_int) type {
    return struct {
        tags: [max_tags][]const u8 = undefined,
        tag_count: usize = 0,

        pub fn initFromSlice(tags: []const []const u8) @This() {
            var tag_list = @This(){};
            for (tags) |tag| {
                tag_list.addTag(tag) catch { std.debug.print("Skipping adding tag due to being at the limit '{d}'", .{ max_tags }); break; };
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
        const len = types.len;

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

        pub fn getFlag(comptime T: type) usize {
            return @as(usize, 1) << @as(u6, @intCast(getIndex(T)));
        }

        pub fn getFlags(comptime flag_types: []const type) usize {
            var flags: usize = 0;
            for (flag_types) |flag_type| {
                flags |= getFlag(flag_type);
            }
            return flags;
        }
    };
}

fn FlagUtils(comptime T: type) type {
    return struct {
        pub inline fn hasFlag(flags: T, flag: T) bool {
            return (flags & flag) != 0;
        }

        pub inline fn containsFlags(flags: T, required_flags: T) bool {
            return (flags & required_flags) == required_flags;
        }

        pub inline fn setFlag(flags: *T, flag: T) void {
            flags.* = flags.* | flag;
        }

        pub inline fn removeFlag(flags: *T, flag: T) void {
            flags.* = flags.* & ~flag;
        }

        pub inline fn clearFlags(flags: *T) void {
            flags = @as(T, 0);
        }
    };
}

fn TypeBitMask(comptime types: []const type) type {
    const MaskType = usize;
    const size = types.len;
    if (size > @bitSizeOf(MaskType)) {
        @compileLog("Doesn't support bit masks higher than usize (for now), size = {d}, usize = {d}", .{ size, @bitSizeOf(MaskType) });
    }

    const flag_utils = FlagUtils(MaskType);
    const type_list = TypeList(types);

    return struct {
        enabled_mask: MaskType = @as(MaskType, 0),
        mask: MaskType = @as(MaskType, 0),

        pub inline fn set(self: *@This(), comptime T: type) void {
            flag_utils.setFlag(&self.mask, type_list.getFlag(T));
            self.setEnabled(T, true);
        }

        pub inline fn unset(self: *@This(), comptime T: type) void {
            flag_utils.removeFlag(&self.mask, type_list.getFlag(T));
            self.setEnabled(T, false);
        }

        pub inline fn eql(self: *@This(), other: *@This()) bool {
            return self.mask == other.mask;
        }

        pub inline fn contains(self: *@This(), other: *@This()) bool {
            return flag_utils.containsFlags(self.mask, other.mask);
        }

        pub inline fn setEnabled(self: *@This(), comptime T: type, enabled: bool) void {
            if (enabled) {
                flag_utils.setFlag(&self.enabled_mask, type_list.getFlag(T));
            } else {
                flag_utils.removeFlag(&self.enabled_mask, type_list.getFlag(T));
            }
        }

        pub inline fn isEnabled(self: *@This(), comptime T: type) bool {
            return flag_utils.hasFlag(self.enabled_mask, type_list.getFlag(T));
        }

        pub inline fn enabledEql(self: *@This(), other: *@This()) bool {
            return self.enabled_mask == other.enabled_mask;
        }
    };
}


/// The ecs context used to manage entities, components, and systems
pub const ECSContextParams = struct {
    entity_type: type = usize,
    entity_interfaces: []const type = &.{},
    components: []const type,
    systems: []const type = &.{},
};

pub fn ECSContext(context_params: ECSContextParams) type {
    const max_tags = 4;
    const EntityIdType = context_params.entity_type;
    const entity_interface_types = context_params.entity_interfaces;
    const component_types = context_params.components;
    const system_types = context_params.systems;
    const component_type_list = TypeList(component_types);
    const entity_interface_type_list = TypeList(entity_interface_types);
    const system_type_list = TypeList(system_types);

    return struct {
        const ECSContextType = @This();
        pub const Entity = EntityIdType;
        pub const Tags = TagList(max_tags);

        /// Entity data that exists outside of components
        pub const EntityData = struct {
            components: [component_types.len]?*anyopaque = undefined,
            interface_instance: ?*anyopaque = null,
            tag_list: Tags = .{},
            component_signature: TypeBitMask(component_types) = .{},
            is_valid: bool = false,
        };

        pub const ECSystemData = struct {
            interface_instance: *anyopaque,
            component_signature: TypeBitMask(component_types) = .{},
        };

        pub const InitEntityParams = struct {
            interface_type: ?type = null,
        };

        allocator: std.mem.Allocator,
        entity_data_list: std.ArrayList(EntityData),
        system_data_list: std.ArrayList(ECSystemData),
        entity_id_counter: Entity = @as(Entity, 0),

        pub fn init(allocator: std.mem.Allocator) !@This() {
            var new_context = @This(){
                .allocator = allocator,
                .entity_data_list = std.ArrayList(EntityData).init(allocator),
                .system_data_list = try std.ArrayList(ECSystemData).initCapacity(allocator, system_type_list.len),
            };

            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                var new_system: *T = try allocator.create(T);
                if (@hasDecl(T, "init")) {
                    new_system.init();
                }
                _ = try new_context.system_data_list.addOne();
                new_context.system_data_list.items[i].interface_instance = new_system;
            }

            return new_context;
        }

        pub fn deinit(self: *@This()) void {
            for (0..self.entity_data_list.items.len) |i| {
                self.deinitEntity(@intCast(i));
            }
            self.entity_data_list.deinit();

            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                var system: *T = @alignCast(@ptrCast(self.system_data_list.items[i].interface_instance));
                if (@hasDecl(T, "deinit")) {
                    system.deinit();
                }
                self.allocator.destroy(system);
            }
            self.system_data_list.deinit();
        }

        pub fn initEntity(self: *@This(), comptime params: InitEntityParams) !Entity {
            const newEntity = self.entity_id_counter;
            defer self.entity_id_counter += 1;

            if (newEntity >= self.entity_data_list.items.len) {
                var entity_data: *EntityData = try self.entity_data_list.addOne();
                for (0..component_type_list.len) |i| {
                    entity_data.components[i] = null;
                }
            }
            var entity_data: *EntityData = &self.entity_data_list.items[newEntity];
            if (params.interface_type) |T| {
                var new_interface: *T = try self.allocator.create(T);
                if (@hasDecl(T, "init")) {
                    new_interface.init();
                }
            } else {
                entity_data.interface_instance = null;
            }
            entity_data.is_valid = true;

            return newEntity;
        }

        pub fn deinitEntity(self: *@This(), entity: Entity) void {
            if (self.isEntityValid(entity)) {
                const entity_data: *EntityData = &self.entity_data_list.items[entity];
                inline for (0..entity_interface_types.len) |i| {
                    const T: type = entity_interface_type_list.getType(i);
                    if (T == entity_interface_types[i]) {
                        if (entity_data.interface_instance) |interface_instance| {
                            const interface_ptr: *T = @alignCast(@ptrCast(interface_instance));
                            if (@hasDecl(T, "deinit")) {
                                interface_ptr.deinit();
                            }
                            self.allocator.destroy(interface_ptr);
                            entity_data.interface_instance = null;
                        }
                    }
                }
                inline for (0..component_types.len) |i| {
                    if (entity_data.components[i]) |component| {
                        const T: type = component_type_list.getType(i);
                        const current_comp: *T = @alignCast(@ptrCast(component));
                        self.allocator.destroy(current_comp);
                        entity_data.components[i] = null;
                        entity_data.is_valid = false;
                    }
                }
                entity_data.tag_list = .{};
                entity_data.is_valid = false;
            }
        }

        pub inline fn isEntityValid(self: *@This(), entity: Entity) bool {
            return entity < self.entity_data_list.items.len and self.entity_data_list.items[entity].is_valid;
        }

        pub fn setComponent(self: *@This(), entity: Entity, comptime T: type, component: *const T) !void {
            std.debug.assert(self.isEntityValid(entity));
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            const comp_index = component_type_list.getIndex(T);
            if (!hasComponent(self, entity,T)) {
                entity_data.components[comp_index] = try self.allocator.create(T);
                entity_data.component_signature.set(T);
            }

            const current_comp: *T = @alignCast(@ptrCast(entity_data.components[comp_index].?));
            current_comp.* = component.*;
        }

        pub fn getComponent(self: *@This(), entity: Entity, comptime T: type) ?*T {
            std.debug.assert(self.isEntityValid(entity));
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            const comp_index: usize = component_type_list.getIndex(T);
            if (entity_data.components[comp_index].data) |comp| {
                return @alignCast(@ptrCast(comp));
            }
            return null;
        }

        pub fn removeComponent(self: *@This(), entity: Entity, comptime T: type) void {
            std.debug.assert(self.isEntityValid(entity));
            if (hasComponent(self, T)) {
                const entity_data: *EntityData = &self.entity_data_list.items[entity];
                const comp_index: usize = component_type_list.getIndex(T);

                const comp_ptr: *T = @alignCast(@ptrCast(self.components[comp_index]));
                self.allocator.destroy(comp_ptr);
                entity_data.components[comp_index] = null;
                entity_data.component_signature.unset(T);
            }
        }

        pub inline fn hasComponent(self: *@This(), entity: Entity, comptime T: type) bool {
            std.debug.assert(self.isEntityValid(entity));
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            const comp_index: usize = component_type_list.getIndex(T);
            return entity_data.components[comp_index] != null;
        }

        pub fn setComponentEnabled(self: *@This(), entity: Entity, comptime T: type, enabled: bool) void {
            std.debug.assert(self.isEntityValid(entity));
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            entity_data.component_signature.setEnabled(T, enabled);
        }

        pub fn isComponentEnabled(self: *@This(), entity: Entity, comptime T: type) bool {
            std.debug.assert(self.isEntityValid(entity));
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            return entity_data.component_signature.isEnabled(T);
        }

        pub fn tick(self: *@This()) void {
            // Pre entity tick
            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                var system: *T = @alignCast(@ptrCast(self.system_data_list.items[i].interface_instance));
                if (@hasDecl(T, "preContextTick")) {
                    system.preContextTick();
                }
            }

            // Tick entities
            for (self.entity_data_list.items) |*entity_data| {
                if (entity_data.interface_instance) |interface_instance| {
                    inline for (0..entity_interface_types.len) |i| {
                        const T: type = entity_interface_type_list.getType(i);
                        if (T == entity_interface_types[i]) {
                            const interface_ptr: *T = @alignCast(@ptrCast(interface_instance));
                            if (@hasDecl(T, "tick")) {
                                interface_ptr.tick();
                            }
                        }
                    }
                }
            }

            // Post entity tick
            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                var system: *T = @alignCast(@ptrCast(self.system_data_list.items[i].interface_instance));
                if (@hasDecl(T, "postContextTick")) {
                    system.postContextTick();
                }
            }
        }
    };
}
