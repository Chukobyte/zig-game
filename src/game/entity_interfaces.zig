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
const Button = UIWidgetComponent.Button;

fn refreshStatBarLabel(context: *ECSContext) void {
    if (context.getEntityByTag("stat_bar")) |text_label_entity| {
        if (context.getComponent(text_label_entity, TextLabelComponent)) |text_label_comp| {
            PersistentState.get().refreshTextLabel(text_label_comp) catch unreachable;
        }
    }
}

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
                            .widget = .{
                                .button = .{
                                    .on_just_pressed = Button.onJustPressed,
                                    .on_clicked = struct {
                                        pub fn onClicked(con: *ECSContext, ent: Entity) void {
                                            const ui_widget = con.getComponent(ent, UIWidgetComponent).?;
                                            if (ui_widget.owning_entity) |owning_entity| {
                                                const local_self = con.getEntityInterfacePtr(TileInterface, owning_entity).?;
                                                local_self.state = .farm;
                                                defer con.deinitEntity(ent);
                                                local_self.build_farm_button_entity = null;

                                                const tm_comp = con.getComponent(owning_entity, TransformComponent).?;
                                                const hire_farmer_button_transform = Transform2D{
                                                    .position = .{ .x = tm_comp.transform.position.x + 7.0,  .y = tm_comp.transform.position.y + 16.0 },
                                                };
                                                const hire_farmer_button_entity = con.initEntityAndRef(.{ .tags = &.{ "hire_farmer" } }) catch unreachable;
                                                hire_farmer_button_entity.setComponent(TransformComponent, &.{ .transform = hire_farmer_button_transform }) catch unreachable;
                                                hire_farmer_button_entity.setComponent(UIWidgetComponent, &.{
                                                    .widget = .{
                                                        .button = .{
                                                            .on_just_pressed = Button.onJustPressed,
                                                            .on_clicked = struct {
                                                                pub fn onClicked(c: *ECSContext, e: Entity) void {
                                                                    var persistent_state = PersistentState.get();
                                                                    persistent_state.food.value.addScalar(&persistent_state.food.value, 1) catch unreachable;
                                                                    refreshStatBarLabel(c);
                                                                    Button.onClicked(c, e);
                                                                }
                                                            }.onClicked,
                                                        }
                                                    },
                                                    .bounds = .{ .x = 0.0, .y = 0.0, .w = 68.0, .h = 20.0 },
                                                    .owning_entity = owning_entity,
                                                    .on_hovered = Button.onHovered,
                                                    .on_unhovered = Button.onUnhovered,
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
                                                        .text = TextLabel.String.init(con.allocator),
                                                        .color = Color.White,
                                                        .origin = Vec2{ .x = 5.0, .y = 12.0 },
                                                    }
                                                }) catch unreachable;
                                                const hire_farmer_text_label_comp = hire_farmer_button_entity.getComponent(TextLabelComponent).?;
                                                hire_farmer_text_label_comp.text_label.setText("Hire Farmer", .{}) catch unreachable;
                                                local_self.hire_farmer_button_entity = hire_farmer_button_entity;
                                            }
                                        }
                                    }.onClicked,
                                }
                            },
                            .bounds = .{ .x = 0.0, .y = 0.0, .w = 68.0, .h = 20.0 },
                            .owning_entity = entity,
                            .on_hovered = Button.onHovered,
                            .on_unhovered = Button.onUnhovered,
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
