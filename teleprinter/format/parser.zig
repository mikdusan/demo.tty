const std = @import("std");
const builtin = @import("builtin");
const util = @import("util.zig");
const TTY = @import("../tty.zig").TTY;

const Bool = @import("bool.zig");
const String = @import("string.zig");
const Unsigned = @import("unsigned.zig");

// Representation of a vararg.
pub const Argument = union(enum) {
    value: Value,
    manipulator: usize,

    pub const Value = struct {
        argi: usize,
        type_: type,
        never_used: bool,
        manipulators: Range,
        parameters: [4]usize,
    };

    pub const Range = struct {
        begin: usize,
        len: usize,
    };
};

// Representation of a format string replacement.
pub const Replacement = struct {
    spec: []const u8,
    argi: usize,
};

pub const VarArgs = struct {
    args: []Argument,
    next_value_index: usize,

    fn nextExpectParameter(comptime self: *VarArgs) void {
        if (!(self.next_value_index < self.args.len)) {
            util.compileError("too few arguments: arg[" ++ util.stringForUnsigned(self.next_value_index) ++ "] does not exist");
            unreachable;
        }
        switch (self.args[self.next_value_index]) {
            .value => |*value| {
                value.never_used = false;
            },
            .manipulator => {
                util.compileError("expecting parameter: arg[" ++ util.stringForUnsigned(self.next_value_index) ++ "] is a manipulator");
                unreachable;
            }
        }
        self.next_value_index += 1;
    }

    fn nextValueIndex(comptime self: *VarArgs) usize {
        var found = false;
        var i = self.next_value_index;
        while (i < self.args.len) {
            if (!found) {
                switch (self.args[i]) {
                    .value => |*value| {
                        found = true;
                        value.never_used = false;
                    },
                    .manipulator => {
                        self.next_value_index += 1;
                    },
                }
            }
            i += 1;
        }
        if (!(self.next_value_index < self.args.len) or !found) {
            util.compileError("too few arguments: arg[" ++ util.stringForUnsigned(self.next_value_index) ++ "] does not exist");
            unreachable;
        }
        const result = self.next_value_index;
        self.next_value_index += 1;
        return result;
    }
};

