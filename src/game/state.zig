const std = @import("std");

pub const PersistentState = struct {
    const Static = struct {
        var state: ?PersistentState = null;
    };

    energy: std.math.big.int.Managed,

    pub fn init(allocator: std.mem.Allocator) *@This() {
        if (Static.state == null) {
            Static.state = .{
                .energy = std.math.big.int.Managed.init(allocator) catch unreachable,
            };
        }
        return get();
    }

    pub fn deinit(self: *@This()) void {
        self.energy.deinit();
        Static.state = null;
    }

    pub fn get() *@This() {
        return &Static.state.?;
    }

    pub fn save() void {}

    pub fn load() void {}
};
