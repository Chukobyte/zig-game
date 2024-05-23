const std = @import("std");

pub fn DynamicString(stack_buffer_size: comptime_int, comptime auto_free_heap: bool) type {
    return struct {

        const Mode = enum {
            initial,
            stack,
            heap,
        };

        allocator: std.mem.Allocator,
        mode: Mode = .initial,
        stack_buffer: [stack_buffer_size]u8,
        heap_buffer: ?[]u8 = null,
        buffer: []u8,

        pub fn init(allocator: std.mem.Allocator) @This() {
            var new_string = @This(){ .allocator = allocator, .mode = undefined, .stack_buffer = undefined, .buffer = undefined, };
            new_string.set("", .{}) catch { unreachable; };
            return new_string;
        }

        pub inline fn initAndSet(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !@This() {
            var new_string = @This(){ .allocator = allocator, .mode = undefined, .stack_buffer = undefined, .buffer = undefined, };
            try new_string.set(fmt, args);
            return new_string;
        }

        pub fn deinit(self: *const @This()) void {
            if (self.heap_buffer) |buffer| {
                self.allocator.free(buffer);
            }
        }

        pub fn set(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
            const string_length = std.fmt.count(fmt, args) + 1;
            if (string_length > stack_buffer_size) {
                self.mode = .heap;
                if (self.heap_buffer == null) {
                    self.heap_buffer = try self.allocator.alloc(u8, string_length);
                } else if (self.heap_buffer.?.len < string_length){
                    if (!self.allocator.resize(self.heap_buffer.?, string_length)) {
                        self.allocator.free(self.heap_buffer.?);
                        self.heap_buffer = try self.allocator.alloc(u8, string_length);
                    }
                }
                self.buffer = try std.fmt.bufPrint(self.heap_buffer.?, fmt, args);
            } else {
                self.mode = .stack;
                self.buffer = try std.fmt.bufPrint(&self.stack_buffer, fmt, args);
                if (auto_free_heap) {
                    self.freeHeap();
                }
            }
        }

        /// Will free heap if no longer being used
        pub fn freeHeap(self: *@This()) void {
            if (self.mode == .stack) {
                return;
            }
            if (self.heap_buffer) |buffer| {
                self.allocator.free(buffer);
                self.heap_buffer = null;
            }
        }

        pub inline fn get(self: *const @This()) []const u8 {
            return self.buffer;
        }

        pub inline fn getLen(self: *@This()) usize {
            return self.buffer.len;
        }
    };
}

pub const String8 = DynamicString(8, false);
pub const String16 = DynamicString(16, false);
pub const String32 = DynamicString(32, false);
pub const String64 = DynamicString(64, false);
pub const String128 = DynamicString(128, false);
pub const String256 = DynamicString(256, false);

pub const String = String32;
