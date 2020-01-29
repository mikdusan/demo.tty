const std = @import("std");

pub fn stringForUnsigned(comptime value: usize) []const u8 {
    if (value == 0) return "0";

    const base = 10;
    const base_digits = "0123456789";
    const ndigits = 1 + @floatToInt(
        usize,
        std.math.floor(std.math.log2(@intToFloat(f64, value)) / std.math.log2(@intToFloat(f64, base))),
    );
    comptime var buffer: [ndigits]u8 = undefined;
    comptime var i = buffer.len;
    comptime var a = value;
    inline while (i > 0 and a != 0) {
        i -= 1;
        const digit = a % base;
        buffer[i] = base_digits[digit];
        a /= base;
    }

    return buffer[0..];
}

pub fn unsignedForString(comptime string: []const u8, comptime pos: usize) usize {
    if (string[0] == '0') {
        if (string.len == 1) return 0;
        compileErrorForPosition(
            "failure parsing unsigned integer '"
                ++ string
                ++ "': invalid char '"
                ++ string[0..1]
                ++ "'"
            ,
            pos - string.len,
        );
        unreachable;
    }

    comptime var index: usize = 0;
    inline for (string) |c,i| {
        const digit = switch (c) {
            '0'...'9' => c - '0',
            else => {
                compileErrorForPosition(
                    "failure parsing unsigned integer '"
                        ++ string
                        ++ "': invalid char '"
                        ++ string[i..i+1]
                        ++ "'"
                    ,
                    pos - string.len,
                );
                unreachable;
            },
        };

        if (index != 0) index = index * 10;
        index = index + digit;
    }

    return index;
}

pub fn compileErrorForPosition(comptime fmt: []const u8, comptime pos: usize) void {
    @compileError(fmt ++ " @ format[" ++ stringForUnsigned(pos) ++ "]");
    unreachable;
}

pub fn compileError(comptime fmt: []const u8) void {
    @compileError(fmt);
    unreachable;
}

pub fn errorTextInvalidChar(comptime char: u8) []const u8 {
    return "invalid char '" ++ [_]u8{ char } ++ "'";
}
