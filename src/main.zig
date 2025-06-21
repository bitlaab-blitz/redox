const std = @import("std");

const Redox = @import("redox").Redox;


pub fn main() !void {

    const redox = try Redox.Sync.init("127.0.0.1", 6379);
    defer redox.deinit();

    std.debug.print("Redis error: {s}|\n", .{redox.errMsg()});

    try redox.set("foo", "hello", .Default);

    const v = try redox.get("foo");
    defer v.free();

    std.debug.print("{s}\n", .{v.value()});

    try redox.remove("foho");
}

