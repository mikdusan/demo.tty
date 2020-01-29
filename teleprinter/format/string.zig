const std = @import("std");
const basic = @import("basic.zig");
const parser = @import("parser.zig");
const util = @import("util.zig");
const TTY = @import("../tty.zig").TTY;

const Options = struct {
    fill: basic.Fill,
    alignment: basic.Alignment,
    width: basic.Width,
    style: Style,
};

const Alignment = enum {
    left,
    right,
    center,
};

const Style = enum {
    default,
};

pub fn parse(
    tty: *TTY,
    comptime fmt: []const u8,
    comptime spec: []const u8,
    comptime value: parser.Argument.Value,
    comptime varargs: parser.VarArgs,
    args: var,
) TTY.Error!void {
    comptime var options = Options{
        .fill = basic.Fill{ .direct = ' ' },
        .alignment = .left,
        .width = basic.Width{ .direct = 0 },
        .style = .default,
    };

    const State = union(enum) {
        fill: void,
        alignment: void,
        width_maybe: void,
        width: []const u8,
        style: void,
        end: void,
    };
    comptime var state = State{ .fill = {}};
    comptime var next_parameter_index = value.argi + 1;

    inline for (spec) |char, pos| {
//@compileLog(pos,state,char);
//std.debug.warn("pos={}  state={}  `{c}`\n", pos, state, char);
        switch (state) {
            .fill => switch (char) {
                '<' => {
                    options.alignment = .left;
                    state = State{ .width_maybe = {}};
                },
                '>' => {
                    options.alignment = .right;
                    state = State{ .width_maybe = {}};
                },
                '^' => {
                    options.alignment = .center;
                    state = State{ .width_maybe = {}};
                },
                '0'...'9' => {
                    state = State{ .width = spec[pos..pos+1] };
                },
                's' => {
                    options.style = .default;
                    state = State{ .end = {}};
                },
                else => {
                    state = State{ .alignment = {}};
                },
            },
            .alignment => switch (char) {
                '<' => {
                    if (spec[pos-1] == '*') {
                        options.fill = basic.Fill{ .argi = next_parameter_index };
                        next_parameter_index += 1;
                    } else {
                        options.fill = basic.Fill{ .direct = spec[pos-1] };
                    }
                    options.alignment = .left;
                    state = State{ .width_maybe = {}};
                },
                '>' => {
                    if (spec[pos-1] == '*') {
                        options.fill = basic.Fill{ .argi = next_parameter_index };
                        next_parameter_index += 1;
                    } else {
                        options.fill = basic.Fill{ .direct = spec[pos-1] };
                    }
                    options.alignment = .right;
                    state = State{ .width_maybe = {}};
                },
                '^' => {
                    if (spec[pos-1] == '*') {
                        options.fill = basic.Fill{ .argi = next_parameter_index };
                        next_parameter_index += 1;
                    } else {
                        options.fill = basic.Fill{ .direct = spec[pos-1] };
                    }
                    options.alignment = .center;
                    state = State{ .width_maybe = {}};
                },
                '0'...'9' => {
                    state = State{ .width = spec[pos..pos+1] };
                },
                's' => {
                    options.style = .default;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .width_maybe => switch (char) {
                '*' => {
                    options.width = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                    state = State{ .style = {}};
                },
                '0'...'9' => {
                    state = State{ .width = spec[pos..pos+1] };
                },
                's' => {
                    options.style = .default;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .width => |width| switch (char) {
                '0'...'9' => {
                    state.width.len += 1;
                },
                's' => {
                    options.width = basic.Width{ .direct = comptime util.unsignedForString(width, pos) };
                    options.style = .default;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .style => switch (char) {
                's' => {
                    options.style = .default;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("expecting style: '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .end => {
                util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                unreachable;
            },
        }
    }

    // finish pending
    if (spec.len != 0) {
        const char = spec[spec.len-1];
        switch (state) {
            .fill => {},
            .alignment => switch (char) {
                '*' => {
                    options.width = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                },
                else => {
                    util.compileErrorForPosition("invalid char '" ++ spec[spec.len-1..spec.len] ++ "'", spec.len - 1);
                },
            },
            .width => |width| options.width = basic.Width{ .direct = comptime util.unsignedForString(width, spec.len - width.len) },
            .width_maybe => {},
            .style => {},
            .end => {},
        }
    }

    const subject: []const u8 = args[value.argi];
    try basic.emitReplacement(tty, value, options.fill, options.alignment, options.width, subject, args);
}
