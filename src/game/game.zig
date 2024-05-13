const zeika = @import("zeika");
const assets = @import("assets");

const seika = zeika.seika;
const math = zeika.math;

const Vec2 = math.Vec2;
const Transform2D = math.Transform2D;
const Rect2 = math.Rect2;
const Color = math.Color;

const Renderer = zeika.Renderer;
const Texture = zeika.Texture;
const Font = zeika.Font;

pub const Sprite = struct {
    texture: Texture.Handle,
    draw_source: Rect2,
    size: Vec2,
    origin: Vec2 = Vec2.Zero,
    flip_h: bool = false,
    flip_v: bool = false,
    modulate: Color = Color.White,
};

pub const TextLabel = struct {
    font: Font,
    text: []u8 = undefined,
    color: Color = Color.White,
};

pub const Entity = struct {
    transform: Transform2D = Transform2D.Identity,
    z_index: i32 = 0,
    sprite: ?Sprite = null,
    text_label: ?TextLabel = null,

    on_enter_scene_func: ?*const fn(self: *@This()) void = null,
    on_exit_scene_func: ?*const fn(self: *@This()) void = null,
    update_func: ?*const fn(self: *@This()) void = null,

    pub fn getSpriteDrawConfig(self: *const @This()) ?Renderer.SpriteDrawQueueConfig {
        if (self.sprite) |sprite| {
            return Renderer.SpriteDrawQueueConfig{
                .texture_handle = sprite.texture,
                .draw_source = sprite.draw_source,
                .size = sprite.size,
                .transform = &self.transform,
                .color = sprite.modulate,
                .flip_h = sprite.flip_h,
                .flip_v = sprite.flip_v,
                .z_index = self.z_index,
            };
        }
        return null;
    }

    pub fn getTextDrawConfig(self: *const @This()) ?Renderer.TextDrawQueueConfig {
        if (self.text_label) |text_label| {
            return Renderer.TextDrawQueueConfig{
                .font = text_label.font,
                .text = text_label.text,
                .position = self.transform.position,
                .color = text_label.color,
                .z_index = self.z_index,
            };
        }
        return null;
    }
};
