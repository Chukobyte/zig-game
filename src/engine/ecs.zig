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

        pub fn getIndex(comptime T: type) comptime_int {
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
            inline for (flag_types) |flag_type| {
                flags |= getFlag(flag_type);
            }
            return flags;
        }

        pub fn hasType(comptime T: type) bool {
            inline for (types) |OtherT| {
                if (T == OtherT) {
                    return true;
                }
            }
            return false;
        }
    };
}

pub fn FlagUtils(comptime T: type) type {
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

        pub inline fn setFlagsFromTypes(self: *@This(), comptime types_to_set: []const type) void {
            self.unsetAll();
            inline for (types_to_set) |T| {
                self.set(T);
            }
        }

        pub inline fn unset(self: *@This(), comptime T: type) void {
            flag_utils.removeFlag(&self.mask, type_list.getFlag(T));
            self.setEnabled(T, false);
        }

        pub inline fn unsetAll(self: *@This()) void {
            self.enabled_mask = @as(MaskType, 0);
            self.mask = @as(MaskType, 0);
        }

        pub inline fn eql(self: *const @This(), other: *const @This()) bool {
            return self.mask == other.mask;
        }

        pub inline fn eqlFlags(self: *const @This(), other: MaskType) bool {
            return self.mask == other;
        }

        pub inline fn contains(self: *const @This(), other: *const @This()) bool {
            return flag_utils.containsFlags(self.mask, other.mask);
        }

        pub inline fn setEnabled(self: *@This(), comptime T: type, enabled: bool) void {
            if (enabled) {
                flag_utils.setFlag(&self.enabled_mask, type_list.getFlag(T));
            } else {
                flag_utils.removeFlag(&self.enabled_mask, type_list.getFlag(T));
            }
        }

        pub inline fn isEnabled(self: *const @This(), comptime T: type) bool {
            return flag_utils.hasFlag(self.enabled_mask, type_list.getFlag(T));
        }

        pub inline fn enabledEql(self: *@This(), other: *@This()) bool {
            return self.enabled_mask == other.enabled_mask;
        }
    };
}

pub fn ArchetypeList(system_types: []const type, comp_types: []const type) type {
    const CompTypeList = TypeList(comp_types);
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
            const num_of_sorted_components = list_data.num_of_sorted_components;
            const num_of_components = list_data.num_of_components;
            inline for (0..num_of_sorted_components) |i| {
                inline for (0..num_of_components) |comp_i| {
                    if (component_types[comp_i] != list_data.sorted_components[i][comp_i]) {
                        break;
                    } else {
                        if (comp_i <= num_of_components - 1) {
                            return i;
                        }
                    }
                }
            }
            @compileError("Didn't pass in valid component types for sort index!");
        }

        pub fn getArchetypeCount() comptime_int {
            const archetype_list_data: []ArchetypeListData = generateArchetypeListData();
            return archetype_list_data.len;
        }

        pub fn getSortedComponentsMax() comptime_int {
            const archetype_list_data: []ArchetypeListData = generateArchetypeListData();
            var sorted_comp_max = 0;
            for (archetype_list_data) |*list_data| {
                if (list_data.num_of_sorted_components > sorted_comp_max) {
                    sorted_comp_max = list_data.num_of_sorted_components;
                }
            }
            return sorted_comp_max;
        }

        const ArchetypeListData = struct {
            const sorted_components_max = 4;
            const components_max = 16;

            signature: usize,
            num_of_components: usize,
            num_of_sorted_components: usize = 0,
            sorted_components: [sorted_components_max][components_max]type = undefined,
            sorted_components_by_index: [sorted_components_max][components_max]usize = undefined,
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
                            for (0..list_data.num_of_components) |i| {
                                list_data.sorted_components[list_data.num_of_sorted_components][i] = component_types[i];
                                list_data.sorted_components_by_index[list_data.num_of_sorted_components][i] = i;
                            }
                            list_data.num_of_sorted_components += 1;
                            continue :main;
                        }
                    }

                    // Now that it doesn't exist add it
                    archetype_list_data[archetypes_count] = ArchetypeListData{ .signature = archetype_sig, .num_of_components = component_types.len, .num_of_sorted_components = 1 };
                    for (0..component_types.len) |i| {
                        archetype_list_data[archetypes_count].sorted_components[0][i] = component_types[i];
                        archetype_list_data[archetypes_count].sorted_components_by_index[0][i] = i;
                    }

                    archetypes_count += 1;
                }
            }
            return archetype_list_data[0..archetypes_count];
        }
    };
}

