const std = @import("std");

const zeika = @import("zeika");
const math = zeika.Math;

const Texture = zeika.Texture;
const Renderer = zeika.Renderer;

pub fn main() !void {
    try zeika.init_all("Zig Test", 800, 600, 800, 600);

    var texture = Texture.init_solid_colored_texture(1, 1, 255);
    defer Texture.deinit_texture(&texture);

    while (zeika.is_running()) {
        zeika.update();

        if (zeika.is_key_just_pressed(zeika.InputKey.KeyboardEscape, 0)) {
            break;
        }

        Renderer.queue_draw_sprite(
            &texture,
            &math.Rect2{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
            &math.Vec2{ .x = 64.0, .y = 64.0 },
            &math.Color.Red,
            false, false,
            &math.Transform2D{ .position = math.Vec2{ .x = 100.0, .y = 100.0 } },
            0
        );
        Renderer.flush_batched_sprites();
    }

    zeika.shutdown_all();
}
