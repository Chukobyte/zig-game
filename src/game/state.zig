const std = @import("std");

const zeika = @import("zeika");

const engine = @import("engine");

const data_db = engine.data_db;
const ObjectDataDB = data_db.ObjectDataDB;

pub const PersistentState = struct {
    const Static = struct {
        var state: ?PersistentState = null;
    };

    allocator: std.mem.Allocator,
    energy: std.math.big.int.Managed,
    data_db: ObjectDataDB,

    pub fn init(allocator: std.mem.Allocator) *@This() {
        if (Static.state == null) {
            Static.state = .{
                .allocator = allocator,
                .energy = std.math.big.int.Managed.init(allocator) catch unreachable,
                .data_db = ObjectDataDB.init(allocator),
            };
        }
        return get();
    }

    pub fn deinit(self: *@This()) void {
        self.energy.deinit();
        self.data_db.deinit();
        Static.state = null;
    }

    pub fn get() *@This() {
        return &Static.state.?;
    }

    pub fn save(self: *@This()) !void {
        const state_obj = try self.data_db.findOrAddObject(.{ .name = "state" });
        const energy_string = try self.energy.toString(self.allocator, 10, .upper);
        defer self.allocator.free(energy_string);
        try self.data_db.writeProperty(state_obj, "energy", []const u8, energy_string);
        const user_save_path = try zeika.get_user_save_path(.{ .org_name = "chukobyte", .app_name = "zig_test", .relative_path = "/game.sav" });
        try self.data_db.serialize(.{ .file_path = user_save_path, .mode = .binary });
    }

    pub fn load(self: *@This()) !void {
        const user_save_path = try zeika.get_user_save_path(.{ .org_name = "chukobyte", .app_name = "zig_test", .relative_path = "/game.sav" });
        const result = self.data_db.deserialize(.{ .file_path = user_save_path, .mode = .binary });
        if (result == error.FileNotFound) {
            return;
        }
        if (self.data_db.findObject("state")) |state_obj| {
            if (self.data_db.findProperty(state_obj, "energy")) |energy_prop| {
                try self.energy.setString(10, energy_prop.value.string);
            }
        }
    }
};
