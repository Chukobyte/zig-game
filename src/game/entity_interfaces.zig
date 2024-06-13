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
const WeakEntityRef = ECSContext.WeakEntityRef;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const ColliderComponent = comps.ColliderComponent;
const TextLabelComponent = comps.TextLabelComponent;
const UIWidgetComponent = comps.UIWidgetComponent;

fn refreshStatBarLabel(context: *ECSContext) void {
    if (context.getEntityByTag("stat_bar")) |text_label_entity| {
        if (context.getComponent(text_label_entity, TextLabelComponent)) |text_label_comp| {
            PersistentState.get().refreshTextLabel(text_label_comp) catch unreachable;
        }
    }
}

pub const StatBarInterface = struct {
    // const energy_per_increment = 1;

    // pub fn idleIncrement(_: *@This(), context: *ECSContext, entity: Entity) void {
    //     if (context.getComponent(entity, TextLabelComponent)) |text_label_comp| {
    //         var persistent_state = PersistentState.get();
    //         persistent_state.energy.addScalar(&persistent_state.energy, energy_per_increment) catch unreachable;
    //         persistent_state.refreshTextLabel(text_label_comp) catch unreachable;
    //     }
    // }

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
                var persistent_state = PersistentState.get();
                persistent_state.materials.value.addScalar(&persistent_state.materials.value, 1) catch unreachable;
                refreshStatBarLabel(context);
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
                const transform_comp = context.getComponent(entity, TransformComponent).?;
                const new_tile_entity: WeakEntityRef = context.initEntityAndRef(.{ .interface = TileInterface, .tags = &.{ "tile" } }) catch unreachable;
                const new_tile_transform = transform_comp.transform;
                new_tile_entity.setComponent(TransformComponent, &.{ .transform = new_tile_transform }) catch unreachable;
                new_tile_entity.setComponent(SpriteComponent, &.{
                    .sprite = .{
                        .texture = AssetDB.get().solid_colored_texture,
                        .size = .{ .x = 80.0, .y = 80.0 },
                        .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                        .modulate = .{ .r = 32, .g = 0, .b = 178 },
                    },
                })  catch unreachable;
                new_tile_entity.setComponent(TextLabelComponent, &.{
                    .text_label = .{
                        .font = AssetDB.get().tile_font,
                        .text = TextLabel.String.init(context.allocator),
                        .color = Color.White,
                        .origin = Vec2{ .x = 5.0, .y = 75.0 },
                    }
                }) catch unreachable;
            }
        } else {
            sprite.modulate = Color.White;
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent, UIWidgetComponent }; }
};