/// Paramaters to initialize ecs context
pub const ECSContextParams = struct {
    entity_type: type = usize,
    entity_interfaces: []const type = &.{},
    components: []const type,
    systems: []const type = &.{},
};

/// The ecs context used to manage entities, components, and systems
pub fn ECSContext(context_params: ECSContextParams) type {
    const max_tags = 4;
    const EntityIdType = context_params.entity_type;
    const entity_interface_types = context_params.entity_interfaces;
    const component_types = context_params.components;
    const system_types = context_params.systems;
    const component_type_list = TypeList(component_types);
    const entity_interface_type_list = TypeList(entity_interface_types);
    const system_type_list = TypeList(system_types);
    const archetype_list = ArchetypeList(system_types, component_types);
    const archetype_count = archetype_list.getArchetypeCount();
    const sorted_components_max = archetype_list.getSortedComponentsMax();

    const arch_list = ArchetypeList(system_types, component_types);

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
            is_in_system_map: [system_types.len]bool = undefined,
            is_in_archetype_map: [archetype_count]bool = undefined,
        };

        /// System related stuff
        pub const ECSystemData = struct {
            interface_instance: *anyopaque,
            component_signature: TypeBitMask(component_types) = .{},
        };

        const ArchetypeData = struct {
            sorted_components: std.ArrayList([sorted_components_max][component_types.len]*anyopaque) = undefined,
            entities: std.ArrayList(Entity) = undefined,
            sorted_components_by_index: [sorted_components_max][component_types.len]usize = undefined,
            systems: [system_types.len]usize = undefined, // System indices
            system_count: usize = 0,
            signature: usize = 0,
            num_of_components: usize = 0,
            num_of_sorted_components: usize = 0,
        };

        pub fn ArchetypeComponentIterator(arch_comps: []const type) type {
            const comp_sort_index = archetype_list.getSortIndex(arch_comps);
            const arch_index = archetype_list.getIndex(arch_comps);
            const arch_list_data = arch_list.generateArchetypeListData();
            const list_data = arch_list_data[arch_index];

            return struct {

                pub const Node = struct {
                    components: *[list_data.num_of_components]*anyopaque,

                    pub fn getComponent(self: *const @This(), comptime T: type) *T {
                        return @alignCast(@ptrCast(self.components[getComponentSlot(T)]));
                    }

                    pub fn getValue(self: *const @This(), slot: comptime_int) *arch_comps[slot] {
                        return @alignCast(@ptrCast(self.components[slot]));
                    }
                };

                current_entity: Entity,
                archetype: *ArchetypeData,

                pub fn init(context: *ECSContextType) @This() {
                    const new_iterator = @This(){
                        .current_entity = 0,
                        .archetype = &context.archetype_data_list[arch_index],
                    };
                    return new_iterator;
                }

                pub fn next(self: *@This()) ?Node {
                    if (self.current_entity < self.archetype.entities.items.len) {
                        const node = Node{ .components = self.archetype.sorted_components.items[self.current_entity][comp_sort_index][0..] };
                        self.current_entity += 1;
                        // TODO: Make sure current entity is valid
                        return node;
                    }
                    return null;
                }

                pub fn peek(self: *@This()) ?Node {
                    if (self.current_entity < self.archetype.entities.items.len) {
                        const node = Node{ .components = self.archetype.sorted_components.items[self.current_entity][comp_sort_index][0..] };
                        // TODO: Make sure current entity is valid
                        return node;
                    }
                    return null;
                }

                pub inline fn getSlot(self: *const @This(), comptime T: type) usize {
                    _ = self;
                    return getComponentSlot(T);
                }

                fn getComponentSlot(comptime T: type) usize {
                    inline for (0..list_data.num_of_components) |i| {
                        if (T == list_data.sorted_components[comp_sort_index][i]) {
                            return i;
                        }
                    }
                    @compileError("Comp isn't in iterator!");
                }
            };
        }

        /// Optional parameters for creating an entity
        pub const InitEntityParams = struct {
            interface: ?type = null,
            tags: ?[]const []const u8 = null,
        };

        //--- ECSContext --- //

        allocator: std.mem.Allocator,
        entity_data_list: std.ArrayList(EntityData),
        system_data_list: std.ArrayList(ECSystemData),
        archetype_data_list: [archetype_count]ArchetypeData,
        entity_id_counter: Entity = @as(Entity, 0),

        pub fn init(allocator: std.mem.Allocator) !@This() {
            var new_context = @This(){
                .allocator = allocator,
                .entity_data_list = std.ArrayList(EntityData).init(allocator),
                .system_data_list = try std.ArrayList(ECSystemData).initCapacity(allocator, system_type_list.len),
                .archetype_data_list = undefined,
            };

            const arch_list_data = comptime arch_list.generateArchetypeListData();

            inline for (0..archetype_count) |i| {
                const arch_data = &arch_list_data[i];
                const data_list = &new_context.archetype_data_list[i];
                data_list.entities = std.ArrayList(Entity).init(allocator);
                data_list.sorted_components = std.ArrayList([sorted_components_max][component_types.len]*anyopaque).init(allocator);
                for (0..arch_data.num_of_sorted_components) |comp_sort_i| {
                    for (0..arch_data.num_of_components) |comp_i| {
                        data_list.sorted_components_by_index[comp_sort_i][comp_i] = arch_data.sorted_components_by_index[comp_sort_i][comp_i];
                    }
                }
                data_list.signature = arch_data.signature;
                data_list.num_of_components = arch_data.num_of_components;
                data_list.num_of_sorted_components = arch_data.num_of_sorted_components;
            }

            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                var new_system: *T = try allocator.create(T);
                new_system.* = T{}; // Systems need to be able to be default constructed for now
                _ = try new_context.system_data_list.addOne();
                var new_system_data: *ECSystemData = &new_context.system_data_list.items[i];
                new_system_data.interface_instance = new_system;

                if (@hasDecl(T, "getArchetype")) {
                    const system_component_types = T.getArchetype();
                    new_system_data.component_signature.setFlagsFromTypes(system_component_types);

                    inline for (0..archetype_count) |arch_i| {
                        const data_list = &new_context.archetype_data_list[arch_i];
                        if (new_system_data.component_signature.eqlFlags(data_list.signature)) {
                            data_list.systems[data_list.system_count] = i;
                            data_list.system_count += 1;
                        }
                    }

                } else {
                    new_system_data.component_signature.unsetAll();
                }

                if (@hasDecl(T, "init")) {
                    new_system.init(&new_context);
                }
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
                const system_data: *ECSystemData = &self.system_data_list.items[i];
                var system: *T = @alignCast(@ptrCast(system_data.interface_instance));
                if (@hasDecl(T, "deinit")) {
                    system.deinit(self);
                }
                self.allocator.destroy(system);
            }
            self.system_data_list.deinit();

            inline for (0..archetype_count) |i| {
                const data_list = &self.archetype_data_list[i];
                data_list.entities.deinit();
                data_list.sorted_components.deinit();
                data_list.* = .{};
            }
        }

        pub fn tick(self: *@This()) void {
            // Pre entity tick
            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                if (@hasDecl(T, "preContextTick")) {
                    var system: *T = @alignCast(@ptrCast(self.system_data_list.items[i].interface_instance));
                    system.preContextTick(self);
                }
            }

            // Tick entities
            for (self.entity_data_list.items, 0..self.entity_data_list.items.len) |*entity_data, entity| {
                if (entity_data.interface_instance) |interface_instance| {
                    inline for (0..entity_interface_types.len) |i| {
                        const T: type = entity_interface_type_list.getType(i);
                        if (T == entity_interface_types[i]) {
                            if (@hasDecl(T, "tick")) {
                                const interface_ptr: *T = @alignCast(@ptrCast(interface_instance));
                                interface_ptr.tick(self, entity);
                            }
                        }
                    }
                }
            }

            // Post entity tick
            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                if (@hasDecl(T, "postContextTick")) {
                    var system: *T = @alignCast(@ptrCast(self.system_data_list.items[i].interface_instance));
                    system.postContextTick(self);
                }
            }
        }

        pub fn render(self: *@This()) void {
            inline for (0..system_type_list.len) |i| {
                const T: type = system_type_list.getType(i);
                if (@hasDecl(T, "render")) {
                    var system: *T = @alignCast(@ptrCast(self.system_data_list.items[i].interface_instance));
                    system.render(self);
                }
            }
        }

        //--- Entity --- //

        /// Wrapper around an entity integer that simplifies entity operations
        pub const WeakEntityRef = struct {
            id: Entity,
            context: *ECSContextType,

            pub inline fn deinit(self: *@This()) void {
                self.context.deinitEntity(self.id);
            }
            pub inline fn isValid(self: *const @This()) bool {
                return self.context.isEntityValid(self.id);
            }
            pub inline fn setComponent(self: *@This(), comptime T: type, component: *const T) !void {
                return self.context.setComponent(self.id, T, component);
            }
            pub inline fn getComponent(self: *@This(), comptime T: type) ?*T {
                return self.context.getComponent(self.id, T);
            }
            pub inline fn removeComponent(self: *@This(), comptime T: type) !void {
                return self.context.removeComponent(self.id, T);
            }
            pub inline fn hasComponent(self: *@This(), comptime T: type) bool {
                return self.context.hasComponent(self.id, T);
            }
        };

        pub fn initEntity(self: *@This(), comptime params: InitEntityParams) !Entity {
            if (comptime params.interface != null and !entity_interface_type_list.hasType(params.interface.?)) {
                @compileLog("Initialized an entity with unregistered entity interface '{any}'!", .{ params.interface.? });
            }

            const new_entity = self.entity_id_counter;
            defer self.entity_id_counter += 1;

            if (new_entity >= self.entity_data_list.items.len) {
                var entity_data: *EntityData = try self.entity_data_list.addOne();
                for (0..component_type_list.len) |i| {
                    entity_data.components[i] = null;
                }
                entity_data.component_signature.unsetAll();
            }
            var entity_data: *EntityData = &self.entity_data_list.items[new_entity];
            if (params.interface) |T| {
                var new_interface: *T = try self.allocator.create(T);
                new_interface.* = T{}; // Interfaces must be able to be default constructed for now
                if (@hasDecl(T, "init")) {
                    new_interface.init(self, new_entity);
                }
                entity_data.interface_instance = new_interface;
            } else {
                entity_data.interface_instance = null;
            }

            if (params.tags) |tags| {
                entity_data.tag_list = Tags.initFromSlice(tags);
            } else {
                entity_data.tag_list = .{};
            }

            inline for (0..system_types.len) |i| {
                entity_data.is_in_system_map[i] = false;
            }
            entity_data.is_valid = true;

            return new_entity;
        }

        pub fn deinitEntity(self: *@This(), entity: Entity) void {
            if (self.isEntityValid(entity)) {
                const entity_data: *EntityData = &self.entity_data_list.items[entity];
                entity_data.component_signature.unsetAll();
                self.refreshArchetypeState(entity) catch {}; // Not worried about error
                inline for (0..entity_interface_types.len) |i| {
                    const T: type = entity_interface_type_list.getType(i);
                    if (T == entity_interface_types[i]) {
                        if (entity_data.interface_instance) |interface_instance| {
                            const interface_ptr: *T = @alignCast(@ptrCast(interface_instance));
                            if (@hasDecl(T, "deinit")) {
                                interface_ptr.deinit(self, entity);
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

        /// Returns first entity that matches a tag
        pub fn getEntityByTag(self: *@This(), tag: []const u8) ?Entity {
            for (self.entity_data_list.items, 0..self.entity_data_list.items.len) |entity_data, i| {
                if (entity_data.is_valid and entity_data.tag_list.hasTag(tag)) {
                    return i;
                }
            }
            return null;
        }

        pub inline fn isEntityValid(self: *@This(), entity: Entity) bool {
            return entity < self.entity_data_list.items.len and self.entity_data_list.items[entity].is_valid;
        }

        pub fn setComponent(self: *@This(), entity: Entity, comptime T: type, component: *const T) !void {
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            const comp_index = component_type_list.getIndex(T);
            if (!hasComponent(self, entity,T)) {
                entity_data.components[comp_index] = try self.allocator.create(T);
                entity_data.component_signature.set(T);
                try self.refreshArchetypeState(entity);
            }

            const current_comp: *T = @alignCast(@ptrCast(entity_data.components[comp_index].?));
            current_comp.* = component.*;
        }

        pub fn getComponent(self: *@This(), entity: Entity, comptime T: type) ?*T {
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            const comp_index: usize = component_type_list.getIndex(T);
            if (entity_data.components[comp_index]) |comp| {
                return @alignCast(@ptrCast(comp));
            }
            return null;
        }

        pub fn removeComponent(self: *@This(), entity: Entity, comptime T: type) void {
            if (self.hasComponent(entity, T)) {
                const entity_data: *EntityData = &self.entity_data_list.items[entity];
                const comp_index: usize = component_type_list.getIndex(T);

                const comp_ptr: *T = @alignCast(@ptrCast(entity_data.components[comp_index]));
                self.allocator.destroy(comp_ptr);
                entity_data.components[comp_index] = null;
                entity_data.component_signature.unset(T);
                self.refreshArchetypeState(entity) catch {}; // Ignore
            }
        }

        pub inline fn hasComponent(self: *@This(), entity: Entity, comptime T: type) bool {
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            const comp_index: usize = component_type_list.getIndex(T);
            return entity_data.components[comp_index] != null;
        }

        pub fn setComponentEnabled(self: *@This(), entity: Entity, comptime T: type, enabled: bool) void {
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            entity_data.component_signature.setEnabled(T, enabled);
        }

        pub fn isComponentEnabled(self: *@This(), entity: Entity, comptime T: type) bool {
            const entity_data: *EntityData = &self.entity_data_list.items[entity];
            return entity_data.component_signature.isEnabled(T);
        }

        // --- Archetype --- //

        pub inline fn getArchetypeEntities(self: *@This(), arch_comps: []const type) []const Entity {
            const arch_index = archetype_list.getIndex(arch_comps);
            return self.archetype_data_list[arch_index].entities.items[0..];
        }

        fn refreshArchetypeState(self: *@This(), entity: Entity) !void {
            const SystemNotifyState = enum {
                none,
                on_entity_registered,
                on_entity_unregistered,
            };

            const Static = struct {
                var SystemState: [system_types.len]SystemNotifyState = undefined;
            };

            const entity_data: *EntityData = &self.entity_data_list.items[entity];

            const arch_list_data = comptime arch_list.generateArchetypeListData();

            inline for (0..archetype_count) |i| {
                const data_list = &self.archetype_data_list[i];
                const match_signature = FlagUtils(usize).containsFlags(entity_data.component_signature.mask, data_list.signature);
                if (match_signature and !entity_data.is_in_archetype_map[i]) {
                    entity_data.is_in_archetype_map[i] = true;
                    data_list.entities.append(entity) catch { unreachable; };
                    if (entity >= data_list.sorted_components.items.len) {
                        _ = try data_list.sorted_components.addManyAsSlice(entity + 1 - data_list.sorted_components.items.len);
                    }
                    // Update sorted component arrays
                    inline for (0..arch_list_data[i].num_of_sorted_components) |sort_comp_i| {
                        inline for (0..arch_list_data[i].num_of_components) |comp_i| {
                            // Map component pointers with order
                            const entity_comp_index = data_list.sorted_components_by_index[sort_comp_i][comp_i];
                            data_list.sorted_components.items[entity][sort_comp_i][comp_i] = entity_data.components[entity_comp_index].?;
                            if (comp_i + 1 >= data_list.num_of_components)  {
                                break;
                            }
                        }
                        if (sort_comp_i + 1 >= data_list.num_of_sorted_components)  {
                            break;
                        }
                    }

                    for (0..data_list.system_count) |sys_i| {
                        const system_index = data_list.systems[sys_i];
                        Static.SystemState[system_index] = .on_entity_registered;
                    }
                } else if (!match_signature and entity_data.is_in_archetype_map[i]) {
                    entity_data.is_in_archetype_map[i] = false;
                    for (0..data_list.entities.items.len) |item_index| {
                        if (data_list.entities.items[item_index] == entity) {
                            _ = data_list.entities.swapRemove(item_index);
                            break;
                        }
                    }
                    for (0..data_list.system_count) |sys_i| {
                        const system_index = data_list.systems[sys_i];
                        Static.SystemState[system_index] = .on_entity_unregistered;
                    }
                }
            }

            inline for (self.system_data_list.items, 0..system_types.len) |*system_data, i| {
                const T: type = system_type_list.getType(i);
                switch (Static.SystemState[i]) {
                    .on_entity_registered => {
                        if (@hasDecl(T, "onEntityRegistered")) {
                            var system: *T = @alignCast(@ptrCast(system_data.interface_instance));
                            system.onEntityRegistered(self, entity);
                        }
                        Static.SystemState[i] = .none;
                    },
                    .on_entity_unregistered => {
                        if (@hasDecl(T, "onEntityUnregistered")) {
                            var system: *T = @alignCast(@ptrCast(system_data.interface_instance));
                            system.onEntityUnregistered(self, entity);
                        }
                        Static.SystemState[i] = .none;
                    },
                    .none => {},
                }
            }
        }
    };
}
