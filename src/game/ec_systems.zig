const zeika = @import("zeika");

const game = @import("game.zig");
const comps = @import("components.zig");

const Renderer = zeika.Renderer;

const ECSContext = game.ECSContext;

const TransformComponent = comps.TransformComponent;
const SpriteComponent = comps.SpriteComponent;
const TextLabelComponent = comps.TextLabelComponent;

pub const MainSystem = struct {
    pub fn preContextTick(self: *@This(), context: *ECSContext) void {
        _ = self; _ = context;
        if (zeika.isKeyJustPressed(.keyboard_escape, 0)) {
            game.quit();
        }
    }
};

pub const SpriteRenderingSystem = struct {
    pub fn render(self: *@This(), context: *ECSContext) void {
        _ = self;
        for (0..context.entity_data_list.items.len) |entity| {
            if (context.getComponent(entity, TransformComponent)) |transform_comp| {
                if (context.getComponent(entity, SpriteComponent)) |sprite_comp| {
                    const draw_config = sprite_comp.sprite.getDrawConfig(&transform_comp.transform, 0);
                    Renderer.queueDrawSprite(&draw_config);
                }
            }
        }
    }
    pub fn getComponentTypes() []const type { return &.{ TransformComponent, SpriteComponent }; }
};

pub const TextRenderingSystem = struct {
    pub fn render(self: *@This(), context: *ECSContext) void {
        _ = self;
        for (0..context.entity_data_list.items.len) |entity| {
            if (context.getComponent(entity, TransformComponent)) |transform_comp| {
                if (context.getComponent(entity, TextLabelComponent)) |text_label_comp| {
                    if (!text_label_comp.text_label.text.isEmpty()) {
                        const draw_config = text_label_comp.text_label.getDrawConfig(transform_comp.transform.position, 0);
                        Renderer.queueDrawText(&draw_config);
                    }
                }
            }
        }
    }
    pub fn getComponentTypes() []const type { return &.{ TransformComponent, TextLabelComponent }; }
};
