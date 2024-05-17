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

pub const Entity = struct {
    transform: Transform2D = Transform2D.Identity,
    z_index: i32 = 0,
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
    entities: std.ArrayList(*Entity),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){
            .entities = std.ArrayList(*Entity).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.entities.deinit();
    }

    pub fn registerEntities(self: *@This(), entities: [] Entity) !void {
        for (entities) |*entity| {
            try self.entities.append(entity);
            if (entity.on_enter_scene_func) |enter_scene_func| {
                enter_scene_func(entity);
            }
        }
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

pub fn getWorldMousePos( ) Vec2 {
    const mouse_pos: Vec2 = zeika.getMousePosition();
    const game_window_size: Vec2i = zeika.getWindowSize();
    const game_resolution = Vec2i{ .x = 800, .y = 450 };
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
