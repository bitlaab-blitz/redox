//! # High-Level HiRedis Wrapper
//! **Remarks:** HiRedis is single-threaded, but Redox ensures thread safety.

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Mutex = std.Thread.Mutex;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const hiredis = @import("../binding/hiredis.zig");
const ReplyType = hiredis.ReplyType;


const Str = []const u8;
const StrC = [*c]const u8;

const Error = error { NotFound, UnknownType, InvalidCommand, OperationFailed };

const Keys = []const Str;

//##############################################################################
//# SYNCHRONOUS WRAPPER -------------------------------------------------------#
//##############################################################################

pub const Sync = struct {
    const Ctx = hiredis.Sync.Ctx;
    const Reply = hiredis.Sync.Reply;

    const Flag = enum { Default, IfNotExists, IfExists };

    ctx: Ctx,
    mutex: Mutex,

    const Self = @This();

    /// # Initializes HiRedis Instance
    pub fn init(host: Str, port: u16) !Self {
        var buff: [256]u8 = undefined;
        const host_z = try fmt.bufPrintZ(&buff, "{s}", .{host});

        const ctx = try hiredis.Sync.connect(host_z, port);
        return .{.ctx = ctx, .mutex = Mutex{}};
    }

    /// # Destroys HiRedis Instance
    pub fn deinit(self: *const Self) void { hiredis.Sync.freeCtx(self.ctx); }

    /// # Shows Human-Readable Error Message
    /// - Most recent error that occurred on a HiRedis instance
    pub fn errMsg(self: *Self) Str {
        self.mutex.lock();
        defer self.mutex.unlock();

        return hiredis.Sync.errMsg(self.ctx);
    }

    /// # Inserts a New Record
    /// - `k` - The record key (e.g., `user:1234`)
    /// - `v` - The record value (e.g., `John Doe`)
    pub fn set(self: *Self, k: Str, v: Str, f: Flag) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const reply = blk: {
            switch (f) {
                .Default => {
                    var argv = [3]StrC {"SET", k.ptr, v.ptr};
                    var len = [3]usize {3, k.len, v.len};
                    break :blk try self.command(&argv, &len);
                },
                .IfNotExists => {
                    var argv = [4]StrC {"SET", k.ptr, v.ptr, "NX"};
                    var len = [4]usize {3, k.len, v.len, 2};
                    break :blk try self.command(&argv, &len);
                },
                .IfExists => {
                    var argv = [4]StrC {"SET", k.ptr, v.ptr, "XX"};
                    var len = [4]usize {3, k.len, v.len, 2};
                    break :blk try self.command(&argv, &len);
                }
            }
        };

        switch (reply.*.type) {
            @intFromEnum(ReplyType.Status) => hiredis.Sync.freeReply(reply),
            @intFromEnum(ReplyType.Error) => return Error.InvalidCommand,
            @intFromEnum(ReplyType.Nil) => return Error.OperationFailed,
            else => return Error.UnknownType
        }
    }

    /// # Inserts a New Record with Expiry
    /// - `k` - The record key (e.g., `user:1234`)
    /// - `v` - The record value (e.g., `John Doe`)
    /// - `ttl` - Time-to-live in seconds (e.g., `120`)
    pub fn setWith(self: *Self, k: Str, v: Str, f: Flag, ttl: u32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var buff: [10]u8 = undefined;
        const ttl_str = try fmt.bufPrint(&buff, "{d}", .{ttl});

        const reply = blk: {
            switch (f) {
                .Default => {
                    var argv = [5]StrC {"SET", k.ptr, v.ptr, "EX", ttl_str.ptr};
                    var len = [5]usize {3, k.len, v.len, 2, ttl_str.len};
                    break :blk try self.command(&argv, &len);
                },
                .IfNotExists => {
                    var argv = [6]StrC {
                        "SET", k.ptr, v.ptr, "NX", "EX", ttl_str.ptr
                    };
                    var len = [6]usize {3, k.len, v.len, 2, 2, ttl_str.len};
                    break :blk try self.command(&argv, &len);
                },
                .IfExists => {
                    var argv = [6]StrC {
                        "SET", k.ptr, v.ptr, "XX", "EX", ttl_str.ptr
                    };
                    var len = [6]usize {3, k.len, v.len, 2, 2, ttl_str.len};
                    break :blk try self.command(&argv, &len);
                }
            }
        };

        switch (reply.*.type) {
            @intFromEnum(ReplyType.Status) => hiredis.Sync.freeReply(reply),
            @intFromEnum(ReplyType.Error) => return Error.InvalidCommand,
            @intFromEnum(ReplyType.Nil) => return Error.OperationFailed,
            else => return Error.UnknownType
        }
    }

    /// # Extracts a Record by the Given Key
    /// **Remarks:** Make sure to call `Data.free()` after use.
    ///
    /// - `k` - The record key (e.g., `user:1234`)
    pub fn get(self: *Self, k: Str) !Data {
        self.mutex.lock();
        defer self.mutex.unlock();

        var argv = [2]StrC {"GET", k.ptr};
        var len = [2]usize {3, k.len};
        const reply = try self.command(&argv, &len);

        switch (reply.*.type) {
            @intFromEnum(ReplyType.String) => {
                return .{.reply = reply, .string = reply.*.str[0..reply.*.len]};
            },
            @intFromEnum(ReplyType.Error) => return Error.InvalidCommand,
            @intFromEnum(ReplyType.Nil) => return Error.NotFound,
            else => return Error.UnknownType
        }
    }

    /// # Deletes a Record by the Given Key
    /// - `k` - The record key (e.g., `user:1234`)
    pub fn remove(self: *Self, k: Str) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var argv = [2]StrC {"DEL", k.ptr};
        var len = [2]usize {3, k.len};
        const reply = try self.command(&argv, &len);

        switch (reply.*.type) {
            @intFromEnum(ReplyType.Integer) => {
                defer hiredis.Sync.freeReply(reply);
                if (reply.*.integer == 0) return Error.NotFound;
            },
            @intFromEnum(ReplyType.Error) => return Error.InvalidCommand,
            else => return Error.UnknownType
        }
    }

    /// # Scans for Partially Matching keys
    /// **WARNING:** Return value should be freed with `Redox.Sync.free()`.
    ///
    /// - `pk` - The partial record key (e.g., `user:*`)
    /// - `count` - Limits the maximum number of scanned keys
    pub fn scan(self: *Self, heap: Allocator, pk: Str, count: u32) !Keys {
        self.mutex.lock();
        defer self.mutex.unlock();

        var key_list = ArrayList(Str).init(heap);
        var cursor: StrC = "0";

        while (true) {
            const sc = mem.span(cursor);
            var argv = [8]StrC {
                "SCAN", sc.ptr, "MATCH", pk.ptr, "TYPE", "string", "COUNT", "32"
            };
            var len = [8]usize {4, sc.len, 5, pk.len, 4, 6, 5, 2};

            const reply = try self.command(&argv, &len);
            defer hiredis.Sync.freeReply(reply);

            switch (reply.*.type) {
                @intFromEnum(ReplyType.Array) => {
                    cursor = reply.*.element[0].*.str;
                    const keys = reply.*.element[1];

                    for (0..keys.*.elements) |i| {
                        if (key_list.items.len == count) break;

                        const key = keys.*.element[i];
                        const val = try heap.alloc(u8, key.*.len);
                        mem.copyForwards(u8, val, mem.span(key.*.str));
                        try key_list.append(val);
                    }

                    if (mem.eql(u8, sc, "0")) break;
                },
                else => return Error.UnknownType
            }
        }

        return try key_list.toOwnedSlice();
    }

    /// # Frees `Keys` returned by the `scan()`
    pub fn free(heap: Allocator, keys: Keys) void {
        for (keys) |key| heap.free(key);
        heap.free(keys);
    }

    /// # Executes a Given Command
    fn command(self: *const Self, argv: []StrC, len: []const usize) !Reply {
        return try hiredis.Sync.command(self.ctx, argv, len);
    }

    const Data = struct {
        reply: Reply,
        string: Str,

        pub fn free(self: *const Data) void {
            hiredis.Sync.freeReply(self.reply);
        }

        pub fn value(self: *const Data) Str { return self.string; }
    };
};

//##############################################################################
//# ASYNCHRONOUS WRAPPER ------------------------------------------------------#
//##############################################################################

// TODO: Implement when sync becomes a bottleneck.
// pub const Async = struct { };
