const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const game = @import("game.zig");
const comps = @import("components.zig");
const state = @import("state.zig");

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

const PersistentState = state.PersistentState;

const ECSContext = game.ECSContext;
const Entity = ECSContext.Entity;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const ColliderComponent = comps.ColliderComponent;
const TextLabelComponent = comps.TextLabelComponent;
const UIWidgetComponent = comps.UIWidgetComponent;

pub const SpriteButtonInterface = struct {
    pub fn tick(self: *@This(), context: *ECSContext, entity: Entity) void {
        _ = self;
        const sprite_comp = context.getComponent(entity, SpriteComponent).?;
        const widget_comp = context.getComponent(entity, UIWidgetComponent).?;

        var sprite = &sprite_comp.sprite;
        if (widget_comp.is_hovered) {
            const button: *UIWidgetComponent.ButtonWidget = &widget_comp.widget.button;
            if (button.is_pressed) {
                sprite.modulate = Color.White;
            } else {
                sprite.modulate = Color.Red;
            }

            if (button.was_just_pressed) {
                if (context.getEntityByTag("text_label")) |text_label_entity| {
                    if (context.getComponent(text_label_entity, TextLabelComponent)) |text_label_comp| {
                        var persistent_state = PersistentState.get();
                        persistent_state.energy.addScalar(&persistent_state.energy, 1) catch unreachable;
                        text_label_comp.text_label.setText("Energy: {any}", .{ persistent_state.energy }) catch unreachable;
                    }
                }
            }
        } else {
            sprite.modulate = Color.Blue;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent, ColliderComponent }; }
};

pub const EnergyTextLabelInterface = struct {
    pub fn idleIncrement(self: *@This(), context: *ECSContext, entity: Entity) void {
        _ = self;
        const energyPerIncrement = 1;
        if (context.getComponent(entity, TextLabelComponent)) |text_label_comp| {
            var persistent_state = PersistentState.get();
            persistent_state.energy.addScalar(&persistent_state.energy, energyPerIncrement) catch unreachable;
            text_label_comp.text_label.setText("Energy: {any}", .{ persistent_state.energy }) catch unreachable;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, TextLabelComponent }; }
};