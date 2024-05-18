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

    transform: Transform2D = Transform2D.Identity,
    z_index: i32 = 0,
    tag_list: ?Tags = null,
    sprite: ?Sprite = null,
    text_label: ?TextLabel = null,
    collision: ?Collision = null,

    on_enter_scene_func: ?*const fn(self: *@This()) void = null,
    on_exit_scene_func: ?*const fn(self: *@This()) void = null,
    update_func: ?*const fn(self: *@This()) void = null,

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
    pub inline fn registerEntity(self: *@This(), entity: Entity) !void {
        try self.registerEntities([]Entity { entity });
    }

    /// Will register entities to the world.  Creates copies of the passed in entities and the world takes ownership.
    pub fn registerEntities(self: *@This(), entities: []const Entity) !void {
        try self.entities.appendSlice(entities);
        for (self.entities.items) |*entity| {
            if (entity.on_enter_scene_func) |enter_scene_func| {
                enter_scene_func(entity);
            }
        }
    }

    pub fn unregisterEntities(self: *@This(), entities: []const Entity) !void {
        var i: usize = 0;
        while (i < self.entities.items.len) : (i += 1) {
            var should_remove = false;
            for (entities) |*entity| {
                if (std.mem.eql(Entity, self.entities.items[i], entity)) {
                    if (entity.on_exit_scene_func) |exit_scene_func| {
                        exit_scene_func(entity);
                    }
                    should_remove = true;
                    break;
                }
            }
            if (should_remove) {
                try self.entities.swapRemove(i);
                i -= 1; // Don't increment as the current index will hold the next value
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

const Camera = struct {
    viewport: Vec2 = Vec2.Zero,
    zoom: Vec2 = Vec2.One,
    offset: Vec2 = Vec2.Zero,
};

// Game

const GameProperties = struct {
    title: []const u8 = "ZigTest",
    initial_window_size: Vec2i = Vec2i{ .x = 800, .y = 450 },
    resolution: Vec2i = Vec2i{ .x = 800, .y = 450 },
};

const game_properties = GameProperties{};
var gloabal_world: World = undefined;

pub fn init() !void {
    try zeika.initAll(
        game_properties.title,
        game_properties.initial_window_size.x,
        game_properties.initial_window_size.y,
        game_properties.resolution.x,
        game_properties.resolution.y
    );
    gloabal_world = World.init(std.heap.page_allocator);

}

pub fn deinit() void {
    gloabal_world.deinit();
    zeika.shutdownAll();
}

pub fn run() !void {
    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const default_font: Font = Font.initFromMemory(
            assets.DefaultFont.data,
            assets.DefaultFont.len,
            .{ .font_size = 16, .apply_nearest_neighbor = true }
    );
    defer default_font.deinit();

    const entities = [_]Entity{
        Entity{
            .transform = Transform2D{ .position = Vec2{ .x = 100.0, .y = 100.0 } },
            .tag_list = Entity.Tags.initFromSlice(&[_][]const u8{ "sprite" }),
            .sprite = Sprite{
                .texture = texture_handle,
                .size = Vec2{ .x = 64.0, .y = 64.0 },
                .draw_source = Rect2{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = Color.Blue,
            },
            .collision = Collision{ .collider = Rect2{ .x = 0.0, .y = 0.0, .w = 64.0, .h = 64.0 } },
            .update_func = struct {
                pub fn update(self: *Entity) void {
                    if (self.sprite) |*sprite| {
                        if (self.collision) |*collision| {
                            const world_mouse_pos: Vec2 = getWorldMousePos();
                            const entity_collider = Rect2{
                                .x = self.transform.position.x + collision.collider.x,
                                .y = self.transform.position.y + collision.collider.y,
                                .w = collision.collider.w,
                                .h = collision.collider.h
                            };
                            const mouse_collider = Rect2{ .x = world_mouse_pos.x, .y = world_mouse_pos.y, .w = 1.0, .h = 1.0 };
                            if (entity_collider.doesOverlap(&mouse_collider)) {
                                if (zeika.isKeyPressed(.mouse_button_left, 0)) {
                                    sprite.modulate = Color.White;
                                } else {
                                    sprite.modulate = Color.Red;
                                }

                                if (zeika.isKeyJustPressed(.mouse_button_left, 0)) {
                                    if (gloabal_world.getEntityByTag("text_label")) |text_label_entity| {
                                        if (text_label_entity.text_label) |*text_label| {
                                            const StaticData = struct {
                                                var text_buffer: [256]u8 = undefined;
                                                var money: i32 = 0;
                                            };
                                            StaticData.money += 1;
                                            text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: {d}", .{ StaticData.money }) catch { unreachable; };
                                        }
                                    }
                                }
                            } else {
                                sprite.modulate = Color.Blue;
                            }
                        }
                    }
                }
                }.update,
        },
        Entity{
            .transform = Transform2D{ .position = Vec2{ .x = 100.0, .y = 200.0 } },
            .tag_list = Entity.Tags.initFromSlice(&[_][]const u8{ "text_label" }),
            .text_label = TextLabel{
                .font = default_font,
                .color = Color.Red
            },
            .on_enter_scene_func = struct {
                pub fn on_enter_scene(self: *Entity) void  {
                    const StaticData = struct {
                        var text_buffer: [256]u8 = undefined;
                    };
                    if (self.text_label) |*text_label| {
                        text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: 0", .{}) catch { unreachable; };
                    }
                }
            }.on_enter_scene,
        },
    };
    try gloabal_world.registerEntities(&entities);

    while (zeika.isRunning()) {
        zeika.update();

        if (zeika.isKeyJustPressed(.keyboard_escape, 0)) {
            break;
        }

        // TODO: Prototyping things, eventually will categorize game objects so we don't have conditionals within the update loops

        // Object Updates
        for (gloabal_world.entities.items) |*entity| {
            if (entity.update_func) |update| {
                update(entity);
            }
        }

        // Render
        for (gloabal_world.entities.items) |*entity| {
            if (entity.*.getSpriteDrawConfig()) |draw_config| {
                Renderer.queueDrawSprite(&draw_config);
            }
            if (entity.getTextDrawConfig()) |draw_config| {
                Renderer.queueDrawText(&draw_config);
            }
        }
        Renderer.flushBatches();
    }
}

pub fn getWorldMousePos( ) Vec2 {
    const mouse_pos: Vec2 = zeika.getMousePosition();
    const game_window_size: Vec2i = zeika.getWindowSize();
    const game_resolution = game_properties.resolution;
    const global_camera = Camera{};
    const mouse_pixel_coord = Vec2{
        .x = math.mapToRange(f32, mouse_pos.x, 0.0, @floatFromInt(game_window_size.x), 0.0, game_resolution.x),
        .y = math.mapToRange(f32, mouse_pos.y, 0.0, @floatFromInt(game_window_size.y), 0.0, game_resolution.y)
    };
    const mouse_world_pos = Vec2{
        .x = (global_camera.viewport.x + global_camera.offset.x + mouse_pixel_coord.x) * global_camera.zoom.x,
        .y = (global_camera.viewport.y + global_camera.offset.y + mouse_pixel_coord.y) * global_camera.zoom.y
    };
    return mouse_world_pos;
}
