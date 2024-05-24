const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const assets = @import("assets");
const engine = @import("engine");

const comps = @import("components.zig");
const ec_systems = @import("ec_systems.zig");
const entity_interfaces = @import("entity_interfaces.zig");

const core = engine.core;
const ecs = engine.ecs;

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

const MainSystem = ec_systems.MainSystem;
const SpriteRenderingSystem = ec_systems.SpriteRenderingSystem;
const TextRenderingSystem = ec_systems.TextRenderingSystem;

const SpriteButtonInterface = entity_interfaces.SpriteButtonInterface;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const TextLabelComponent = comps.TextLabelComponent;
const ColliderComponent = comps.ColliderComponent;

var game_properties = GameProperties{};

pub const ECSContext = ecs.ECSContext(.{
    .components = &.{ TransformComponent, SpriteComponent, TextLabelComponent, ColliderComponent },
    .systems = &.{ MainSystem, SpriteRenderingSystem, TextRenderingSystem },
});

var is_game_running = false;

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

pub inline fn initAndRun(props: GameProperties) !void {
    try init(props);
    try run();
}

pub fn deinit() void {
    zeika.shutdownAll();
}

pub fn run() !void {
    is_game_running = true;
    const allocator = std.heap.page_allocator;

    var ecs_context = try ECSContext.init(allocator);
    defer ecs_context.deinit();

    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const default_font: Font = Font.initFromMemory(
        assets.DefaultFont.data,
        assets.DefaultFont.len,
        .{ .font_size = 16, .apply_nearest_neighbor = true }
    );
    defer default_font.deinit();

    const sprite_button_entity = try ecs_context.initEntity(.{ .interface_type = SpriteButtonInterface, .tags = &.{ "sprite" } });
    try ecs_context.setComponent(sprite_button_entity, TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 100.0 } } });
    try ecs_context.setComponent(sprite_button_entity, SpriteComponent, &.{
        .sprite = .{
            .texture = texture_handle,
            .size = .{ .x = 64.0, .y = 64.0 },
            .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
            .modulate = Color.Blue
        },
    });

    const text_label_entity = try ecs_context.initEntity(.{});
    try ecs_context.setComponent(text_label_entity, TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 200.0 } } });
    try ecs_context.setComponent(text_label_entity, TextLabelComponent, &.{ .text_label = .{
        .font = default_font, .text = try TextLabel.String.initAndSet(allocator, "Money: 0", .{}), .color = Color.Red }
    });

    while (isGameRunning()) {
        zeika.update();
        ecs_context.tick();
        ecs_context.render();
        Renderer.flushBatches();
    }
}

pub inline fn isGameRunning() bool {
    return zeika.isRunning() and is_game_running;
}

pub fn quit() void {
    is_game_running = false;
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
