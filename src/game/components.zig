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
};

pub const ColliderComponent = struct {
    collider: Rect2,
};

pub const UIWidgetComponent = struct {
    pub const Type = enum {
        button,
    };

    pub const ButtonWidget = struct {
        on_clicked: ?*const fn(Entity) void = null,
        is_pressed: bool = false,
        was_just_pressed: bool = false, // If just pressed this frame
    };

    pub const Widget = union(Type) {
        button: ButtonWidget,
    };

    widget: Widget = undefined,
    bounds: ?Rect2 = null,
    is_hovered: bool = false,
};
