//! # Underlying HiRedis v1.3.0 API Bindings

const std = @import("std");
const log = std.log;
const debug = std.debug;

const hiredis = @cImport({
    @cInclude("hiredis.h");
    @cInclude("async.h");
});

const Str = []const u8;
const StrZ = [:0]const u8;
const StrC = [*c]const u8;

const Error = error { FailedToConnect, FailedToExecCommand };

pub const ReplyType = enum(c_int) {
    Nil =  hiredis.REDIS_REPLY_NIL,
    Error = hiredis.REDIS_REPLY_ERROR,
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
        if (ctx != null and ctx.*.err == 0) return ctx
        else {
            log.info("{s}", .{errMsg(ctx)});
            return Error.FailedToConnect;
        }
    }

    pub fn freeCtx(ctx: Ctx) void { hiredis.redisFree(ctx); }

    pub fn errMsg(ctx: Ctx) Str { return ctx.*.errstr[0..]; }

    pub fn command(ctx: Ctx, argv: []StrC, len: []const usize) Error!Reply {
        const lc: c_int = @intCast(argv.len);
        const arg_c: [*c]StrC = @ptrCast(argv);
        const len_c: [*c]const usize = @ptrCast(len);

        const reply = hiredis.redisCommandArgv(ctx, lc, arg_c, len_c);

        return if (reply != null) @ptrCast(@alignCast(reply))
        else Error.FailedToExecCommand;
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
