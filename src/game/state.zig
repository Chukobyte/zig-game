const std = @import("std");

const zeika = @import("zeika");

const engine = @import("engine");

const comps = @import("components.zig");

const data_db = engine.data_db;
const ObjectDataDB = data_db.ObjectDataDB;

const TextLabelComponent = comps.TextLabelComponent;

pub const PersistentState = struct {
    const Static = struct {
        var state: ?PersistentState = null;
    };

    /// A wrapper around std.math.big.int.Managed to be used specifically for this game
    pub const BigInt = struct {
        value: std.math.big.int.Managed,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return @This(){ .value = std.math.big.int.Managed.init(allocator) catch unreachable };
        }

        pub fn deinit(self: *@This()) void {
            self.value.deinit();
        }

        pub inline fn setString(self: *@This(), value: []const u8) !void {
            try self.value.setString(10, value);
        }

        pub inline fn toString(self: *@This(), allocator: std.mem.Allocator) ![]u8 {
            return try self.value.toString(allocator, 10, .upper);
        }

        pub inline fn add(self: *@This(), a: *const @This(), b: *const @This()) !void {
            try self.value.add(&a.value, &b.value);
        }

        pub inline fn addScalar(self: *@This(), a: *const @This(), scalar: anytype) !void {
            try self.value.addScalar(&a.value, scalar);
        }
    };

    allocator: std.mem.Allocator,
    data_db: ObjectDataDB,
    // Village Stats
    food: BigInt,
    wood: BigInt,
    stone: BigInt,
    gold: BigInt,
    // Villagers
    farmers: BigInt,
    loggers: BigInt,
    masons: BigInt,


    pub fn init(allocator: std.mem.Allocator) *@This() {
        if (Static.state == null) {
            Static.state = .{
                .allocator = allocator,
                .data_db = ObjectDataDB.init(allocator),
                .food = BigInt.init(allocator),
                .wood = BigInt.init(allocator),
                .stone = BigInt.init(allocator),
                .gold = BigInt.init(allocator),
                .farmers = BigInt.init(allocator),
                .loggers = BigInt.init(allocator),
                .masons = BigInt.init(allocator),
            };
            Static.state.?.food.setString("10") catch unreachable;
        }
        return get();
    }

    pub fn deinit(self: *@This()) void {
        self.food.deinit();
        self.wood.deinit();
        self.stone.deinit();
        self.gold.deinit();
        self.farmers.deinit();
        self.loggers.deinit();
        self.masons.deinit();
        self.data_db.deinit();
        Static.state = null;
    }

    pub fn get() *@This() {
        return &Static.state.?;
    }

    const BigIntProperty = struct {
        value: *BigInt,
        key: []const u8,
    };

    inline fn getBigIntProperties(self: *@This()) []const BigIntProperty {
        return &[_]BigIntProperty{
            .{ .value = &self.food, .key = "food" },
            .{ .value = &self.wood, .key = "wood" },
            .{ .value = &self.stone, .key = "stone" },
            .{ .value = &self.gold, .key = "gold" },
        };
    }

    pub fn save(self: *@This()) !void {
        const state_obj = try self.data_db.findOrAddObject(.{ .name = "state" });
        for (self.getBigIntProperties()) |*prop| {
            const prop_string = try prop.value.toString(self.allocator);
            defer self.allocator.free(prop_string);
            try self.data_db.writeProperty(state_obj, prop.key, []const u8, prop_string);
        }
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
            for (self.getBigIntProperties()) |*prop| {
                if (self.data_db.findProperty(state_obj, prop.key)) |data_prop| {
                    try prop.value.setString(data_prop.value.string);
                }
            }
        }
    }

    pub fn refreshTextLabel(self: *@This(), text_label_comp: *TextLabelComponent) !void {
        try text_label_comp.text_label.setText(
            "Food: {any}                                Wood: {any}                                Stone: {any}",
            .{ self.food.value, self.wood.value, self.stone.value }
        );
    }
};
