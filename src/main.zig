const game = @import("game/game.zig");

pub fn main() !void {
    try game.init(.{});
    defer game.deinit();
    try game.run();
}
