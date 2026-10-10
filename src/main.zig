const std = @import("std");

const Redox = @import("redox").Redox;

pub fn main(init: std.process.Init) !void {
    const heap = init.gpa;

    // Let's start from here...

    var redox = try Redox.Sync.init(init.io, "127.0.0.1", 6379);
    defer redox.deinit();

    std.debug.print("Redis error: {s}\n", .{try redox.errMsg()});

    // Insert records (replaces the value if the key already exists)
    try redox.set("foo:1", "bar", .Default);
    try redox.set("bar:1", "bar", .Default);
    try redox.set("bar:2", "bar", .Default);

    // Insert multiple records in a single round-trip (pipelined)
    const pairs = [_][2][]const u8 {
        .{ "foo:2", "bar" },
        .{ "foo:3", "bar" },
        .{ "foo:fi", "bar" }
    };
    try redox.setMany(&pairs, .Default);

    // Insert a record with expiry (time-to-live in seconds)
    try redox.setWith("session:1", "token", .Default, 120);

    // Insert only if the key does not exist (fails if it already does)
    redox.set("foo:1", "new-bar", .IfNotExists) catch |err| {
        std.debug.print("IfNotExists failed: {s}\n", .{@errorName(err)});
    };

    // Insert only if the key already exists (fails if it does not)
    redox.set("missing:key", "bar", .IfExists) catch |err| {
        std.debug.print("IfExists failed: {s}\n", .{@errorName(err)});
    };

    // Extract a record by key
    const rec = try redox.get("foo:1");
    defer rec.free();
    std.debug.print("foo:1 = {s}\n", .{rec.value()});

    // Scan for partially matching keys
    const keys = try redox.scan(heap, "foo:*", 21);
    defer Redox.Sync.free(heap, keys);

    for (keys) |key| { std.debug.print("key: {s}\n", .{key}); }

    // Delete a record by key
    try redox.remove("bar:1");
}
