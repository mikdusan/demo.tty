const std = @import("std");
const TTY = @import("tty.zig").TTY;

pub fn Dumb_TTY(comptime writeFn_: var) type {
    const info = @typeInfo(@TypeOf(writeFn_));
    return struct {
        tty: TTY,
        writeContext: WriteContext,
        state_stack: StateStack,

        pub const writeFn = writeFn_;
        pub const WriteContext = info.Fn.args[0].arg_type.?;
        pub const ReturnType = info.Fn.return_type.?;

        pub fn init(allocator: *std.mem.Allocator, destroy_self: bool, writeContext: var) @This() {
            return @This(){
                .tty = TTY{
                    .virtual = TTY.Virtual{
                        .startup = @This().startup,
                        .shutdown = @This().shutdown,
                        .deinit = @This().deinit,
                        .write = @This().write,
                        .writeDirect = @This().writeDirect,
                        .push = @This().push,
                        .pop = @This().pop,
                        .setPersistent = @This().setPersistent,
                        .setTransient = @This().setTransient,
                        .endTransient = @This().endTransient,
                    },
                    .private = TTY.Private{
                        .destroy_self = if (destroy_self) allocator else null,
                        .indent = 0,
                        .pending_indent = true,
                        .tab = "    ",
                    },
                },
                .writeContext = writeContext,
                .state_stack = StateStack.init(allocator),
            };
        }

        fn startup(tty: *TTY) (error {WriteFailure})!void {}
        fn shutdown(tty: *TTY) (error {WriteFailure})!void {}

        fn deinit(tty: *TTY) void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            self.state_stack.deinit();
            self.* = undefined;
        }

        fn write(tty: *TTY, bytes: []const u8) (error {WriteFailure})!void {
            try tty.nocolorWrite(bytes);
        }

        fn writeDirect(tty: *TTY, bytes: []const u8) (error {WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            @This().writeFn(self.writeContext, bytes) catch return error.WriteFailure;
        }

        fn push(tty: *TTY, base_state: TTY.State) (error {OutOfMemory,WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            try self.state_stack.append(base_state);
        }

        fn pop(tty: *TTY) ?TTY.State {
            const self = @fieldParentPtr(@This(), "tty", tty);
            return self.state_stack.popOrNull();
        }

        fn setPersistent(tty: *TTY, attr: TTY.PersistentAttribute) void {}
        fn setTransient(tty: *TTY, attr: TTY.TransientAttribute) void {}
        fn endTransient(tty: *TTY) void {}

        const StateStack = std.ArrayList(TTY.State);
    };
}
