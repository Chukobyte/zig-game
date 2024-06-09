const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const assets = @import("assets");
const engine = @import("engine");

pub const state = @import("state.zig");
pub const comps = @import("components.zig");
pub const ec_systems = @import("ec_systems.zig");
pub const entity_interfaces = @import("entity_interfaces.zig");

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

const SpriteButtonInterface = entity_interfaces.SpriteButtonInterface;
const StatBarInterface = entity_interfaces.StatBarInterface;

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
    .entity_interfaces = &.{ SpriteButtonInterface, StatBarInterface },
    .components = &.{ TransformComponent, SpriteComponent, TextLabelComponent, ColliderComponent, UIWidgetComponent },
    .systems = &.{ MainSystem, SpriteRenderingSystem, TextRenderingSystem, UISystem },
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

pub fn run() !void {
    // Acts as a temp in place struct for where init, setup, and deinit will be done at a scene level
    const Scene = struct {

        const AssetsContainer = struct {
            stat_bar_font: Font,
            add_tile_texture: Texture.Handle,
            solid_colored_texture: Texture.Handle,

            fn init() @This() {
                return @This(){
                    .stat_bar_font = Font.initFromMemory(
                        assets.DefaultFont.data,
                        assets.DefaultFont.len,
                        .{ .font_size = 16, .apply_nearest_neighbor = true }
                    ),
                    .add_tile_texture = Texture.initFromMemory(
                        assets.AddTileTexture.data,
                        assets.AddTileTexture.len
                    ),
                    .solid_colored_texture = Texture.initSolidColoredTexture(1, 1, 255),
                };
            }

            fn deinit(self: *@This()) void {
                self.stat_bar_font.deinit();
                self.add_tile_texture.deinit();
                self.solid_colored_texture.deinit();
            }
        };

        allocator: std.mem.Allocator,
        ecs_context: *ECSContext,
        assets: AssetsContainer,

        pub fn init(allocator: std.mem.Allocator, ecs_context: *ECSContext) !@This() {
            return @This(){
                .allocator = allocator,
                .ecs_context = ecs_context,
                .assets = AssetsContainer.init(),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.assets.deinit();
        }

        pub fn setupInitialScene(self: *@This()) !void {
            // TODO: Start using ui components for positioning
            // Stat bar
            {
                const stat_bar_entity = try self.ecs_context.initEntity(.{ .tags = &.{ "stat_bar" } });
                try self.ecs_context.setComponent(stat_bar_entity, TransformComponent, &.{ .transform = .{ .position = .{ .x = 0.0, .y = 0.0 } } });
                try self.ecs_context.setComponent(stat_bar_entity, SpriteComponent, &.{
                    .sprite = .{
                        .texture = self.assets.solid_colored_texture,
                        .size = .{ .x = @floatFromInt(game_properties.resolution.x), .y = 32 },
                        .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                        .modulate = .{ .r = 32, .g = 0, .b = 178 },
                    },
                });

                const energy_label_entity = try self.ecs_context.initEntity(.{ .interface = StatBarInterface, .tags = &.{ "text_label" } });
                try self.ecs_context.setComponent(energy_label_entity, TransformComponent, &.{ .transform = .{ .position = .{ .x = 10.0, .y = 20.0 } } });
                try self.ecs_context.setComponent(energy_label_entity, TextLabelComponent, &.{ .text_label = .{
                    .font = self.assets.stat_bar_font, .text = TextLabel.String.init(self.allocator), .color = .{ .r = 243, .g = 97, .b = 255 } },
                });
                if (self.ecs_context.getComponent(energy_label_entity, TextLabelComponent)) |text_label_comp| {
                    const persistent_state = PersistentState.get();
                    try persistent_state.refreshTextLabel(text_label_comp);
                }
            }

            // Temp test sprite button widget
            {
                const sprite_button_entity = try self.ecs_context.initEntity(.{ .interface = SpriteButtonInterface, .tags = &.{ "sprite" } });
                try self.ecs_context.setComponent(sprite_button_entity, TransformComponent, &.{ .transform = .{ .position = .{ .x = 100.0, .y = 100.0 } } });
                try self.ecs_context.setComponent(sprite_button_entity, SpriteComponent, &.{
                    .sprite = .{
                        .texture = self.assets.solid_colored_texture,
                        .size = .{ .x = 64.0, .y = 64.0 },
                        .draw_source = .{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                        .modulate = .{ .r = 32, .g = 0, .b = 178 },
                    },
                });
                try self.ecs_context.setComponent(sprite_button_entity, UIWidgetComponent, &.{
                    .widget = .{ .button = .{} },
                    .bounds = .{ .x = 0.0, .y = 0.0, .w = 64.0, .h = 64.0 },
                });
                var widget_comp: *UIWidgetComponent = self.ecs_context.getComponent(sprite_button_entity, UIWidgetComponent).?;
                widget_comp.on_mouse_hovered = OnMouseHoveredEvent.init(self.allocator);
                widget_comp.on_mouse_unhovered = OnMouseUnhoveredEvent.init(self.allocator);
            }
        }
    };

    const allocator = std.heap.page_allocator;

    var ecs_context = try ECSContext.init(allocator);
    defer ecs_context.deinit();

    is_game_running = true;

    var scene = try Scene.init(allocator, &ecs_context);
    defer scene.deinit();
    try scene.setupInitialScene();

    var timer = try std.time.Timer.start();

    while (isGameRunning()) {
        const seconds_to_increment: comptime_int = 1;
        const nanoseconds_to_increment: comptime_int = seconds_to_increment * 1_000_000_000;
        const current_time = timer.read();
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
