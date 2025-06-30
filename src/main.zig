const std = @import("std");

const Redox = @import("redox").Redox;

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});

    var gpa_mem = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // Let's start from here...

    var redox = try Redox.Sync.init("127.0.0.1", 6379);
    defer redox.deinit();

    std.debug.print("Redis error: {s}|\n", .{redox.errMsg()});

    try redox.set("foo:1", "bar", .Default);
    try redox.set("foo:2", "bar", .Default);
    try redox.set("foo:3", "bar", .Default);
    try redox.set("foo:fi", "bar", .Default);
    try redox.set("bar:1", "bar", .Default);
    try redox.set("bar:2", "bar", .Default);

    const keys = try redox.scan(heap, "foo:*", 21);
    defer Redox.Sync.free(heap, keys);

    for (keys) |key| { std.debug.print("key: {s}\n", .{key}); }
}
