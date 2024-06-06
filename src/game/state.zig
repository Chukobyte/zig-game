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
    const BigInt = struct {
        value: std.math.big.int.Managed,

        fn init(allocator: std.mem.Allocator) @This() {
            return @This(){ .value = std.math.big.int.Managed.init(allocator) catch unreachable };
        }

        fn deinit(self: *@This()) void {
            self.value.deinit();
        }

        fn setString(self: *@This(), value: []const u8) !void {
            try self.value.setString(10, value);
        }
    };

    allocator: std.mem.Allocator,
    energy: std.math.big.int.Managed,
    food: BigInt,
    materials: BigInt,
    money: BigInt,
    data_db: ObjectDataDB,

    pub fn init(allocator: std.mem.Allocator) *@This() {
        if (Static.state == null) {
            Static.state = .{
                .allocator = allocator,
                .energy = std.math.big.int.Managed.init(allocator) catch unreachable,
                .food = BigInt.init(allocator),
                .materials = BigInt.init(allocator),
                .money = BigInt.init(allocator),
                .data_db = ObjectDataDB.init(allocator),
            };
            Static.state.?.food.setString("10") catch unreachable;
        }
        return get();
    }

    pub fn deinit(self: *@This()) void {
        self.energy.deinit();
        self.food.deinit();
        self.materials.deinit();
        self.money.deinit();
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

        const food_string = try self.food.value.toString(self.allocator, 10, .upper);
        const materials_string = try self.materials.value.toString(self.allocator, 10, .upper);
        const money_string = try self.money.value.toString(self.allocator, 10, .upper);
        defer self.allocator.free(food_string);
        defer self.allocator.free(materials_string);
        defer self.allocator.free(money_string);

        try self.data_db.writeProperty(state_obj, "food", []const u8, food_string);
        try self.data_db.writeProperty(state_obj, "materials", []const u8, materials_string);
        try self.data_db.writeProperty(state_obj, "money", []const u8, money_string);

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
            if (self.data_db.findProperty(state_obj, "food")) |food_prop| {
                try self.food.setString(food_prop.value.string);
            }
            if (self.data_db.findProperty(state_obj, "materials")) |materials_prop| {
                try self.materials.setString(materials_prop.value.string);
            }
            if (self.data_db.findProperty(state_obj, "money")) |money_prop| {
                try self.money.setString(money_prop.value.string);
            }
        }
    }

    pub fn refreshTextLabel(self: *@This(), text_label_comp: *TextLabelComponent) !void {
        try text_label_comp.text_label.setText(
            "Food: {any}                                Materials: {any}                                Money: {any}",
            .{ self.food.value, self.materials.value, self.money.value }
        );
    }
};
