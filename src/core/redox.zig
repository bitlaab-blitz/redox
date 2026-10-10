//! # High-Level HiRedis Wrapper
//! **Remarks:** HiRedis is single-threaded, but Redox ensures thread safety.

const std = @import("std");
const Io = std.Io;
const fmt = std.fmt;
const mem = std.mem;
const Mutex = std.Io.Mutex;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const hiredis = @import("../binding/hiredis.zig");
const ReplyType = hiredis.ReplyType;


const Str = []const u8;
const StrC = [*c]const u8;

const Error = error {
    RedoxKeyNotFound,
    RedoxUnknownType,
    RedoxInvalidCommand,
    RedoxOperationFailed
};

const Keys = []const Str;

//##############################################################################
//# SYNCHRONOUS WRAPPER -------------------------------------------------------#
//##############################################################################

pub const Sync = struct {
    const Ctx = hiredis.Sync.Ctx;
    const Reply = hiredis.Sync.Reply;

    const Flag = enum { Default, IfNotExists, IfExists };

    io: Io,
    ctx: Ctx,
    mutex: Mutex,
    host_buf: [256]u8,
    host_len: usize,
    port: u16,

    const Self = @This();

    /// # Initializes HiRedis Instance
    pub fn init(io: Io, host: Str, port: u16) !Self {
        var buff: [256]u8 = undefined;
        const host_z = try fmt.bufPrintSentinel(&buff, "{s}", .{host}, 0);

        const ctx = try hiredis.Sync.connect(host_z, port);
        var self = Self {
            .io = io,
            .ctx = ctx,
            .mutex = .init,
            .host_buf = undefined,
            .host_len = host.len,
            .port = port,
        };

        mem.copyForwards(u8, &self.host_buf, host);
        return self;
    }

    /// # Destroys HiRedis Instance
    pub fn deinit(self: *const Self) void { hiredis.Sync.freeCtx(self.ctx); }

    /// # Shows Human-Readable Error Message
    /// - Most recent error that occurred on a HiRedis instance
    pub fn errMsg(self: *Self) !Str {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        return hiredis.Sync.errMsg(self.ctx);
    }

    /// # Inserts a New Record
    /// - `k` - The record key (e.g., `user:1234`)
    /// - `v` - The record value (e.g., `John Doe`)
    pub fn set(self: *Self, k: Str, v: Str, f: Flag) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

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

        defer hiredis.Sync.freeReply(reply);

        switch (reply.*.type) {
            @intFromEnum(ReplyType.Status) => {},
            @intFromEnum(ReplyType.Error) => return Error.RedoxInvalidCommand,
            @intFromEnum(ReplyType.Nil) => return Error.RedoxOperationFailed,
            else => return Error.RedoxUnknownType
        }
    }

    /// # Inserts a New Record with Expiry
    /// - `k` - The record key (e.g., `user:1234`)
    /// - `v` - The record value (e.g., `John Doe`)
    /// - `ttl` - Time-to-live in seconds (e.g., `120`)
    pub fn setWith(self: *Self, k: Str, v: Str, f: Flag, ttl: u32) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

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

        defer hiredis.Sync.freeReply(reply);

        switch (reply.*.type) {
            @intFromEnum(ReplyType.Status) => {},
            @intFromEnum(ReplyType.Error) => return Error.RedoxInvalidCommand,
            @intFromEnum(ReplyType.Nil) => return Error.RedoxOperationFailed,
            else => return Error.RedoxUnknownType
        }
    }

    /// # Extracts a Record by the Given Key
    /// **Remarks:** Make sure to call `Data.free()` after use.
    ///
    /// - `k` - The record key (e.g., `user:1234`)
    pub fn get(self: *Self, k: Str) !Data {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        var argv = [2]StrC {"GET", k.ptr};
        var len = [2]usize {3, k.len};
        const reply = try self.command(&argv, &len);

        switch (reply.*.type) {
            @intFromEnum(ReplyType.String) => {
                return .{.reply = reply, .string = reply.*.str[0..reply.*.len]};
            },
            @intFromEnum(ReplyType.Error) => {
                defer hiredis.Sync.freeReply(reply);
                return Error.RedoxInvalidCommand;
            },
            @intFromEnum(ReplyType.Nil) => {
                defer hiredis.Sync.freeReply(reply);
                return Error.RedoxKeyNotFound;
            },
            else => {
                defer hiredis.Sync.freeReply(reply);
                return Error.RedoxUnknownType;
            }
        }
    }

    /// # Deletes a Record by the Given Key
    /// - `k` - The record key (e.g., `user:1234`)
    pub fn remove(self: *Self, k: Str) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        var argv = [2]StrC {"DEL", k.ptr};
        var len = [2]usize {3, k.len};
        const reply = try self.command(&argv, &len);
        defer hiredis.Sync.freeReply(reply);

        switch (reply.*.type) {
            @intFromEnum(ReplyType.Integer) => {
                if (reply.*.integer == 0) return Error.RedoxKeyNotFound;
            },
            @intFromEnum(ReplyType.Error) => return Error.RedoxInvalidCommand,
            else => return Error.RedoxUnknownType
        }
    }

    /// # Scans for Partially Matching keys
    /// **WARNING:** Return value should be freed with `Redox.Sync.free()`.
    ///
    /// - `pk` - The partial record key (e.g., `user:*`)
    /// - `count` - Limits the maximum number of scanned keys
    pub fn scan(self: *Self, heap: Allocator, pk: Str, count: u32) !Keys {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);

        var key_list: ArrayList(Str) = .empty;
        errdefer key_list.deinit(heap);

        var cursor_buf: [24]u8 = undefined;
        var cursor_len: usize = 1;
        @memcpy(cursor_buf[0..1], "0");

        while (true) {
            var argv = [8]StrC {
                "SCAN", cursor_buf[0..cursor_len].ptr, "MATCH", pk.ptr,
                "TYPE", "string", "COUNT", "32"
            };
            var len = [8]usize {4, cursor_len, 5, pk.len, 4, 6, 5, 2};

            const reply = try self.command(&argv, &len);
            defer hiredis.Sync.freeReply(reply);

            switch (reply.*.type) {
                @intFromEnum(ReplyType.Array) => {
                    // Copy the new cursor out before the reply is freed below.
                    const cur = reply.*.element[0];
                    const next = cur.*.str[0..cur.*.len];

                    if (next.len > cursor_buf.len) {
                        return Error.RedoxOperationFailed;
                    }

                    @memcpy(cursor_buf[0..next.len], next);
                    cursor_len = next.len;

                    const keys = reply.*.element[1];

                    for (0..keys.*.elements) |i| {
                        if (key_list.items.len == count) break;

                        const key = keys.*.element[i];
                        const val = try heap.alloc(u8, key.*.len);
                        mem.copyForwards(u8, val, key.*.str[0..key.*.len]);
                        key_list.append(heap, val) catch |err| {
                            heap.free(val);
                            return err;
                        };
                    }

                    if (key_list.items.len == count) break;
                    if (mem.eql(u8, cursor_buf[0..cursor_len], "0")) break;
                },
                else => return Error.RedoxUnknownType
            }
        }

        return try key_list.toOwnedSlice(heap);
    }

    /// # Frees `Keys` returned by the `scan()`
    pub fn free(heap: Allocator, keys: Keys) void {
        for (keys) |key| heap.free(key);
        heap.free(keys);
    }

    /// # Executes a Given Command
    /// **Remarks:** Reconnects and retries once if failed to execute. If the
    /// original command reached the server but the reply read failed,
    /// the retry executes it a second time (safe for idempotent commands only).
    fn command(self: *Self, argv: []StrC, len: []const usize) !Reply {
        return hiredis.Sync.command(self.ctx, argv, len) catch |err| {
            switch (err) {
                error.RedoxFailedToExecCommand => {
                    // Transparently reconnect and retry once
                    var buff: [256]u8 = undefined;
                    const host_str = self.host_buf[0..self.host_len];
                    const host_z = try fmt.bufPrintSentinel(
                        &buff, "{s}", .{host_str}, 0
                    );

                    const ctx = try hiredis.Sync.connect(host_z, self.port);
                    hiredis.Sync.freeCtx(self.ctx);
                    self.ctx = ctx;

                    return try hiredis.Sync.command(self.ctx, argv, len);
                },
                else => return err
            }
        };
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
