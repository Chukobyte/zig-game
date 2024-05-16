///! Zig file used to embed assets at compile time

pub const DefaultFont = EmbeddedAsset.create("assets/font/verdana.ttf");

const EmbeddedAsset = struct {
    data: *anyopaque,
    len: usize,

    fn create(comptime file_path: []const u8) EmbeddedAsset {
        const embedded_file = @embedFile(file_path);
        return EmbeddedAsset{
            .data = @ptrCast(@constCast(embedded_file.ptr)),
            .len = embedded_file.len,
        };
    }
};

