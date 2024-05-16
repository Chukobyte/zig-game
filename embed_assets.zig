///! Zig file used to embed assets at compile time

const default_font_file = @embedFile("assets/font/verdana.ttf");

const EmbeddedAssets = struct {
    data: *anyopaque,
    len: usize,
};

pub const DefaultFont = EmbeddedAssets{
    .data = @ptrCast(@constCast(default_font_file.ptr)),
    .len = default_font_file.len,
};
