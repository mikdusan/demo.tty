const std = @import("std");
const TTY = @import("tty.zig").TTY;

pub fn ANSI_TTY(comptime writeFn_: var) type {
    const info = @typeInfo(@TypeOf(writeFn_));
    return struct {
        tty: TTY,
        writeContext: WriteContext,
        persistent: State,
        active: State,
        pending: Pending,
        theme: Theme,
        state_stack: StateStack,

        pub const WriteContext = info.Fn.args[0].arg_type.?;
        pub const ReturnType = info.Fn.return_type.?;
        pub const writeFn = writeFn_;

        pub fn init(allocator: *std.mem.Allocator, destroy_self: bool, writeContext: var, colorPalette: ColorPalette) (error {WriteFailure})!@This() {
            var result = @This(){
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
                .persistent = undefined,
                .active = undefined,
                .pending = Pending{ .hue = null, .standout = null, .mode = null },
                .theme = undefined,
                .state_stack = StateStack.init(allocator),
            };

            switch (colorPalette) {
                .ansi4 => @panic("ANSI_TTY 4-bit color not implemented"),
                .ansi8 => {
                    result.theme = darkTheme;
                },
                .ansi24 => @panic("ANSI_TTY 24-bit color not implemented"),
            }

            const code_set = result.theme[0][0][1];
            result.persistent = State{
                .hue = .hue0,
                .standout = .medium,
                .mode = .foreground,
                .bg = code_set.bg,
                .fg = code_set.fg,
            };
            result.active = result.persistent;
            return result;
        }

        fn resetColor(self: *@This()) (error {WriteFailure})!void {
            @This().writeFn(self.writeContext, "\x1b[0m") catch return error.WriteFailure;
        }

        fn startup(tty: *TTY) (error {WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            const code_set = self.theme[@enumToInt(TTY.Hue.hue0)][@enumToInt(TTY.Mode.foreground)][@enumToInt(TTY.Standout.medium)];
            @This().writeFn(self.writeContext, code_set.codes[2]) catch return error.WriteFailure;
        }

        fn shutdown(tty: *TTY) (error {WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            try self.resetColor();
        }

        fn deinit(tty: *TTY) void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            self.state_stack.deinit();
            self.* = undefined;
        }

        fn push(tty: *TTY, base_state: TTY.State) (error {OutOfMemory,WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            try self.processPending();
            try self.state_stack.append(
                StateStackItem{
                    .base = base_state,
                    .ansi = self.active,
                },
            );
        }

        fn pop(tty: *TTY) ?TTY.State {
            const self = @fieldParentPtr(@This(), "tty", tty);
            if (self.state_stack.popOrNull()) |item| {
                self.pending.hue = item.ansi.hue;
                self.pending.standout = item.ansi.standout;
                self.pending.mode = item.ansi.mode;
                return item.base;
            } else {
                return null;
            }
        }

        fn write(tty: *TTY, bytes: []const u8) (error {WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            try self.processPending();
            try tty.nocolorWrite(bytes);
        }

        fn writeDirect(tty: *TTY, bytes: []const u8) (error {WriteFailure})!void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            @This().writeFn(self.writeContext, bytes) catch return error.WriteFailure;
        }

        fn setPersistent(tty: *TTY, attr: TTY.PersistentAttribute) void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            switch (attr) {
                .indent, .dedent, .nodent => {}, // handled in base
                .hue => |hue| {
                    if (self.persistent.hue != hue) {
                        self.persistent.hue = hue;
                        self.pending.hue = hue;
                    }
                },
                .standout => |standout| {
                    if (self.persistent.standout != standout) {
                        self.persistent.standout = standout;
                        self.pending.standout = standout;
                    }
                },
                .mode => |mode| {
                    if (self.persistent.mode != mode) {
                        self.persistent.mode = mode;
                        self.pending.mode = mode;
                    }
                },
            }
        }

        fn setTransient(tty: *TTY, attr: TTY.TransientAttribute) void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            switch (attr) {
                .hue => |hue| self.pending.hue = hue,
                .standout => |standout| self.pending.standout = standout,
                .mode => |mode| self.pending.mode = mode,
            }
        }

        fn endTransient(tty: *TTY) void {
            const self = @fieldParentPtr(@This(), "tty", tty);
            if (self.active.hue != self.persistent.hue) self.pending.hue = self.persistent.hue;
            if (self.active.standout != self.persistent.standout) self.pending.standout = self.persistent.standout;
            if (self.active.mode != self.persistent.mode) self.pending.mode = self.persistent.mode;
        }

        fn processPending(self: *@This()) (error {WriteFailure})!void {
            var adjust = false;
            if (self.pending.hue) |hue| {
                self.active.hue = hue;
                self.pending.hue = null;
                adjust = true;
            }
            if (self.pending.standout) |standout| {
                self.active.standout = standout;
                self.pending.standout = null;
                adjust = true;
            }
            if (self.pending.mode) |mode| {
                self.active.mode = mode;
                self.pending.mode = null;
                adjust = true;
            }
            if (adjust) {
                const code_set = self.theme[@enumToInt(self.active.hue)][@enumToInt(self.active.mode)][@enumToInt(self.active.standout)];
                if (self.active.bg != code_set.bg) {
                    if (self.active.fg == code_set.fg) {
                        @This().writeFn(self.writeContext, code_set.codes[0]) catch return error.WriteFailure;
                    } else {
                        @This().writeFn(self.writeContext, code_set.codes[2]) catch return error.WriteFailure;
                    }
                } else if (self.active.fg != code_set.fg) {
                    @This().writeFn(self.writeContext, code_set.codes[1]) catch return error.WriteFailure;
                }
                self.active.bg = code_set.bg;
                self.active.fg = code_set.fg;
            }
        }

        pub const ColorPalette = enum {
            ansi4,
            ansi8,
            ansi24,
        };

        const State = struct {
            hue: TTY.Hue,
            standout: TTY.Standout,
            mode: TTY.Mode,
            bg: u9,
            fg: u9,
        };

        const Pending = struct {
            hue: ?TTY.Hue,
            standout: ?TTY.Standout,
            mode: ?TTY.Mode,
        };

        const StateStackItem = struct {
            base: TTY.State,
            ansi: State,
        };
        const StateStack = std.ArrayList(StateStackItem);
    };
}

