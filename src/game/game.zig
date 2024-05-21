const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const assets = @import("assets");

const core = @import("core.zig");
const ec = @import("../engine/entity_component/entity_component.zig");

const Renderer = zeika.Renderer;
const Texture = zeika.Texture;
const Font = zeika.Font;
const Vec2 = zeika.math.Vec2;
const Vec2i = zeika.math.Vec2i;
const Rect2 = zeika.math.Rect2;
const Color = zeika.math.Color;

const World = core.World;
const Entity = core.Entity;
const Sprite = core.Sprite;
const TextLabel = core.TextLabel;
const Collision = core.Collision;
const Camera = core.Camera;
const GameProperties = core.GameProperties;

const TransformComponent = struct {
    transform: math.Transform2D = math.Transform2D.Identity,
};

const SpriteComponent = struct {
    sprite: Sprite,
};

const TextLabelComponent = struct {
    text_label: TextLabel,
};

const ECContext = ec.ECContext(u32, &.{ TransformComponent, SpriteComponent, TextLabelComponent });

var game_properties = GameProperties{};
var gloabal_world: World = undefined;

pub fn init(props: GameProperties) !void {
    game_properties = props;
    try zeika.initAll(
        game_properties.title,
        game_properties.initial_window_size.x,
        game_properties.initial_window_size.y,
        game_properties.resolution.x,
        game_properties.resolution.y
    );
    gloabal_world = World.init(std.heap.page_allocator);

}

pub fn deinit() void {
    gloabal_world.deinit();
    zeika.shutdownAll();
}

pub fn run() !void {
    var ec_context = ECContext.init(std.heap.page_allocator);
    defer ec_context.deinit();

    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const default_font: Font = Font.initFromMemory(
        assets.DefaultFont.data,
        assets.DefaultFont.len,
        .{ .font_size = 16, .apply_nearest_neighbor = true }
    );
    defer default_font.deinit();

    const sprite_interface = Entity.Interface{
        .update = struct {
            pub fn update(self: *Entity) void {
                if (self.sprite) |*sprite| {
                    if (self.collision) |*collision| {
                        const world_mouse_pos: Vec2 = getWorldMousePos();
                        const entity_collider = Rect2{
                            .x = self.transform.position.x + collision.collider.x,
                            .y = self.transform.position.y + collision.collider.y,
                            .w = collision.collider.w,
                            .h = collision.collider.h
                        };
                        const mouse_collider = Rect2{ .x = world_mouse_pos.x, .y = world_mouse_pos.y, .w = 1.0, .h = 1.0 };
                        if (entity_collider.doesOverlap(&mouse_collider)) {
                            if (zeika.isKeyPressed(.mouse_button_left, 0)) {
                                sprite.modulate = Color.White;
                            } else {
                                sprite.modulate = Color.Red;
                            }

                            if (zeika.isKeyJustPressed(.mouse_button_left, 0)) {
                                if (gloabal_world.getEntityByTag("text_label")) |text_label_entity| {
                                    if (text_label_entity.text_label) |*text_label| {
                                        const StaticData = struct {
                                            var text_buffer: [256]u8 = undefined;
                                            var money: i32 = 0;
                                        };
                                        StaticData.money += 1;
                                        text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: {d}", .{ StaticData.money }) catch { unreachable; };
                                    }
                                }
                            }
                        } else {
                            sprite.modulate = Color.Blue;
                        }
                    }
                }
            }
        }.update,
    };

    const text_label_interface = Entity.Interface{
        .on_enter_scene = struct {
            pub fn on_enter_scene(self: *Entity) void  {
                const StaticData = struct {
                    var text_buffer: [256]u8 = undefined;
                };
                if (self.text_label) |*text_label| {
                    text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: 0", .{}) catch { unreachable; };
                }
            }
        }.on_enter_scene,
    };

    const entities = [_]Entity{
        Entity{
            .transform = .{ .position = .{ .x = 100.0, .y = 100.0 } },
            .tag_list = Entity.Tags.initFromSlice(&.{ "sprite" }),
            .sprite = Sprite{
                .texture = texture_handle,
                .size = .{ .x = 64.0, .y = 64.0 },
                .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = Color.Blue,
            },
            .collision = Collision{ .collider = .{ .x = 0.0, .y = 0.0, .w = 64.0, .h = 64.0 } },
            .interface = sprite_interface,
        },
        Entity{
            .transform = .{ .position = .{ .x = 100.0, .y = 200.0 } },
            .tag_list = Entity.Tags.initFromSlice(&.{ "text_label" }),
            .text_label = .{
                .font = default_font,
                .color = Color.Red
            },
            .interface = text_label_interface,
        },
    };
    _ = try gloabal_world.registerEntities(&entities);

    while (zeika.isRunning()) {
        zeika.update();

        if (zeika.isKeyJustPressed(.keyboard_escape, 0)) {
            break;
        }

        // TODO: Prototyping things, eventually will categorize game objects so we don't have conditionals within the update loops

        // Object Updates
        for (gloabal_world.entities.items) |*entity| {
            if (entity.interface.update) |update| {
                update(entity);
            }
        }

        // Render
        for (gloabal_world.entities.items) |*entity| {
            if (entity.*.getSpriteDrawConfig()) |draw_config| {
                Renderer.queueDrawSprite(&draw_config);
            }
            if (entity.getTextDrawConfig()) |draw_config| {
                Renderer.queueDrawText(&draw_config);
            }
        }
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
