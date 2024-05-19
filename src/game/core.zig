const std = @import("std");

const zeika = @import("zeika");
const assets = @import("assets");

const seika = zeika.seika;
const math = zeika.math;

const Vec2 = math.Vec2;
const Vec2i = math.Vec2i;
const Transform2D = math.Transform2D;
const Rect2 = math.Rect2;
const Color = math.Color;

const Renderer = zeika.Renderer;
const Texture = zeika.Texture;
const Font = zeika.Font;

pub const Sprite = struct {
    texture: Texture.Handle,
    draw_source: Rect2,
    size: Vec2,
    origin: Vec2 = Vec2.Zero,
    flip_h: bool = false,
    flip_v: bool = false,
    modulate: Color = Color.White,
};

pub const TextLabel = struct {
    font: Font,
    text: []u8 = undefined,
    color: Color = Color.White,
};

pub const Collision = struct {
    collider: Rect2,

    pub inline fn isColliding(self: *const @This(), other: *const @This()) bool {
        return self.collider.doesOverlap(other.collider);
    }
};

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

pub const Entity = struct {
    pub const Tags = TagList(4);

    pub const Interface = struct {
        on_enter_scene: ?*const fn(self: *Entity) void = null,
        on_exit_scene: ?*const fn(self: *Entity) void = null,
        update: ?*const fn(self: *Entity) void = null,
    };

    transform: Transform2D = Transform2D.Identity,
    z_index: i32 = 0,
    tag_list: ?Tags = null,
    sprite: ?Sprite = null,
    text_label: ?TextLabel = null,
    collision: ?Collision = null,
    id: ?u32 = null, // Assigned from World

    interface: Interface = .{},

    pub fn getSpriteDrawConfig(self: *const @This()) ?Renderer.SpriteDrawQueueConfig {
        if (self.sprite) |sprite| {
            return Renderer.SpriteDrawQueueConfig{
                .texture_handle = sprite.texture,
                .draw_source = sprite.draw_source,
                .size = sprite.size,
                .transform = &self.transform,
                .color = sprite.modulate,
                .flip_h = sprite.flip_h,
                .flip_v = sprite.flip_v,
                .z_index = self.z_index,
            };
        }
        return null;
    }

    pub fn getTextDrawConfig(self: *const @This()) ?Renderer.TextDrawQueueConfig {
        if (self.text_label) |text_label| {
            return Renderer.TextDrawQueueConfig{
                .font = text_label.font,
                .text = text_label.text,
                .position = self.transform.position,
                .color = text_label.color,
                .z_index = self.z_index,
            };
        }
        return null;
    }
};

pub const World = struct {
    allocator: std.mem.Allocator,
    entities: std.ArrayList(Entity),
    id_counter: u32 = 1,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){
            .allocator = allocator,
            .entities = std.ArrayList(Entity).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.entities.deinit();
    }

    /// Will register entity to the world.  Will create an owned copy of the passed in entity.
    pub inline fn registerEntity(self: *@This(), entity: Entity) !u32 {
        const ids = try self.registerEntities(&[_]Entity{ entity });
        return ids[0];
    }

    /// Will register entities to the world.  Creates copies of the passed in entities and the world takes ownership.
    pub fn registerEntities(self: *@This(), entities: []const Entity) ![]u32 {
        const Static = struct {
            const max_ids = 32;
            var id_buffer: [max_ids]u32 = undefined;
            var len: usize = 0;
        };
        Static.len = 0;
        std.debug.assert(entities.len < Static.max_ids);

        try self.entities.appendSlice(entities);
        for (self.entities.items) |*entity| {
            entity.id = self.id_counter;
            self.id_counter += 1;
            Static.id_buffer[Static.len] = entity.id.?;
            Static.len += 1;
            if (entity.interface.on_enter_scene) |enter_scene| {
                enter_scene(entity);
            }
        }
        return Static.id_buffer[0..Static.len];
    }

    pub inline fn unregisterEntity(self: *@This(), id: u32) void {
        self.unregisterEntities(&[_]u32{ id });
    }

    pub fn unregisterEntities(self: *@This(), ids: []const u32) void {
        var i: usize = 0;
        while (i < self.entities.items.len) : (i += 1) {
            var should_remove = false;
            for (ids) |id| {
                if (self.entities.items[i].id.? == id) {
                    if (self.entities.items[i].interface.on_exit_scene) |on_exit_scene| {
                        on_exit_scene(&self.entities.items[i]);
                    }
                    should_remove = true;
                    break;
                }
            }
            if (should_remove) {
                _ = self.entities.swapRemove(i);
                if (i > 0) {
                    i -= 1; // Don't increment as the current index will hold the next value
                }
            }
        }
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

pub const Scene = struct {

};

pub const Hero = struct {
    pub const Stats = struct {
        health: i32,
        tiles: i32,
        attack: i32,
        defense: i32,
        accuracy: i32,
        evasion: i32,
    };

    pub const PowerEffect = struct {
        pub const Type = enum {
            active,
            passive,
        };

        type: Type,
    };

    pub const Power = struct {

    };

    stats: Stats,
    powers: []Power,
};

pub const Camera = struct {
    viewport: Vec2 = Vec2.Zero,
    zoom: Vec2 = Vec2.One,
    offset: Vec2 = Vec2.Zero,
};

pub const GameProperties = struct {
    title: []const u8 = "ZigTest",
    initial_window_size: Vec2i = .{ .x = 800, .y = 450 },
    resolution: Vec2i = .{ .x = 800, .y = 450 },
};
