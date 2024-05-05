const std = @import("std");

const zeika = @import("zeika");

const ecs = @import("engine/asset.zig");
const data_db = @import("engine/object_data_db.zig");

const math = zeika.math;

const Texture = zeika.Texture;
const Renderer = zeika.Renderer;

pub fn main() !void {
    ecs.ECS(.{ Texture });

    try zeika.initAll("Zig Test", 800, 600, 800, 600);

    const texture_handle: Texture.Handle = Texture.initSolidColoredTexture(1, 1, 255);
    defer Texture.deinit(texture_handle);

    const spriteDrawData = Renderer.SpriteDrawQueueConfig{
        .texture_handle = texture_handle,
        .draw_source = math.Rect2{ .x = 0.0, .y = 0.0, .w = 1.0, .h = 1.0 },
        .size = math.Vec2{ .x = 64.0, .y = 64.0 },
        .transform = &math.Transform2D{ .position = math.Vec2{ .x = 100.0, .y = 100.0 } },
        .color = math.Color.Red,
    };

    // Quick test
    var data_db_inst = data_db.ObjectDataDB.init(std.heap.page_allocator);
    defer data_db_inst.deinit();
    const temp_object = try data_db_inst.createObject("Test");
    try data_db_inst.writeProperty(temp_object, "age", i32, 8);
    // const obj_age = data_db_inst.readProperty(temp_object, "age", i32);
    // std.debug.print("obj_age = {}", .{ obj_age });
    
    while (zeika.isRunning()) {
        zeika.update();

        if (zeika.isKeyJustPressed(zeika.InputKey.keyboard_escape, 0)) {
            break;
        }

        Renderer.queueDrawSprite(&spriteDrawData);
        Renderer.flushBatchedSprites();
    }

    zeika.shutdownAll();
}