pub fn parse(tty: *TTY, comptime fmt: []const u8, args: var) TTY.Error!void {
//    @compileLog("fmt",fmt);
//    @compileLog("args",args);
//    @compileLog("args.len",args.len);
    comptime var varargs_storage: [args.len]Argument = undefined;
    {
        comptime var manip_begin: ?usize = null;
        inline for (varargs_storage) |*arg,i| {
            if (comptime typeHasTrait(@TypeOf(args[i]), TTY.Trait.Manipulator)) {
//@compileLog("manip",i);
                arg.* = Argument{ .manipulator = i };
                if (manip_begin == null) manip_begin = i;
            } else {
                comptime var range: Argument.Range = undefined;
                if (manip_begin) |mb| {
                    range = Argument.Range{ .begin = mb, .len = i - mb };
                } else {
                    range = Argument.Range{ .begin = 0, .len = 0 };
                }
                manip_begin = null;
                arg.* = Argument{
                    .value = Argument.Value{
                        .argi = i,
                        .type_ = @TypeOf(args[i]),
                        .never_used = true,
                        .manipulators = range,
                        .parameters = [_]usize{ 0, 0, 0, 0 },
                    },
                };
//@compileLog("not-manip",i,arg.value.type_,args[i]);
            }
        }
    }
    comptime var varargs = VarArgs{
        .args = varargs_storage[0..],
        .next_value_index = 0,
    };

    const State = enum {
        start,
        text,
        replacement_open_or_escape,
        escape_close,
        replacement_index_or_spec,
        replacement_spec,
    };

    comptime var state: State = .start;
    comptime var positional_argument_index: usize = 0;
    comptime var literal: []const u8 = undefined;

    inline for (fmt) |char, pos| {
//@compileLog(pos,state,char,literal);
//std.debug.warn("pos={}  state={}  `{c}`\n", pos, state, char);
        switch (state) {
            .start => switch (char) {
                '{' => {
                    state = .replacement_open_or_escape;
                    literal = fmt[pos+1..pos+1];
                },
                '}' => {
                    state = .escape_close;
                },
                else => {
                    state = .text;
                    literal = fmt[pos..pos+1];
                },
            },
            .text => switch (char) {
                '{' => {
                    try tty.write(literal);
                    state = .replacement_open_or_escape;
                    literal = fmt[pos+1..pos+1];
                },
                '}' => {
                    state = .escape_close;
                },
                else => {
                    literal.len += 1;
                },
            },
            .replacement_open_or_escape => switch (char) {
                '{' => {
                    try tty.write([]u8{ char });
                    state = .start;
                },
                '}' => {
                    const argi = comptime varargs.nextValueIndex();
                    try parseReplacement(tty, fmt, literal, varargs.args[argi].value, varargs, args);
                    state = .start;
                },
                '*' => {
                    positional_argument_index = comptime varargs.nextValueIndex();
                    comptime varargs.nextExpectParameter();
                    state = .replacement_spec;
                    literal = fmt[pos..pos+1];
                },
                else => {
                    //positional_argument_index = comptime varargs.nextValueIndex();
                    state = .replacement_index_or_spec;
                    literal = fmt[pos..pos+1];
                },
            },
            .escape_close => switch (char) {
                '}' => {
                    try tty.write([]u8{ char });
                    state = .start;
                },
                else => {
                    util.compileErrorForPosition("invalid char '" ++ fmt[pos..pos+1] ++ "': expected '}'", pos);
                    unreachable;
                },
            },
            .replacement_index_or_spec => switch (char) {
                '{' => {
                    util.compileErrorForPosition("replacement_spec: unexpected char '{'", pos);
                    unreachable;
                },
                '}' => {
                    positional_argument_index = comptime varargs.nextValueIndex();
                    try parseReplacement(tty, fmt, literal, varargs.args[positional_argument_index].value, varargs, args);
                    state = .start;
                },
                '/' => {
                    if (literal.len == 0) {
                        positional_argument_index = comptime varargs.nextValueIndex();
                    } else {
                        const ufs = comptime util.unsignedForString(literal, pos);
                        if (!(ufs < args.len)) {
                            util.compileErrorForPosition(
                                "arg_index "
                                    ++ literal
                                    ++ " exceeds args.len="
                                    ++ util.stringForUnsigned(args.len),
                                pos - literal.len,
                            );
                            unreachable;
                        }
                        positional_argument_index = ufs;
                        varargs.args[positional_argument_index].value.never_used = false;
                    }
                    state = .replacement_spec;
                },
                '*' => {
                    positional_argument_index = comptime varargs.nextValueIndex();
                    comptime varargs.nextExpectParameter();
                    state = .replacement_spec;
                    literal.len += 1;
                },
                else => {
                    literal.len += 1;
                },
            },
            .replacement_spec => switch (char) {
                '{' => {
                    util.compileErrorForPosition("replacement_spec: unexpected char '{'", pos);
                    unreachable;
                },
                '}' => {
                    try parseReplacement(tty, fmt, literal, varargs.args[positional_argument_index].value, varargs, args);
                    state = .start;
                },
                '*' => {
                    comptime varargs.nextExpectParameter();
                    literal.len += 1;
                },
                else => {
                    literal.len += 1;
                },
            },
            else => {
                std.debug.warn("state: {}\n", state);
                @panic("state WIP");
            },
        }
    }

    switch (state) {
        .start,
        => {},
        .text => {
            try tty.write(literal);
        },
        else => {
            std.debug.warn("end state: {}\n", state);
            @panic("end state WIP");
        },
    }

    // emit error if arg never used
    comptime {
        var indexes: []const u8 = "";
        for (varargs.args) |arg,i| {
            switch (arg) {
                .value => |value| {
                    if (value.never_used) {
                        if (indexes.len != 0) indexes = indexes ++ ", ";
                        indexes = indexes ++ util.stringForUnsigned(i);
                    }
                },
                else => {},
            }
        }
        if (indexes.len != 0) {
            var text: []const u8 = "format argument";
            if (indexes.len > 1) text = text ++ "s";
            text = text ++ " never used: " ++ indexes;
            @compileError(text);
        }
    }
}

fn parseReplacement(
    tty: *TTY,
    comptime fmt: []const u8,
    comptime spec: []const u8,
    comptime value: Argument.Value,
    comptime varargs: VarArgs,
    args: var,
) TTY.Error!void {
    const arg = args[value.argi];
    const arg_info = @typeInfo(value.type_);
//@compileLog("arg",value.argi,value.type_,arg,arg_info);
    switch (arg_info) {
        .Array => |array| switch (array.child) {
            u8 => {
                return String.parse(tty, fmt, spec, value, varargs, args);
            },
            else => {},
        },
        .Bool => {
            return Bool.parse(tty, fmt, spec, value, varargs, args);
        },
        .Pointer => |pointer| switch (pointer.child) {
            u8 => {
                return String.parse(tty, fmt, spec, value, varargs, args);
            },
            else => {
                const child_info = @typeInfo(pointer.child);
                switch (child_info) {
                    .Array => |a2| switch (a2.child) {
                        u8 => {
                            return String.parse(tty, fmt, spec, value, varargs, args);
                        },
                        else => {},
                    },
                    else => {},
                }
                @compileError("unexpected argument Pointer.child info: " ++ @tagName(child_info));
            },
        },
        .Int => |int| {
            if (!int.is_signed) {
                return Unsigned.parse(tty, fmt, spec, value, varargs, args);
            }
        },
        // TODO
        //.ComptimeInt => {},
        else => {},
    }
    @compileError("unexpected argument info: " ++ @tagName(arg_info));
}

fn typeHasTrait(comptime T: type, comptime Trait: type) bool {
    const decls = switch (@typeInfo(T)) {
        .Enum => |enum_| enum_.decls,
        .Union => |union_| union_.decls,
        .Struct => |struct_| struct_.decls,
        else => return false,
    };
    inline for (decls) |def| {
        switch (def.data) {
            .Type => {
                if (def.data.Type == Trait) return true;
            },
            else => {},
        }
    }
    return false;
}