const ANSICodeSet = struct {
    // cardinal used to compare equality of background color
    bg: u9,
    // cardinal used to compare equality of foreground color
    fg: u9,
    // 0 = set bg
    // 1 = set fg
    // 2 = set both
    codes: [3][]const u8,
};

const Theme = [@typeInfo(TTY.Hue).Enum.fields.len][2][3]ANSICodeSet;

pub const darkTheme = Theme{
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 7,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;7m",
                    "\x1b[49;38;5;7m",
                },
            },
            ANSICodeSet{
                .bg = 236,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;236m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;236;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 8,
                .fg = 11,
                .codes = [_][]const u8{
                    "\x1b[48;5;8m",
                    "\x1b[38;5;11m",
                    "\x1b[48;5;8;38;5;11m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 8,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;8m",
                    "\x1b[49;38;5;8m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 7,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;7m",
                    "\x1b[49;38;5;7m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;15m",
                    "\x1b[49;38;5;15m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 90,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;90m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;90;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 127,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;127m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;127;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 164,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;164m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;164;38;5;15m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 90,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;90m",
                    "\x1b[49;38;5;90m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 127,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;127m",
                    "\x1b[49;38;5;127m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 201,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;201m",
                    "\x1b[49;38;5;201m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 19,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;19m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;19;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 20,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;20m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;20;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 21,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;21m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;21;38;5;15m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 21,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;21m",
                    "\x1b[49;38;5;21m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 27,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;27m",
                    "\x1b[49;38;5;27m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 33,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;33m",
                    "\x1b[49;38;5;33m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 30,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;30m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;30;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 37,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;37m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;37;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 44,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;44m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;44;38;5;0m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 37,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;37m",
                    "\x1b[49;38;5;37m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 44,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;44m",
                    "\x1b[49;38;5;44m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 51,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;51m",
                    "\x1b[49;38;5;51m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 28,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;28m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;28;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 34,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;34m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;34;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 40,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;40m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;40;38;5;0m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 34,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;34m",
                    "\x1b[49;38;5;34m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 40,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;40m",
                    "\x1b[49;38;5;40m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 46,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;46m",
                    "\x1b[49;38;5;46m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 88,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;88m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;88;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 124,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;124m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;124;38;5;15m",
                },
            },
            ANSICodeSet{
                .bg = 160,
                .fg = 15,
                .codes = [_][]const u8{
                    "\x1b[48;5;160m",
                    "\x1b[38;5;15m",
                    "\x1b[48;5;160;38;5;15m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 88,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;88m",
                    "\x1b[49;38;5;88m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 124,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;124m",
                    "\x1b[49;38;5;124m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 160,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;160m",
                    "\x1b[49;38;5;160m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 100,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;100m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;100;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 142,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;142m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;142;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 184,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;184m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;184;38;5;0m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 100,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;100m",
                    "\x1b[49;38;5;100m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 184,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;184m",
                    "\x1b[49;38;5;184m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 226,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;226m",
                    "\x1b[49;38;5;226m",
                },
            },
        },
    },
    [_][3]ANSICodeSet{
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 166,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;166m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;166;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 202,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;202m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;202;38;5;0m",
                },
            },
            ANSICodeSet{
                .bg = 208,
                .fg = 0,
                .codes = [_][]const u8{
                    "\x1b[48;5;208m",
                    "\x1b[38;5;0m",
                    "\x1b[48;5;208;38;5;0m",
                },
            },
        },
        [_]ANSICodeSet{
            ANSICodeSet{
                .bg = 511,
                .fg = 130,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;130m",
                    "\x1b[49;38;5;130m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 166,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;166m",
                    "\x1b[49;38;5;166m",
                },
            },
            ANSICodeSet{
                .bg = 511,
                .fg = 202,
                .codes = [_][]const u8{
                    "\x1b[49m",
                    "\x1b[38;5;202m",
                    "\x1b[49;38;5;202m",
                },
            },
        },
    },
};
