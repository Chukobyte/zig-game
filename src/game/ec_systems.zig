const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;
const game = @import("game.zig");
const comps = @import("components.zig");

const Renderer = zeika.Renderer;
const Vec2 = math.Vec2;
const Rect2 = math.Rect2;
const ECSContext = game.ECSContext;
const ComponentIterator = game.ECSContext.ArchetypeComponentIterator;
const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const TextLabelComponent = comps.TextLabelComponent;
const UIWidgetComponent = comps.UIWidgetComponent;

pub const MainSystem = struct {
    pub fn preContextTick(_: *@This(), _: *ECSContext) void {
        if (zeika.isKeyJustPressed(.keyboard_escape, 0)) {
            game.quit();
        }
    }
};

pub const SpriteRenderingSystem = struct {
    pub fn render(_: *@This(), context: *ECSContext) void {
        var comp_iter = context.compIter(getArchetype());
        while (comp_iter.next()) |iter| {
            const transform_comp = iter.getValue(0);
            const sprite_comp = iter.getValue(1);
            const draw_config = sprite_comp.sprite.getDrawConfig(&transform_comp.transform, 0);
            Renderer.queueDrawSprite(&draw_config);
        }
    }
    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent }; }
};

pub const TextRenderingSystem = struct {
    pub fn render(_: *@This(), context: *ECSContext) void {
        var comp_iter = context.compIter(getArchetype());
        while (comp_iter.next()) |iter| {
            const transform_comp = iter.getValue(0);
            const text_label_comp = iter.getValue(1);
            if (!text_label_comp.text_label.text.isEmpty()) {
                const draw_config = text_label_comp.text_label.getDrawConfig(transform_comp.transform.position, 0);
                Renderer.queueDrawText(&draw_config);
            }
        }
    }
    pub fn getArchetype() []const type { return &.{ TransformComponent, TextLabelComponent }; }
};

pub const UISystem = struct {
    pub fn preContextTick(_: *@This(), context: *ECSContext) void {
        const world_mouse_pos: Vec2 = game.getWorldMousePos();
        const mouse_collider: Rect2 = .{ .x = world_mouse_pos.x, .y = world_mouse_pos.y, .w = 1.0, .h = 1.0 };

        var comp_iter = context.compIter(getArchetype());
        while (comp_iter.next()) |iter| {
            const widget_comp = iter.getValue(0);

            if (widget_comp.bounds) |bounds| {
                const transform_comp = iter.getValue(1);
                const full_bounds = Rect2{
                    .x = transform_comp.transform.position.x + bounds.x,
                    .y = transform_comp.transform.position.y + bounds.y,
                    .w = bounds.w,
                    .h = bounds.h
                };
                const is_mouse_hovering = full_bounds.doesOverlap(&mouse_collider);
                if (!widget_comp.is_hovered and is_mouse_hovering) {
                    widget_comp.is_hovered = true;
                    if (widget_comp.on_hovered) |on_hovered| {
                        on_hovered(context, iter.getEntity());
                    }
                } else if (widget_comp.is_hovered and !is_mouse_hovering) {
                    widget_comp.is_hovered = false;
                    if (widget_comp.on_unhovered) |on_unhovered| {
                        on_unhovered(context, iter.getEntity());
                    }
                }

                switch (widget_comp.widget) {
                    .button => |*button| {
                        if (is_mouse_hovering) {
                            if (zeika.isKeyJustPressed(.mouse_button_left, 0)) {
                                button.is_pressed = true;
                                button.was_just_pressed = true;
                                if (button.on_just_pressed) |on_just_pressed| {
                                    on_just_pressed(context, iter.getEntity());
                                }
                            } else if (zeika.isKeyJustReleased(.mouse_button_left, 0)) {
                                button.is_pressed = false;
                                button.was_just_pressed = false;
                                if (button.on_clicked) |on_clicked| {
                                    on_clicked(context, iter.getEntity());
                                }
                            } else {
                                button.was_just_pressed = false;
                            }
                        } else {
                            button.is_pressed = false;
                            button.was_just_pressed = false;
                        }
                    },
                }
            }
        }
    }
    pub fn getArchetype() []const type { return &.{ UIWidgetComponent, TransformComponent }; }
};
