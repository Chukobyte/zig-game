const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const assets = @import("assets");
const engine = @import("engine");

pub const state = @import("state.zig");
pub const comps = @import("components.zig");
pub const ec_systems = @import("ec_systems.zig");
pub const entity_interfaces = @import("entity_interfaces.zig");
pub const asset_db = @import("asset_db.zig");

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

const MainSystem = ec_systems.MainSystem;
const SpriteRenderingSystem = ec_systems.SpriteRenderingSystem;
const TextRenderingSystem = ec_systems.TextRenderingSystem;
const UISystem = ec_systems.UISystem;

const PersistentState = state.PersistentState;

const AddTileButtonInterface = entity_interfaces.AddTileButtonInterface;
const StatBarInterface = entity_interfaces.StatBarInterface;
const TileInterface = entity_interfaces.TileInterface;

const AssetDB = asset_db.AssetDB;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const TextLabelComponent = comps.TextLabelComponent;
const ColliderComponent = comps.ColliderComponent;
const UIWidgetComponent = comps.UIWidgetComponent;
const OnMouseHoveredEvent = UIWidgetComponent.OnMouseHoveredEvent;
const OnMouseUnhoveredEvent = UIWidgetComponent.OnMouseUnhoveredEvent;

pub const GameProperties = struct {
    title: [:0]const u8 = "ZigTest",
    initial_window_size: Vec2i = .{ .x = 800, .y = 450 },
    resolution: Vec2i = .{ .x = 800, .y = 450 },
};

var game_properties = GameProperties{};

pub const ECSContext = ecs.ECSContext(.{
    .entity_interfaces = &.{ AddTileButtonInterface, StatBarInterface, TileInterface },
    .components = &.{ TransformComponent, SpriteComponent, TextLabelComponent, ColliderComponent, UIWidgetComponent },
    .systems = &.{ MainSystem, SpriteRenderingSystem, TextRenderingSystem, UISystem },
});
pub const Entity = ECSContext.Entity;
pub const WeakEntityRef = ECSContext.WeakEntityRef;

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
    var persistent_state = PersistentState.init(std.heap.page_allocator);
    try persistent_state.load();
}

pub inline fn initAndRun(props: GameProperties) !void {
    try init(props);
    try run();
}

pub fn deinit() void {
    var persistent_state = PersistentState.get();
    persistent_state.save() catch unreachable;
    persistent_state.deinit();
    zeika.shutdownAll();
}

fn setupInitialScene(ecs_context: *ECSContext, game_asset_db: *AssetDB) !void {
    // TODO: Start using ui components for positioning
    // Stat bar
    {
        const stat_bar_entity: WeakEntityRef = try ecs_context.initEntityAndRef(.{ .interface = StatBarInterface, .tags = &.{ "stat_bar" } });
        try stat_bar_entity.setComponent(TransformComponent, &.{ .transform = .{ .position = .{ .x = 0.0, .y = 0.0 } } });
        try stat_bar_entity.setComponent(SpriteComponent, &.{
            .sprite = .{
                .texture = game_asset_db.solid_colored_texture,
                .size = .{ .x = @floatFromInt(game_properties.resolution.x), .y = 32 },
                .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = .{ .r = 32, .g = 0, .b = 178 },
            },
        });
        try stat_bar_entity.setComponent(TextLabelComponent, &.{ .text_label = .{
            .font = game_asset_db.default_font, .text = TextLabel.String.init(ecs_context.allocator), .color = .{ .r = 243, .g = 97, .b = 255 }, .origin = .{ .x = 10.0, .y = 20.0 } },
        });
        if (stat_bar_entity.getComponent(TextLabelComponent)) |text_label_comp| {
            const persistent_state = PersistentState.get();
            try persistent_state.refreshTextLabel(text_label_comp);
        }
    }

    // Temp button for searching tile
    {
        const search_tile_entity: WeakEntityRef = try ecs_context.initEntityAndRef(.{ .interface = AddTileButtonInterface, .tags = &.{ "search_tile" } });
        try search_tile_entity.setComponent(TransformComponent, &.{ .transform = .{ .position = .{ .x = 350.0, .y = 200.0 } } });
        try search_tile_entity.setComponent(SpriteComponent, &.{
            .sprite = .{
                .texture = game_asset_db.add_tile_texture,
                .size = .{ .x = 32, .y = 32 },
                .draw_source = .{ .x = 0.0, .y = 0.0, .w = 32.0, .h = 32.0 },
            },
        });
        try search_tile_entity.setComponent(UIWidgetComponent, &.{
            .widget = .{ .button = .{} },
            .bounds = .{ .x = 0.0, .y = 0.0, .w = 32.0, .h = 32.0 },
        });
    }

    // Temp test sprite button widget
    {
        const sprite_button_entity: WeakEntityRef = try ecs_context.initEntityAndRef(.{ .tags = &.{ "sprite" } });
        try sprite_button_entity.setComponent(TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 100.0 } } });
        try sprite_button_entity.setComponent(SpriteComponent, &.{
            .sprite = .{
                .texture = game_asset_db.solid_colored_texture,
                .size = .{ .x = 64.0, .y = 64.0 },
                .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = .{ .r = 32, .g = 0, .b = 178 },
            },
        });
        try sprite_button_entity.setComponent(UIWidgetComponent, &.{
            .widget = .{
                .button = .{
                    .on_just_pressed = struct {
                        pub fn onJustPressed(context: *ECSContext, entity: Entity) void { context.getComponent(entity, SpriteComponent).?.sprite.modulate = Color.White; }
                    }.onJustPressed,
                    .on_clicked = struct {
                        pub fn onClicked(context: *ECSContext, entity: Entity) void {
                            var persistent_state = PersistentState.get();
                            persistent_state.materials.value.addScalar(&persistent_state.materials.value, 1) catch unreachable;
                            if (context.getEntityByTag("stat_bar")) |text_label_entity| {
                                if (context.getComponent(text_label_entity, TextLabelComponent)) |text_label_comp| {
                                    persistent_state.refreshTextLabel(text_label_comp) catch unreachable;
                                }
                            }
                            context.getComponent(entity, SpriteComponent).?.sprite.modulate = Color.Red;
                        }
                    }.onClicked,
                }
            },
            .bounds = .{ .x = 0.0, .y = 0.0, .w = 64.0, .h = 64.0 },
            .on_hovered = struct {
                pub fn onHovered(context: *ECSContext, entity: Entity) void { context.getComponent(entity, SpriteComponent).?.sprite.modulate = Color.Red; }
            }.onHovered,
            .on_unhovered = struct {
                pub fn onUnhovered(context: *ECSContext, entity: Entity) void { context.getComponent(entity, SpriteComponent).?.sprite.modulate = Color.Blue; }
            }.onUnhovered,
        });
    }
}

pub fn run() !void {
    const allocator = std.heap.page_allocator;

    var ecs_context = try ECSContext.init(allocator);
    defer ecs_context.deinit();

    var game_asset_db = AssetDB.init();
    defer game_asset_db.deinit();

    is_game_running = true;

    try setupInitialScene(&ecs_context, game_asset_db);

    var timer = try std.time.Timer.start();

    while (isGameRunning()) {
        const seconds_to_increment: comptime_int = 1;
        const nanoseconds_to_increment: comptime_int = seconds_to_increment * 1_000_000_000;
        const current_time = timer.read();

        ecs_context.newFrame();

        if (current_time >= nanoseconds_to_increment) {
            timer.reset();
            ecs_context.event(.idle_increment);
        }

        zeika.update();
        ecs_context.event(.tick);
        ecs_context.event(.render);
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
