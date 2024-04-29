const std = @import("std");

const seika = @cImport({
    @cInclude("seika/seika.h");
    @cInclude("seika/input/input.h");
});

pub fn main() !void {
    if (!seika.ska_init_all("Zig Game", 800, 600, 800, 600)) {
        std.debug.print("Failed to init seika!", .{});
        return error.SeikaFailedToInit;
    }

    while (seika.ska_is_running()) {
        seika.ska_update();

        if (seika.ska_input_is_key_just_pressed(seika.SkaInputKey_KEYBOARD_ESCAPE, 0)) {
            break;
        }

        seika.ska_window_render();
    }

    seika.ska_shutdown_all();
}
