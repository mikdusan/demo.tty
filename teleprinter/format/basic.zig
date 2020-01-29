const parser = @import("parser.zig");
const TTY = @import("../tty.zig").TTY;

pub const Fill = union(enum) {
    direct: u8,
    argi: usize,
};

pub const Width = union(enum) {
    direct: usize,
    argi: usize,
};

pub const Alignment = enum {
    left,
    right,
    center,
};

pub fn emitReplacement(
    tty: *TTY,
    comptime value: parser.Argument.Value,
    comptime fill: Fill,
    comptime alignment: Alignment,
    comptime width: Width,
    subject: var,
    args: var,
) !void {
    const o_width = switch (width) {
        .direct => |direct| direct,
        .argi => |argi| @as(usize, args[argi]),
    };

    if (o_width == 0 or o_width <= subject.len) {
        try emitSubject(tty, value, subject, args);
        return;
    }

    const o_fill: []const u8 = switch (fill) {
        .direct => |direct| ([_]u8{ direct })[0..],
        .argi => |argi| if (@TypeOf(args[argi]) == u8) ([_]u8{ args[argi] })[0..] else args[argi],
    };

    const padw = o_width - subject.len;
    switch (alignment) {
        .left => {
            try emitSubject(tty, value, subject, args);
            var i: usize = 0;
            while (i < padw) : (i += 1) try tty.write(o_fill);
        },
        .right => {
            var i: usize = 0;
            while (i < padw) : (i += 1) try tty.write(o_fill);
            try emitSubject(tty, value, subject, args);
        },
        .center => {
            const padl = padw / 2;
            var i: usize = 0;
            while (i < padl) : (i += 1) try tty.write(o_fill);
            try emitSubject(tty, value, subject, args);
            while (i < padw) : (i += 1) try tty.write(o_fill);
        },
    }
}

fn emitSubject(tty: *TTY, comptime value: parser.Argument.Value, subject: var, args: var) !void {
    if (value.manipulators.len == 0) {
        try tty.write(subject);
    } else {
        // apply manipulators to tty
        comptime var argi = value.manipulators.begin;
        comptime const end = argi + value.manipulators.len;
        inline while (argi < end) {
            const attr = switch (@TypeOf(args[argi])) {
                TTY.Hue => TTY.TransientAttribute{ .hue = args[argi] },
                TTY.Standout => TTY.TransientAttribute{ .standout = args[argi] },
                TTY.Mode => TTY.TransientAttribute{ .mode = args[argi] },
                else => @panic("unimplemented manipulator type: " ++ @typeName(@TypeOf(args[argi]))),
            };
            tty.setTransient(attr);
            argi += 1;
        }
        try tty.write(subject);
        tty.endTransient();
    }
}
