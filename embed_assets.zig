///! Zig file used to embed assets at compile time

// Fonts
pub const DefaultFont = EmbeddedAsset.create("assets/font/verdana.ttf");

// Images
pub const AddTileTexture = EmbeddedAsset.create("assets/images/add_tile.png");

const EmbeddedAsset = struct {
    ptr: *const anyopaque,
    len: usize,

    fn create(comptime file_path: []const u8) EmbeddedAsset {
        const embedded_file = @embedFile(file_path);
        return EmbeddedAsset{
            .ptr = @ptrCast(embedded_file.ptr),
            .len = embedded_file.len,
        };
    }
};
