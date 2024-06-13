const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;
const Event = zeika.event.Event;
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
const ECSContext = @import("game.zig").ECSContext;
const Entity = ECSContext.Entity;

pub const TransformComponent = struct {
    transform: math.Transform2D = math.Transform2D.Identity,
};

pub const SpriteComponent = struct {
    sprite: Sprite,
};

pub const TextLabelComponent = struct {
    text_label: TextLabel,

    pub fn deinit(self: *@This()) void {
        self.text_label.text.deinit();
    }
};

pub const ColliderComponent = struct {
    collider: Rect2,
};

pub const UIWidgetComponent = struct {
    pub const Type = enum {
        button,
    };

    pub const Button = struct {
        on_just_pressed: ?*const fn(*ECSContext, Entity) void = null,
        on_clicked: ?*const fn(*ECSContext, Entity) void = null,
        is_pressed: bool = false,
        was_just_pressed: bool = false, // If just pressed this frame

        const Colors = struct {
            const hovered: Color = .{ .r = 200, .g = 200, .b = 200 };
            const unhovered: Color = .{ .r = 150, .g = 150, .b = 150 };
            const pressed: Color = .{ .r = 50, .g = 50, .b = 50 };
        };

        /// Generic on hovered
        pub fn onHovered(context: *ECSContext, entity: Entity) void {
            const sprite_comp = context.getComponent(entity, SpriteComponent).?;
            sprite_comp.sprite.modulate = Button.Colors.hovered;
        }

        /// Generic on unhovered
        pub fn onUnhovered(context: *ECSContext, entity: Entity) void {
            const sprite_comp = context.getComponent(entity, SpriteComponent).?;
            sprite_comp.sprite.modulate = Button.Colors.unhovered;
        }

        /// Generic on just pressed
        pub fn onJustPressed(context: *ECSContext, entity: Entity) void {
            const sprite_comp = context.getComponent(entity, SpriteComponent).?;
            sprite_comp.sprite.modulate = Button.Colors.pressed;
        }

        /// Generic on clicked
        pub fn onClicked(context: *ECSContext, entity: Entity) void {
            const sprite_comp = context.getComponent(entity, SpriteComponent).?;
            sprite_comp.sprite.modulate = Button.Colors.hovered;
        }
    };

    pub const Widget = union(Type) {
        button: Button,
    };

    widget: Widget = undefined,
    bounds: ?Rect2 = null,
    is_hovered: bool = false,
    owning_entity: ?Entity = null,
    on_hovered: ?*const fn(*ECSContext, Entity) void = null,
    on_unhovered: ?*const fn(*ECSContext, Entity) void = null,
};
