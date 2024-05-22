const std = @import("std");

const zeika = @import("zeika");
const math = zeika.math;

const engine = @import("engine");

const core = engine.core;
const ec = engine.ec;

const Renderer = zeika.Renderer;
const Texture = zeika.Texture;
const Font = zeika.Font;
const Vec2 = zeika.math.Vec2;
const Vec2i = zeika.math.Vec2i;
const Rect2 = zeika.math.Rect2;
const Color = zeika.math.Color;

const Sprite = core.Sprite;
const TextLabel = core.TextLabel;
const Collision = core.Collision;

const ECContext = @import("game.zig").ECContext;

pub const TransformComponent = struct {
    transform: math.Transform2D = math.Transform2D.Identity,
};

pub const SpriteComponent = struct {
    sprite: Sprite,

    pub fn render(comp: *anyopaque, entity: *ECContext.Entity) void {
        const sprite_comp: *@This() = @alignCast(@ptrCast(comp));
        if (entity.getComponent(TransformComponent)) |transform_comp| {
            const draw_config = sprite_comp.sprite.getDrawConfig(&transform_comp.transform, 0);
            Renderer.queueDrawSprite(&draw_config);
        }
    }
};

pub const TextLabelComponent = struct {

    pub fn DynamicString(stack_buffer_size: comptime_int) type {
        return struct {

            const Mode = enum {
                stack,
                heap,
            };

            allocator: std.mem.Allocator,
            mode: Mode,
            stack_buffer: [stack_buffer_size]u8,
            heap_buffer: ?[]u8 = null,
            buffer: *[]u8,

            pub fn init(allocator: std.mem.Allocator) @This() {
                var new_string = @This(){
                    .allocator = allocator,
                };
                new_string.set("", .{});
                return new_string;
            }

            pub fn deinit(self: *@This()) void {
                self.allocator.free(self.heap_buffer);
            }

            pub fn set(self: *@This(), fmt: []const u8, args: anytype) !void {
                self.updateBufferAndMode(fmt, args);
                _ = try std.fmt.bufPrint(&self.buffer, fmt, args);
            }

            pub inline fn get(self: *@This()) []const u8 {
                return self.buffer;
            }

            fn updateBufferAndMode(self: *@This(), fmt: []const u8, args: anytype) void {
                const string_length = std.fmt.count(fmt, args) + 1;
                if (string_length > stack_buffer_size) {
                    self.mode = .heap;
                    if (self.heap_buffer == null) {
                        self.heap_buffer = self.allocator.alloc(u8, string_length);
                    } else if (self.heap_buffer.?.len < string_length){
                        if (!self.allocator.resize(self.heap_buffer, string_length)) {
                            self.allocator.free(self.heap_buffer);
                            self.heap_buffer = self.allocator.alloc(u8, string_length);
                        }
                    }
                    self.buffer = self.heap_buffer;
                } else {
                    self.mode = .stack;
                    self.buffer = &self.stack_buffer;
                }
            }
        };
    }

    text_label: TextLabel,

    pub fn init(comp: *anyopaque, entity: *ECContext.Entity) void {
        const StaticData = struct {
            var text_buffer: [256]u8 = undefined;
            };
        _ = entity;
        const text_label_comp: *@This() = @alignCast(@ptrCast(comp));
        text_label_comp.text_label.text = std.fmt.bufPrint(&StaticData.text_buffer, "Money: 0", .{}) catch { unreachable; };
    }

    pub fn render(comp: *anyopaque, entity: *ECContext.Entity) void {
        const text_label_comp: *@This() = @alignCast(@ptrCast(comp));
        if (entity.getComponent(TransformComponent)) |transform_comp|  {
            const draw_config = text_label_comp.text_label.getDrawConfig(transform_comp.transform.position, 0);
            Renderer.queueDrawText(&draw_config);
        }
    }
};

pub const ColliderComponent = struct {
    collider: Rect2,
};
