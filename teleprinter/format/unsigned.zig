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
    prefix: Prefix,
    delimiter: ?u8,
    leading: u8,
    iwidth: basic.Width,

    const Prefix = enum {
        none,
        lower,
        upper,
    };
};

const Style = enum {
    binary,
    octal,
    decimal,
    hex,
    hex_upper,
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
        .style = .decimal,
        .prefix = .none,
        .delimiter = null,
        .leading = ' ',
        .iwidth = basic.Width{ .direct = 0 },
    };

    const State = union(enum) {
        fill: void,
        alignment: void,
        width_maybe: void,
        width: []const u8,
        style: void,
        prefix: void,
        delimiter: void,
        leading: void,
        iwidth0: void,
        iwidth: []const u8,
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
                'b' => {
                    options.style = .binary;
                    state = State{ .prefix = {}};
                },
                'd' => {
                    options.style = .decimal;
                    state = State{ .prefix = {}};
                },
                'o' => {
                    options.style = .octal;
                    state = State{ .prefix = {}};
                },
                'x' => {
                    options.style = .hex;
                    state = State{ .prefix = {}};
                },
                'X' => {
                    options.style = .hex_upper;
                    state = State{ .prefix = {}};
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
                'b' => {
                    options.style = .binary;
                    state = State{ .prefix = {}};
                },
                'd' => {
                    options.style = .decimal;
                    state = State{ .prefix = {}};
                },
                'o' => {
                    options.style = .octal;
                    state = State{ .prefix = {}};
                },
                'x' => {
                    options.style = .hex;
                    state = State{ .prefix = {}};
                },
                'X' => {
                    options.style = .hex_upper;
                    state = State{ .prefix = {}};
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
                'b' => {
                    options.style = .binary;
                    state = State{ .prefix = {}};
                },
                'd' => {
                    options.style = .decimal;
                    state = State{ .prefix = {}};
                },
                'o' => {
                    options.style = .octal;
                    state = State{ .prefix = {}};
                },
                'x' => {
                    options.style = .hex;
                    state = State{ .prefix = {}};
                },
                'X' => {
                    options.style = .hex_upper;
                    state = State{ .prefix = {}};
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
                'b' => {
                    options.width = basic.Width{ .direct = comptime util.unsignedForString(width, pos) };
                    options.style = .binary;
                    state = State{ .prefix = {}};
                },
                'd' => {
                    options.width = basic.Width{ .direct = comptime util.unsignedForString(width, pos) };
                    options.style = .decimal;
                    state = State{ .prefix = {}};
                },
                'o' => {
                    options.width = basic.Width{ .direct = comptime util.unsignedForString(width, pos) };
                    options.style = .octal;
                    state = State{ .prefix = {}};
                },
                'x' => {
                    options.width = basic.Width{ .direct = comptime util.unsignedForString(width, pos) };
                    options.style = .hex;
                    state = State{ .prefix = {}};
                },
                'X' => {
                    options.width = basic.Width{ .direct = comptime util.unsignedForString(width, pos) };
                    options.style = .hex_hupper;
                    state = State{ .prefix = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .style => switch (char) {
                'b' => {
                    options.style = .binary;
                    state = State{ .prefix = {}};
                },
                'd' => {
                    options.style = .decimal;
                    state = State{ .prefix = {}};
                },
                'o' => {
                    options.style = .octal;
                    state = State{ .prefix = {}};
                },
                'x' => {
                    options.style = .hex;
                    state = State{ .prefix = {}};
                },
                'X' => {
                    options.style = .hex_hupper;
                    state = State{ .prefix = {}};
                },
                else => {
                    util.compileErrorForPosition("expecting style: '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .prefix => switch (char) {
                'p' => {
                    options.prefix = .lower;
                    state = State{ .delimiter = {}};
                },
                'P' => {
                    options.prefix = .upper;
                    state = State{ .delimiter = {}};
                },
                '\'', ',', '_' => {
                    options.delimiter = char;
                    state = State{ .leading = {}};
                },
                '*' => {
                    options.iwidth = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                    state = State{ .end = {}};
                },
                '0' => {
                    options.leading = '0';
                    state = State{ .iwidth0 = {}};
                },
                '1'...'9' => {
                    state = State{ .iwidth = spec[pos..pos+1] };
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .delimiter => switch (char) {
                '\'', ',', '_' => {
                    options.delimiter = char;
                    state = State{ .leading = {}};
                },
                '0' => {
                    options.leading = '0';
                    state = State{ .iwidth0 = {}};
                },
                '1'...'9' => {
                    state = State{ .iwidth = spec[pos..pos+1] };
                },
                '*' => {
                    options.iwidth = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .leading => switch (char) {
                '0' => {
                    options.leading = '0';
                    state = State{ .iwidth0 = {}};
                },
                '1'...'9' => {
                    state = State{ .iwidth = spec[pos..pos+1] };
                },
                '*' => {
                    options.iwidth = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .iwidth0 => switch (char) {
                '1'...'9' => {
                    state = State{ .iwidth = spec[pos..pos+1] };
                },
                '*' => {
                    options.iwidth = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                    state = State{ .end = {}};
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
                    unreachable;
                },
            },
            .iwidth => switch (char) {
                '0'...'9' => {
                    state.iwidth.len += 1;
                },
                else => {
                    util.compileErrorForPosition("extra char? '" ++ spec[pos..pos+1] ++ "'", pos);
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
            .prefix => {},
            .delimiter => {},
            .leading => {},
            .iwidth0 => {
                util.compileErrorForPosition("incomplete unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
            },
            .iwidth => |width| switch (char) {
                '*' => {
                    options.iwidth = basic.Width{ .argi = next_parameter_index };
                    next_parameter_index += 1;
                },
                else => {
                    options.iwidth = basic.Width{ .direct = comptime util.unsignedForString(width, spec.len - width.len) };
                },
            },
            .end => {},
        }
    }

    switch (options.style) {
        .binary => {
            if (options.delimiter != null and options.delimiter.? == ',') {
                util.compileErrorForPosition("comma-delimiter not supported for binary style: unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
                unreachable;
            }
        },
        .octal => {
            if (options.delimiter != null and options.delimiter.? == ',') {
                util.compileErrorForPosition("comma-delimiter not supported for octal style: unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
                unreachable;
            }
        },
        .decimal => {},
        .hex => {
            if (options.delimiter != null and options.delimiter.? == ',') {
                util.compileErrorForPosition("comma-delimiter not supported for hex style: unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
                unreachable;
            }
        },
        .hex_upper => {
            if (options.delimiter != null and options.delimiter.? == ',') {
                util.compileErrorForPosition("comma-delimiter not supported for upper-hex binary style: unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
                unreachable;
            }
        },
    }

    const o_iwidth = switch (options.iwidth) {
        .direct => |direct| direct,
        .argi => |argi| usize(args[argi]),
    };

    comptime const StyleInfo = struct {
        digits: []const u8,
        base: u8,
        prefix: []const u8,
        group: usize,
    };

    comptime const ldigits = "0123456789abcdef";
    comptime const udigits = "0123456789ABCDEF";

    comptime const stinfo = switch (options.style) {
        .binary => StyleInfo{
            .digits = ldigits,
            .base = 2,
            .prefix = switch (options.prefix) {
                .none => "",
                .lower => "0b",
                .upper => "0B",
            },
            .group = 8,
        },
        .octal => StyleInfo{
            .digits = ldigits,
            .base = 8,
            .prefix = switch (options.prefix) {
                .none => "",
                .lower => "0o",
                .upper => {
                    util.compileErrorForPosition("upper-case prefix not supported for octal style: unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
                    unreachable;
                },
            },
            .group = 4,
        },
        .decimal => StyleInfo{
            .digits = ldigits,
            .base = 10,
            .prefix = switch (options.prefix) {
                .none => "",
                else => {
                    util.compileErrorForPosition("prefix not supported for decimal style: unsigned_spec '" ++ spec ++ "'", 0); // TODO: fix position index
                    unreachable;
                },
            },
            .group = 3,
        },
        .hex => StyleInfo{
            .digits = ldigits,
            .base = 16,
            .prefix = switch (options.prefix) {
                .none => "",
                .lower => "0x",
                .upper => "0X",
            },
            .group = 4,
        },
        .hex_upper => StyleInfo{
            .digits = udigits,
            .base = 16,
            .prefix = switch (options.prefix) {
                .none => "",
                .lower => "0x",
                .upper => "0X",
            },
            .group = 4,
        },
    };

    const sbsz_digits = 1 + comptime(@floatToInt(usize, std.math.floor(std.math.log2(@intToFloat(f64, std.math.maxInt(u128))) / std.math.log2(@intToFloat(f64, stinfo.base)))));
    const sbsz_delimiters = comptime(sbsz_digits / stinfo.group);
    const sbsz = comptime(sbsz_digits + sbsz_delimiters + 2); // prefix max 2

    var subject_buffer = [_]u8{ options.leading } ** sbsz;
    var subject_buffer_index: usize = subject_buffer.len;
    var idigit_num: usize = 0;
    const arg = &args[value.argi];
    if (arg.* == 0) {
        subject_buffer_index -= 1;
        subject_buffer[subject_buffer_index] = '0';
        idigit_num += 1;
    } else {
        var ival = arg.*;
        while (ival != 0) {
            // apply delimiter
            if (options.delimiter != null and subject_buffer_index != subject_buffer.len) {
                if (idigit_num % stinfo.group == 0) {
                    subject_buffer_index -= 1;
                    subject_buffer[subject_buffer_index] = options.delimiter.?;
                }
            }
            const digit = ival % stinfo.base;
            subject_buffer_index -= 1;
            subject_buffer[subject_buffer_index] = stinfo.digits[digit];
            ival /= stinfo.base;
            idigit_num += 1;
        }
    }
    // apply iwidth
    {
        const w = if (o_iwidth > sbsz_digits) sbsz_digits else o_iwidth;
        while (idigit_num < w) {
            // apply delimiter
            if (options.delimiter != null and subject_buffer_index != subject_buffer.len) {
                if (idigit_num % stinfo.group == 0) {
                    subject_buffer_index -= 1;
                    subject_buffer[subject_buffer_index] = options.delimiter.?;
                }
            }
            subject_buffer_index -= 1;
            idigit_num += 1;
        }
    }
    // apply prefix
    if (stinfo.prefix.len != 0) {
        subject_buffer_index -= stinfo.prefix.len;
        for (stinfo.prefix) |char,i| {
            subject_buffer[subject_buffer_index + i] = char;
        }
    }

    const subject = subject_buffer[subject_buffer_index..];
    try basic.emitReplacement(tty, value, options.fill, options.alignment, options.width, subject, args);
}
