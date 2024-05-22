const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const game = @import("game.zig");
const comps = @import("components.zig");

const engine = @import("engine");
const ec = engine.ec;

const Vec2 = math.Vec2;
const Rect2 = math.Rect2;
const Transform2D = math.Transform2D;
const Color = math.Color;

const Texture = zeika.Texture;
const Font = zeika.Font;


const Sprite = engine.core.Sprite;

const ECContext = game.ECContext;
const Entity = ECContext.Entity;
const EntityTemplate = ECContext.EntityTemplate;
const Tags = ECContext.Tags;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const ColliderComponent = comps.ColliderComponent;
const TextLabelComponent = comps.TextLabelComponent;

const SpriteButtonParams = struct {
    sprite: Sprite,
    transform: Transform2D,
    collider_override: ?Rect2 = null,
};

pub inline fn getSpriteButton(params: SpriteButtonParams) EntityTemplate {
    return .{
        .tag_list = Tags.initFromSlice(&.{ "sprite" }),
        .components = .{
            ec.constCompCast(TransformComponent, &.{ .transform = params.transform } ),
            ec.constCompCast(SpriteComponent, &.{ .sprite = params.sprite }),
            null,
            ec.constCompCast(ColliderComponent, &.{ .collider = params.collider_override orelse .{ .x = 0.0, .y = 0.0, .w = params.sprite.size.x, .h = params.sprite.size.y } }),
        },
        .interface = .{
            .update = struct {
                pub fn update(self: *Entity) void {
                    if (self.getComponent(TransformComponent)) |trans_comp| {
                        if (self.getComponent(SpriteComponent)) |sprite_comp| {
                            if (self.getComponent(ColliderComponent)) |collider_comp| {
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
                                        if (self.ec_context.getEntityByTag("text_label")) |text_label_entity| {
                                            if (text_label_entity.getComponent(TextLabelComponent)) |text_label_comp| {
                                                const StaticData = struct {
                                                    var text_buffer: [256]u8 = undefined;
                                                    var money: i32 = 0;
                                                };
                                                StaticData.money += 1;
                                                text_label_comp.text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: {d}", .{ StaticData.money }) catch { unreachable; };
                                            }
                                        }
                                    }
                                } else {
                                    sprite.modulate = Color.Blue;
                                }
                            }
                        }
                    }
                }
            }.update
        },
    };
}

const TextLabelParams = struct {
    font: Font,
    position: Vec2,
    color: Color = Color.White,
};

pub inline fn getTextLabel(params: TextLabelParams) EntityTemplate {
    return .{
        .tag_list = Tags.initFromSlice(&.{ "text_label" }),
        .components = .{
            // ec.constCompCast(TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 200.0 } } }),
            ec.constCompCast(TransformComponent, &.{ .transform = .{ .position = params.position } }),
            null,
            // ec.constCompCast(TextLabelComponent, &.{ .text_label = .{ .font = undefined, .color = Color.Red } }),
            ec.constCompCast(TextLabelComponent, &.{ .text_label = .{ .font = params.font, .color = params.color } }),
            null
        },
        .interface = .{
            .init = struct {
                pub fn init(self: *Entity) void  {
                    const StaticData = struct {
                        var text_buffer: [256]u8 = undefined;
                    };
                    if (self.getComponent(TextLabelComponent)) |text_label_comp| {
                        text_label_comp.text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: 0", .{}) catch { unreachable; };
                    }
                }
            }.init
        },
    };
}

