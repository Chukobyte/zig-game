const std = @import("std");

const zeika = @import("zeika");
const assets = @import("assets");

const data_db = @import("engine/object_data_db.zig");
const game = @import("game/game.zig");

const math = zeika.math;
const Vec2 = math.Vec2;
const Rect2 = math.Rect2;
const Transform2D = math.Transform2D;
const Color = math.Color;

const Texture = zeika.Texture;
const Font = zeika.Font;
const Renderer = zeika.Renderer;

const Entity = game.Entity;
const Sprite = game.Sprite;
const TextLabel = game.TextLabel;

pub fn main() !void {
    try zeika.initAll("Zig Test", 800, 450, 800, 450);

    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const default_font: Font = Font.initFromMemory(
        assets.DefaultFont.data,
        assets.DefaultFont.len,
        .{ .font_size = 16, .apply_nearest_neighbor = true }
    );
    defer default_font.deinit();

    var entities = [_]Entity{
        Entity{
            .transform = Transform2D{ .position = Vec2{ .x = 100.0, .y = 100.0 } },
            .sprite = Sprite{
                .texture = texture_handle,
                .size = Vec2{ .x = 64.0, .y = 64.0 },
                .draw_source = Rect2{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
                .modulate = Color.Blue,
            },
            .update_func = struct {
                pub fn update(self: *Entity) void {
                    self.transform.position.x += 0.5;
                }
            }.update,
        },
        Entity{
            .transform = Transform2D{ .position = Vec2{ .x = 100.0, .y = 200.0 } },
            .text_label = TextLabel{
                .font = default_font,
                .color = Color.Red
            },
            .update_func = struct {
                pub fn update(self: *Entity) void {
                    const StaticData = struct {
                        var text_buffer: [256]u8 = undefined;
                        var money: i32 = 0;
                    };
                    if (self.text_label) |*text_label| {
                        text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: {d}", .{ StaticData.money }) catch { unreachable; };
                    }
                    StaticData.money += 1;
                }
            }.update,
        },
    };

    while (zeika.isRunning()) {
        zeika.update();

        if (zeika.isKeyJustPressed(.keyboard_escape, 0)) {
            break;
        }

        // TODO: Prototyping things, eventually will categorize game objects so we don't have conditionals within the update loops

        // Object Updates
        for (&entities) |*entity| {
            if (entity.update_func) |update| {
                update(entity);
            }
        }

        // Render
        for (&entities) |*entity| {
            if (entity.getSpriteDrawConfig()) |draw_config| {
                Renderer.queueDrawSprite(&draw_config);
            }
            if (entity.getTextDrawConfig()) |draw_config| {
                Renderer.queueDrawText(&draw_config);
            }
        }
        Renderer.flushBatches();
    }

    zeika.shutdownAll();
}
