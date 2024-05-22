const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const engine = @import("engine");

const core = engine.core;
const ec = engine.ec;

const Renderer = zeika.Renderer;
const Texture = zeika.Texture;
const Font = zeika.Font;
const Vec2 = zeika.math.Vec2;
const Vec2i = zeika.math.Vec2i;
const Rect2 = zeika.math.Rect2;
const Color = zeika.math.Color;

const Sprite = core.Sprite;
const TextLabel = core.TextLabel;
const Collision = core.Collision;

const ECContext = @import("game.zig").ECContext;

pub const TransformComponent = struct {
    transform: math.Transform2D = math.Transform2D.Identity,
};

pub const SpriteComponent = struct {
    sprite: Sprite,

    pub fn render(comp: *anyopaque, entity: *ECContext.Entity) void {
        const sprite_comp: *@This() = @alignCast(@ptrCast(comp));
        if (entity.getComponent(TransformComponent)) |transform_comp| {
            const draw_config = sprite_comp.sprite.getDrawConfig(&transform_comp.transform, 0);
            Renderer.queueDrawSprite(&draw_config);
        }
    }
};

pub const TextLabelComponent = struct {
    text_label: TextLabel,

    pub fn init(comp: *anyopaque, entity: *ECContext.Entity) void {
        const StaticData = struct {
            var text_buffer: [256]u8 = undefined;
            };
        _ = entity;
        const text_label_comp: *@This() = @alignCast(@ptrCast(comp));
        text_label_comp.text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: 0", .{}) catch { unreachable; };
    }

    pub fn render(comp: *anyopaque, entity: *ECContext.Entity) void {
        const text_label_comp: *@This() = @alignCast(@ptrCast(comp));
        if (entity.getComponent(TransformComponent)) |transform_comp|  {
            const draw_config = text_label_comp.text_label.getDrawConfig(transform_comp.transform.position, 0);
            Renderer.queueDrawText(&draw_config);
        }
    }
};

pub const ColliderComponent = struct {
    collider: Rect2,
};
