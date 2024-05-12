const zeika = @import("zeika");
const seika = zeika.seika;
const math = zeika.math;

const Vec2 = math.Vec2;
const Transform2D = math.Transform2D;
const Rect2 = math.Rect2;
const Color = math.Color;

const Renderer = zeika.Renderer;
const Texture = zeika.Texture;

pub const Font = struct {
    font: [*c]seika.SkaFont,
};

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
    text: []u8,
    modulate: Color = Color.White,
};

pub const GameObject = struct {
    transform: Transform2D = Transform2D.Identity,
    z_index: i32 = 0,
    sprite: ?Sprite = null,
    text_label: ?TextLabel = null,
    update_func: ?*const fn(self: *@This()) void = null,

    pub fn getSpriteDrawConfig(self: *const @This()) ?Renderer.SpriteDrawQueueConfig {
        if (self.sprite) |sprite| {
            return Renderer.SpriteDrawQueueConfig{
                .texture_handle = sprite.texture,
                .draw_source = sprite.draw_source,
                .size = sprite.size,
                .transform = &self.transform,
                .color = sprite.modulate,
            };
        }
        return null;
    }
};
