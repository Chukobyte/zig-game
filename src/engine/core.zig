const std = @import("std");

const zeika = @import("zeika");
const assets = @import("assets");

const string = @import("string.zig");

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
    texture: Texture,
    draw_source: Rect2,
    size: Vec2,
    origin: Vec2 = Vec2.Zero,
    flip_h: bool = false,
    flip_v: bool = false,
    modulate: Color = Color.White,

    pub inline fn getDrawConfig(self: *const @This(), transform: *const Transform2D, z_index: i32) Renderer.SpriteDrawQueueConfig {
        return .{
            .texture_handle = self.texture,
            .draw_source = self.draw_source,
            .size = self.size,
            .transform = &.{
                .position = .{ .x = transform.position.x + self.origin.x, .y = transform.position.y + self.origin.y },
                .scale = transform.scale,
                .rotation = transform.rotation,
            },
            .color = self.modulate,
            .flip_h = self.flip_h,
            .flip_v = self.flip_v,
            .z_index = z_index,
        };
    }
};

pub const TextLabel = struct {
    pub const String = string.String128;

    font: Font,
    text: String,
    color: Color = Color.White,
    origin: Vec2 = Vec2.Zero,

    pub inline fn setText(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
        try self.text.set(fmt, args);
    }

    pub inline fn getDrawConfig(self: *@This(), position: Vec2, z_index: i32) Renderer.TextDrawQueueConfig {
        return .{
            .font = self.font,
            .text = self.text.getCString(),
            .position = Vec2{ .x = position.x + self.origin.x, .y = position.y + self.origin.y },
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
