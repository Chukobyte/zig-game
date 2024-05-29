const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const game = @import("game.zig");
const comps = @import("components.zig");

const engine = @import("engine");
const core = engine.core;

const Vec2 = math.Vec2;
const Rect2 = math.Rect2;
const Transform2D = math.Transform2D;
const Color = math.Color;

const Texture = zeika.Texture;
const Font = zeika.Font;


const Sprite = core.Sprite;
const TextLabel = core.TextLabel;

const ECSContext = game.ECSContext;
const Entity = ECSContext.Entity;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const ColliderComponent = comps.ColliderComponent;
const TextLabelComponent = comps.TextLabelComponent;

pub const SpriteButtonInterface = struct {
    money: i32 = 0,

    pub fn tick(self: *@This(), context: *ECSContext, entity: Entity) void {
        const trans_comp = context.getComponent(entity, TransformComponent).?;
        const sprite_comp = context.getComponent(entity, SpriteComponent).?;
        const collider_comp = context.getComponent(entity, ColliderComponent).?;

        const transform = trans_comp.transform;
        var sprite = &sprite_comp.sprite;
        const collider = collider_comp.collider;
        const world_mouse_pos: Vec2 = game.getWorldMousePos();
        const entity_collider = Rect2{
            .x = transform.position.x + collider.x,
            .y = transform.position.y + collider.y,
            .w = collider.w,
            .h = collider.h
        };
        const mouse_collider: Rect2 = .{ .x = world_mouse_pos.x, .y = world_mouse_pos.y, .w = 1.0, .h = 1.0 };
        if (entity_collider.doesOverlap(&mouse_collider)) {
            if (zeika.isKeyPressed(.mouse_button_left, 0)) {
                sprite.modulate = Color.White;
            } else {
                sprite.modulate = Color.Red;
            }

            if (zeika.isKeyJustPressed(.mouse_button_left, 0)) {
                if (context.getEntityByTag("text_label")) |text_label_entity| {
                    if (context.getComponent(text_label_entity, TextLabelComponent)) |text_label_comp| {
                        self.money += 1;
                        text_label_comp.text_label.setText("Money: {d}", .{ self.money }) catch { unreachable; };
                    }
                }
            }
        } else {
            sprite.modulate = Color.Blue;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent, ColliderComponent }; }
};
