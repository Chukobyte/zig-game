const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const assets = @import("assets");
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
const Camera = core.Camera;
const GameProperties = core.GameProperties;

const comps = @import("components.zig");
const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const TextLabelComponent = comps.TextLabelComponent;
const ColliderComponent = comps.ColliderComponent;

var game_properties = GameProperties{};

pub const ECContext = ec.ECContext(u32, &.{ TransformComponent, SpriteComponent, TextLabelComponent, ColliderComponent });
pub var ec_context: ECContext = undefined;

pub fn init(props: GameProperties) !void {
    game_properties = props;
    try zeika.initAll(
        game_properties.title,
        game_properties.initial_window_size.x,
        game_properties.initial_window_size.y,
        game_properties.resolution.x,
        game_properties.resolution.y
    );
}

pub fn deinit() void {
    zeika.shutdownAll();
}

pub fn run() !void {
    ec_context = ECContext.init(std.heap.page_allocator);
    defer ec_context.deinit();
    const Entity = ECContext.Entity;
    const Tags = ECContext.Tags;

    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const default_font: Font = Font.initFromMemory(
        assets.DefaultFont.data,
        assets.DefaultFont.len,
        .{ .font_size = 16, .apply_nearest_neighbor = true }
    );
    defer default_font.deinit();

    _ = try ec_context.initEntity(&.{
        .tag_list = Tags.initFromSlice(&.{ "sprite" }),
        .components = .{
            ec.constCompCast(TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 100.0 } } }),
            ec.constCompCast(SpriteComponent, &.{ .sprite = .{ .texture = texture_handle, .size = .{ .x = 64.0, .y = 64.0 }, .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 }, .modulate = Color.Blue } }),
            null,
            ec.constCompCast(ColliderComponent, &.{ .collider = .{ .x = 0.0, .y = 0.0, .w = 64.0, .h = 64.0 } }),
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
                                const world_mouse_pos: Vec2 = getWorldMousePos();
                                const entity_collider = Rect2{
                                    .x = transform.position.x + collider.x,
                                    .y = transform.position.y + collider.y,
                                    .w = collider.w,
                                    .h = collider.h
                                };
                                const mouse_collider = Rect2{ .x = world_mouse_pos.x, .y = world_mouse_pos.y, .w = 1.0, .h = 1.0 };
                                if (entity_collider.doesOverlap(&mouse_collider)) {
                                    if (zeika.isKeyPressed(.mouse_button_left, 0)) {
                                        sprite.modulate = Color.White;
                                    } else {
                                        sprite.modulate = Color.Red;
                                    }

                                    if (zeika.isKeyJustPressed(.mouse_button_left, 0)) {
                                        if (ec_context.getEntityByTag("text_label")) |text_label_entity| {
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
    });

    _ = try ec_context.initEntity(&.{
        .tag_list = Tags.initFromSlice(&.{ "text_label" }),
        .components = .{
            ec.constCompCast(TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 200.0 } } }),
            null,
            ec.constCompCast(TextLabelComponent, &.{ .text_label = .{ .font = default_font, .color = Color.Red } }),
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
    });

    while (zeika.isRunning()) {
        zeika.update();

        if (zeika.isKeyJustPressed(.keyboard_escape, 0)) {
            break;
        }

        ec_context.updateEntities();

        ec_context.renderEntities();

        Renderer.flushBatches();
    }
}

pub fn getWorldMousePos( ) Vec2 {
    const mouse_pos: Vec2 = zeika.getMousePosition();
    const game_window_size: Vec2i = zeika.getWindowSize();
    const game_resolution = game_properties.resolution;
    const global_camera = Camera{};
    const mouse_pixel_coord = Vec2{
        .x = math.mapToRange(f32, mouse_pos.x, 0.0, @floatFromInt(game_window_size.x), 0.0, @floatFromInt(game_resolution.x)),
        .y = math.mapToRange(f32, mouse_pos.y, 0.0, @floatFromInt(game_window_size.y), 0.0, @floatFromInt(game_resolution.y))
    };
    const mouse_world_pos = Vec2{
        .x = (global_camera.viewport.x + global_camera.offset.x + mouse_pixel_coord.x) * global_camera.zoom.x,
        .y = (global_camera.viewport.y + global_camera.offset.y + mouse_pixel_coord.y) * global_camera.zoom.y
    };
    return mouse_world_pos;
}
