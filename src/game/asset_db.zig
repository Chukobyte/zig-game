///! Asset database use for game assets.
///! Would like to use 'object_data_db.zig' in the future for this

const zeika = @import("zeika");

const assets = @import("assets");

const Texture = zeika.Texture;
const Font = zeika.Font;

pub const AssetDB = struct {

    const Static = struct {
        var instance: ?AssetDB = null;
    };

    default_font: Font,
    tile_font: Font,

    solid_colored_texture: Texture,
    add_tile_texture: Texture,

    pub fn init() *@This() {
        Static.instance = @This(){
            .default_font = Font.initFromMemory(&.{
                .buffer = assets.DefaultFont.ptr,
                .buffer_len = assets.DefaultFont.len,
                .font_size = 16,
                .apply_nearest_neighbor = true
            }),
            .tile_font = Font.initFromMemory(&.{
                .buffer = assets.DefaultFont.ptr,
                .buffer_len = assets.DefaultFont.len,
                .font_size = 10,
                .apply_nearest_neighbor = true
            }),
            .solid_colored_texture = Texture.initSolidColoredTexture(1, 1, 255),
            .add_tile_texture = Texture.initFromMemory(assets.AddTileTexture.ptr,assets.AddTileTexture.len),
        };
        return &Static.instance.?;
    }

    pub fn get() *@This() {
        return &Static.instance.?;
    }

    pub fn deinit(self: *const @This()) void {
        self.default_font.deinit();
        self.tile_font.deinit();
        self.solid_colored_texture.deinit();
        self.add_tile_texture.deinit();
        Static.instance = null;
    }
};
