const std = @import("std");

const zeika = @import("zeika");

const data_db = @import("engine/object_data_db.zig");
const game = @import("game/game.zig");

const math = zeika.math;
const Vec2 = math.Vec2;
const Rect2 = math.Rect2;
const Transform2D = math.Transform2D;
const Color = math.Color;

const Texture = zeika.Texture;
const Renderer = zeika.Renderer;

const GameObject = game.GameObject;
const Sprite = game.Sprite;

pub fn main() !void {
    try zeika.initAll("Zig Test", 800, 600, 800, 600);

    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const game_objects = [_]GameObject{
        GameObject{
            .transform = Transform2D{ .position = Vec2{ .x = 100.0, .y = 100.0 } },
            .sprite = Sprite{
                .texture = texture_handle,
                .size = Vec2{ .x = 64.0, .y = 64.0 },
                .draw_source = Rect2{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = Color.Red,
            },
        },
        GameObject{
            .transform = Transform2D{ .position = Vec2{ .x = 200.0, .y = 100.0 } },
            .sprite = Sprite{
                .texture = texture_handle,
                .size = Vec2{ .x = 64.0, .y = 64.0 },
                .draw_source = Rect2{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = Color.Blue,
            },
        },
    };

    while (zeika.isRunning()) {
        zeika.update();

        if (zeika.isKeyJustPressed(zeika.InputKey.keyboard_escape, 0)) {
            break;
        }

        for (game_objects) |object| {
            if (object.getSpriteDrawConfig()) |draw_config| {
                Renderer.queueDrawSprite(&draw_config);
            }
        }
        Renderer.flushBatchedSprites();
    }

    zeika.shutdownAll();
}
