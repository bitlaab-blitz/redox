const std = @import("std");
const redox = @import("redox");

const hiredis = @cImport({ @cInclude("hiredis.h"); });

pub fn main() !void {
    const ctx = hiredis.redisConnect("127.0.0.1", 6379);
    std.debug.print("{any}\n", .{ctx});
    if (ctx == null) {
        std.debug.print("oops\n", .{});
    }

    if (ctx.*.err != 0) {
        std.debug.print("oops {s}\n", .{ctx.*.errstr});
    }

    hiredis.redisFree(ctx);
}

