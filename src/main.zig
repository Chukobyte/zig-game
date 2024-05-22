const game = @import("game/game.zig");

pub fn main() !void {
    try game.initAndRun(.{});
    defer game.deinit();
}
