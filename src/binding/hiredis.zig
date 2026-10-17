//! # Underlying HiRedis v1.3.0 API Bindings

const std = @import("std");

const hiredis = @import("hiredis");

const StrZ = [:0]const u8;
const StrC = [*c]const u8;

const Error = error { RedoxFailedToConnect, RedoxFailedToExecCommand };

pub const ReplyType = enum(c_int) {
    Nil =  hiredis.REDIS_REPLY_NIL,
    Error = hiredis.REDIS_REPLY_ERROR,
    Array = hiredis.REDIS_REPLY_ARRAY,
    Status = hiredis.REDIS_REPLY_STATUS,
    String =  hiredis.REDIS_REPLY_STRING,
    Integer = hiredis.REDIS_REPLY_INTEGER
};

//##############################################################################
//# SYNCHRONOUS WRAPPER -------------------------------------------------------#
//##############################################################################

pub const Sync = struct {
    pub const Ctx = [*c]hiredis.struct_redisContext;
    pub const Reply = [*c]hiredis.struct_redisReply;

    pub fn connect(host: StrZ, port: u16) Error!Ctx {
        const ctx = hiredis.redisConnect(host, @intCast(port));
        if (ctx != null and ctx.*.err == 0) return ctx;

        std.log.err("Redis - {s}", .{errMsg(ctx)});
        if (ctx != null) hiredis.redisFree(ctx);
        return Error.RedoxFailedToConnect;
    }

    pub fn freeCtx(ctx: Ctx) void { hiredis.redisFree(ctx); }

    pub fn errMsg(ctx: Ctx) []const u8 {
        return if (ctx == null or ctx.*.err == 0) "Found No Error in Redis"
        else std.mem.sliceTo(&ctx.*.errstr, 0);
    }

    pub fn command(ctx: Ctx, argv: []StrC, len: []const usize) Error!Reply {
        const lc: c_int = @intCast(argv.len);
        const arg_c: [*c]StrC = @ptrCast(argv);
        const len_c: [*c]const usize = @ptrCast(len);

        const reply = hiredis.redisCommandArgv(ctx, lc, arg_c, len_c);

        return if (reply != null) @ptrCast(@alignCast(reply))
        else Error.RedoxFailedToExecCommand;
    }

    /// # Buffers a Command for Pipelining (No I/O, No Reply)
    /// - Each append **must** be paired with exactly one `getReply()`, in order.
    pub fn append(ctx: Ctx, argv: []StrC, len: []const usize) Error!void {
        const lc: c_int = @intCast(argv.len);
        const arg_c: [*c]StrC = @ptrCast(argv);
        const len_c: [*c]const usize = @ptrCast(len);

        if (hiredis.redisAppendCommandArgv(ctx, lc, arg_c, len_c) != hiredis.REDIS_OK)
            return Error.RedoxFailedToExecCommand;
    }

    /// # Reads One Pipelined Reply (in FIFO order)
    pub fn getReply(ctx: Ctx) Error!Reply {
        var reply: ?*anyopaque = null;

        if (hiredis.redisGetReply(ctx, @ptrCast(&reply)) != hiredis.REDIS_OK)
            return Error.RedoxFailedToExecCommand;

        return if (reply != null) @ptrCast(@alignCast(reply))
        else Error.RedoxFailedToExecCommand;
    }

    pub fn freeReply(reply: Reply) void {
        hiredis.freeReplyObject(@as(?*anyopaque, reply));
    }
};

//##############################################################################
//# ASYNCHRONOUS WRAPPER ------------------------------------------------------#
//##############################################################################

// TODO: Implement when sync becomes a bottleneck.
// pub const Async = struct { };
