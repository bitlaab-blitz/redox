//! # High-Level HiRedis Wrapper
//! **Remarks:** HiRedis is single-threaded, but Redox ensures thread safety.

const std = @import("std");
const fmt = std.fmt;
const Mutex = std.Thread.Mutex;

const hiredis = @import("../binding/hiredis.zig");
const ReplyType = hiredis.ReplyType;


const Str = []const u8;
const StrC = [*c]const u8;

const Error = error { NotFound, UnknownType, InvalidCommand, OperationFailed };

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
