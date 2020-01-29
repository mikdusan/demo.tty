const std = @import("std");
const tm = @import("../teleprinter/manipulators.zig");
const TTY = @import("../teleprinter.zig").TTY;

pub fn hexDump(tty: *TTY, bytes: []const u8) !void {
    const n16 = bytes.len >> 4;
    var line: usize = 0;
    var offset: usize = 0;
    while (line < n16) : (line += 1) {
        try hexDump16(tty, offset, bytes[offset..offset+16]);
        offset += 16;
    }

    const n = bytes.len & 0x0f;
    if (n > 0) {
        try tty.format("{d08}: ", .{tm.low, tm.info, offset});
        var end1 = std.math.min(offset+n, offset+8);
        for (bytes[offset..end1]) |b| try tty.format(" {x02}", .{b});
        var end2 = offset + n;
        if (end2 > end1) {
            try tty.write(" ");
            for (bytes[end1..end2]) |b| try tty.format(" {x02}", .{b});
        }
        const short = 16 - n;
        var i: usize = 0;
        while (i < short) : (i += 1) {
            try tty.write("   ");
        }
        if (end2 > end1) {
            try tty.write("  |");
        } else {
            try tty.write("   |");
        }
        try printCharValues(tty, bytes[offset..end2]);
        try tty.write("|\n");
        offset += n;
    }

    try tty.format("{d08}:\n", .{tm.low, tm.info, offset});
}

fn hexDump16(tty: *TTY, offset: usize, bytes: []const u8) !void {
    try tty.format("{d08}: ", .{tm.low, tm.info, offset});
    for (bytes[0..8]) |b| try tty.format(" {x02}", .{b});
    try tty.write(" ");
    for (bytes[8..16]) |b| try tty.format(" {x02}", .{b});
    try tty.write("  |");
    try printCharValues(tty, bytes);
    try tty.write("|\n");
}

fn printCharValues(tty: *TTY, bytes: []const u8) !void {
    // TODO: bug workaround: fix push/pop
    tty.alert();
    defer tty.hue0();
    for (bytes) |b| try tty.writeByte(print_char_tab[b]);
}

const print_char_tab: []const u8 =
    "................................ !\"#$%&'()*+,-./0123456789:;<=>?" ++
    "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~." ++
    "................................................................" ++
    "................................................................"
;
