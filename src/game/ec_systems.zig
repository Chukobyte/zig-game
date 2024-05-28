const zeika = @import("zeika");

const game = @import("game.zig");
const comps = @import("components.zig");

const Renderer = zeika.Renderer;

const ECSContext = game.ECSContext;
const ComponentIterator = game.ECSContext.ArchetypeComponentIterator;

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
        var comp_iter = ComponentIterator(getArchetype()).init(context);
        while (comp_iter.next()) |iter| {
            const transform_comp = iter.getValue(0);
            const sprite_comp = iter.getValue(1);
            const draw_config = sprite_comp.sprite.getDrawConfig(&transform_comp.transform, 0);
            Renderer.queueDrawSprite(&draw_config);
        }
    }
    pub fn getArchetype() []const type { return &.{ TransformComponent, SpriteComponent }; }
};

pub const TextRenderingSystem = struct {
    pub fn render(self: *@This(), context: *ECSContext) void {
        _ = self;
        var comp_iter = ComponentIterator(getArchetype()).init(context);
        while (comp_iter.next()) |iter| {
            const transform_comp = iter.getValue(0);
            const text_label_comp = iter.getValue(1);
            if (!text_label_comp.text_label.text.isEmpty()) {
                const draw_config = text_label_comp.text_label.getDrawConfig(transform_comp.transform.position, 0);
                Renderer.queueDrawText(&draw_config);
            }
        }
    }
    pub fn getArchetype() []const type { return &.{ TransformComponent, TextLabelComponent }; }
};
