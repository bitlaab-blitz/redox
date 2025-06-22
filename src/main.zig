const std = @import("std");

const Redox = @import("redox").Redox;

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});

    // Let's start from here...

    var redox = try Redox.Sync.init("127.0.0.1", 6379);
    defer redox.deinit();

    std.debug.print("Redis error: {s}|\n", .{redox.errMsg()});

    try redox.setWith("foo", "bar", .Default, 30);

    const rec = try redox.get("foo");
    defer rec.free();
    std.debug.print("Value: {s}|\n", .{rec.value()});

    try redox.remove("foo");
}