// TODO: Move this into a component and ec system
pub const TileInterface = struct {
    const State = enum {
        initial,
        in_battle,
        owned,
        farm,
    };

    battles_won: usize = 0,
    battles_to_fight: usize = 10,
    state: State = .initial,
    build_farm_button_entity: ?WeakEntityRef = null,
    hire_farmer_button_entity: ?WeakEntityRef = null,

    pub fn tick(self: *@This(), context: *ECSContext, entity: Entity) void {
        switch (self.state) {
            .owned => {
                if (self.build_farm_button_entity) |farm_button_entity| {
                    const widget_comp = farm_button_entity.getComponent(UIWidgetComponent).?;
                    const sprite_comp = farm_button_entity.getComponent(SpriteComponent).?;
                    if (widget_comp.is_hovered) {
                        const button: *UIWidgetComponent.ButtonWidget = &widget_comp.widget.button;
                        if (button.is_pressed) {
                            sprite_comp.sprite.modulate = .{ .r = 50, .g = 50, .b = 50 };
                        } else {
                            sprite_comp.sprite.modulate = .{ .r = 200, .g = 200, .b = 200 };
                        }

                        if (button.was_just_pressed) {
                            self.state = .farm;
                            farm_button_entity.deinit();
                            self.build_farm_button_entity = null;

                            const transform_comp = context.getComponent(entity, TransformComponent).?;
                            const hire_farmer_button_transform = Transform2D{
                                .position = .{ .x = transform_comp.transform.position.x + 7.0,  .y = transform_comp.transform.position.y + 16.0 },
                            };
                            const hire_farmer_button_entity = context.initEntityAndRef(.{ .tags = &.{ "hire_farmer" } }) catch unreachable;
                            hire_farmer_button_entity.setComponent(TransformComponent, &.{ .transform = hire_farmer_button_transform }) catch unreachable;
                            hire_farmer_button_entity.setComponent(UIWidgetComponent, &.{
                                .widget = .{ .button = .{} },
                                .bounds = .{ .x = 0.0, .y = 0.0, .w = 68.0, .h = 20.0 },
                            }) catch unreachable;
                            hire_farmer_button_entity.setComponent(SpriteComponent, &.{
                                .sprite = .{
                                    .texture = AssetDB.get().solid_colored_texture,
                                    .size = .{ .x = 68.0, .y = 20.0 },
                                    .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                                    .modulate = .{ .r = 150, .g = 150, .b = 150 },
                                },
                            })  catch unreachable;
                            hire_farmer_button_entity.setComponent(TextLabelComponent, &.{
                                .text_label = .{
                                    .font = AssetDB.get().tile_font,
                                    .text = TextLabel.String.init(context.allocator),
                                    .color = Color.White,
                                    .origin = Vec2{ .x = 5.0, .y = 12.0 },
                                }
                            }) catch unreachable;
                            const hire_farmer_text_label_comp = hire_farmer_button_entity.getComponent(TextLabelComponent).?;
                            hire_farmer_text_label_comp.text_label.setText("Hire Farmer", .{}) catch unreachable;
                            self.hire_farmer_button_entity = hire_farmer_button_entity;
                        }
                    } else {
                        sprite_comp.sprite.modulate = .{ .r = 150, .g = 150, .b = 150 };
                    }
                }
            },
            .farm => {
                if (self.hire_farmer_button_entity) |hire_farmer_button_entity| {
                    const widget_comp = hire_farmer_button_entity.getComponent(UIWidgetComponent).?;
                    const sprite_comp = hire_farmer_button_entity.getComponent(SpriteComponent).?;
                    if (widget_comp.is_hovered) {
                        const button: *UIWidgetComponent.ButtonWidget = &widget_comp.widget.button;
                        if (button.is_pressed) {
                            sprite_comp.sprite.modulate = .{ .r = 50, .g = 50, .b = 50 };
                        } else {
                            sprite_comp.sprite.modulate = Color{ .r = 200, .g = 200, .b = 200 };
                        }

                        if (button.was_just_pressed) {
                            var persistent_state = PersistentState.get();
                            persistent_state.food.value.addScalar(&persistent_state.food.value, 1) catch unreachable;
                            refreshStatBarLabel(context);
                        }
                    } else {
                        sprite_comp.sprite.modulate = .{ .r = 150, .g = 150, .b = 150 };
                    }
                }
            },
            else => {},
        }
    }

    pub fn idleIncrement(self: *@This(), context: *ECSContext, entity: Entity) void {
        switch (self.state) {
            .initial => {
                self.state = .in_battle;
                self.updateBattleText(context, entity);
            },
            .in_battle => {
                if (self.battles_won < self.battles_to_fight) {
                    self.battles_won += 1;
                    self.updateBattleText(context, entity);
                    if (self.battles_won >= self.battles_to_fight) {
                        self.state = .owned;
                        var text_label_comp = context.getComponent(entity, TextLabelComponent).?;
                        text_label_comp.text_label.setText("", .{}) catch unreachable;
                        const transform_comp = context.getComponent(entity, TransformComponent).?;
                        const build_farm_button_transform = Transform2D{
                            .position = .{ .x = transform_comp.transform.position.x + 7.0,  .y = transform_comp.transform.position.y + 16.0 },
                        };
                        const farm_button_entity = context.initEntityAndRef(.{ .tags = &.{ "build_farm" } }) catch unreachable;
                        farm_button_entity.setComponent(TransformComponent, &.{ .transform = build_farm_button_transform }) catch unreachable;
                        farm_button_entity.setComponent(UIWidgetComponent, &.{
                            .widget = .{ .button = .{} },
                            .bounds = .{ .x = 0.0, .y = 0.0, .w = 68.0, .h = 20.0 },
                        }) catch unreachable;
                        farm_button_entity.setComponent(SpriteComponent, &.{
                            .sprite = .{
                                .texture = AssetDB.get().solid_colored_texture,
                                .size = .{ .x = 68.0, .y = 20.0 },
                                .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                                .modulate = .{ .r = 150, .g = 150, .b = 150 },
                            },
                        })  catch unreachable;
                        farm_button_entity.setComponent(TextLabelComponent, &.{
                            .text_label = .{
                                .font = AssetDB.get().tile_font,
                                .text = TextLabel.String.init(context.allocator),
                                .color = Color.White,
                                .origin = Vec2{ .x = 5.0, .y = 12.0 },
                            }
                        }) catch unreachable;
                        const farm_text_label_comp = farm_button_entity.getComponent(TextLabelComponent).?;
                        farm_text_label_comp.text_label.setText("Build Farm", .{}) catch unreachable;
                        self.build_farm_button_entity = farm_button_entity;
                    }
                }
            },
            else => {},
        }
    }

    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent }; }

    inline fn updateBattleText(self: *@This(), context: *ECSContext, entity: Entity) void {
        const text_label_comp = context.getComponent(entity, TextLabelComponent).?;
        text_label_comp.text_label.setText("Battles: {d}/{d}", .{ self.battles_won, self.battles_to_fight }) catch unreachable;
    }
};
