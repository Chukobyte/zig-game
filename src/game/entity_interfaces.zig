const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const comps = @import("components.zig");
const state = @import("state.zig");
const asset_db = @import("asset_db.zig");

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

const AssetDB = asset_db.AssetDB;

const ECSContext = @import("game.zig").ECSContext;
const Entity = ECSContext.Entity;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const ColliderComponent = comps.ColliderComponent;
const TextLabelComponent = comps.TextLabelComponent;
const UIWidgetComponent = comps.UIWidgetComponent;

pub const StatBarInterface = struct {
    const energy_per_increment = 1;

    pub fn idleIncrement(_: *@This(), context: *ECSContext, entity: Entity) void {
        if (context.getComponent(entity, TextLabelComponent)) |text_label_comp| {
            var persistent_state = PersistentState.get();
            // persistent_state.energy.addScalar(&persistent_state.energy, energy_per_increment) catch unreachable;
            persistent_state.refreshTextLabel(text_label_comp) catch unreachable;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, TextLabelComponent }; }
};

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
                        persistent_state.materials.value.addScalar(&persistent_state.materials.value, 1) catch unreachable;
                        persistent_state.refreshTextLabel(text_label_comp) catch unreachable;
                    }
                }
            }
        } else {
            sprite.modulate = Color.Blue;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent, UIWidgetComponent }; }
};

pub const AddTileButtonInterface = struct {
    pub fn tick(_: *@This(), context: *ECSContext, entity: Entity) void {
        const sprite_comp = context.getComponent(entity, SpriteComponent).?;
        const widget_comp = context.getComponent(entity, UIWidgetComponent).?;

        var sprite = &sprite_comp.sprite;
        if (widget_comp.is_hovered) {
            const button: *UIWidgetComponent.ButtonWidget = &widget_comp.widget.button;
            if (button.is_pressed) {
                sprite.modulate = Color{ .r = 100, .g = 100, .b = 100 };
            } else {
                sprite.modulate = Color{ .r = 366, .g = 366, .b = 366 };
            }

            if (button.was_just_pressed) {
                defer context.deinitEntity(entity);
                const new_tile_entity: Entity = context.initEntity(.{ .tags = &.{ "tile" } }) catch unreachable;
                const transform_comp = context.getComponent(entity, TransformComponent).?;
                context.setComponent(new_tile_entity, TransformComponent, &.{ .transform = transform_comp.transform }) catch unreachable;
                context.setComponent(new_tile_entity, SpriteComponent, &.{
                    .sprite = .{
                        .texture = AssetDB.get().solid_colored_texture,
                        .size = .{ .x = 64.0, .y = 64.0 },
                        .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                        .modulate = .{ .r = 32, .g = 0, .b = 178 },
                    },
                })  catch unreachable;
            }
        } else {
            sprite.modulate = Color.White;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent, UIWidgetComponent }; }
};
