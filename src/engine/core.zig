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

    pub fn getDrawConfig(self: *const @This(), transform: *const Transform2D, z_index: i32) Renderer.SpriteDrawQueueConfig {
        return .{
            .texture_handle = self.texture,
            .draw_source = self.draw_source,
            .size = self.size,
            .transform = transform,
            .color = self.modulate,
            .flip_h = self.flip_h,
            .flip_v = self.flip_v,
            .z_index = z_index,
        };
    }
};

pub const TextLabel = struct {
    font: Font,
    text: []u8 = undefined,
    color: Color = Color.White,

    pub fn getDrawConfig(self: *const @This(), position: Vec2, z_index: i32) Renderer.TextDrawQueueConfig {
        return .{
            .font = self.font,
            .text = self.text,
            .position = position,
            .color = self.color,
            .z_index = z_index,
        };
    }
};

pub const Collision = struct {
    collider: Rect2,

    pub inline fn isColliding(self: *const @This(), other: *const @This()) bool {
        return self.collider.doesOverlap(other.collider);
    }
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
