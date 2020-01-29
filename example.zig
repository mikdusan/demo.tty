const std = @import("std");
const tm = tp.manipulators;
const tp = @import("teleprinter.zig");

pub fn main() !void {
    var arena_impl = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_impl.deinit();
    const arena = &arena_impl.allocator;

    const out = try tp.autoTTY(arena, std.fs.File.write, std.io.getStdOut(), null);
    defer out.deinit();
    try out.startup();
    defer out.shutdown() catch {};

    try printReport(out);

    try out.format("\n--- hexdump:\n\n", .{});
    try @import("coreutil.zig").hexDump(out, &[_]u8{
        0x23, 0x23, 0x0a, 0x23, 0x20, 0x55, 0x73, 0x65,     0x72, 0x20, 0x44, 0x61, 0x74, 0x61, 0x62, 0x61,
        0x73, 0x65, 0x0a, 0x23, 0x20, 0x0a, 0x23, 0x20,     0x4e, 0x6f, 0x74, 0x65, 0x20, 0x74, 0x68, 0x61,
        0x74, 0x20, 0x74, 0x68, 0x69, 0x73, 0x20, 0x66,     0x69, 0x6c, 0x65, 0x20, 0x69, 0x73, 0x20, 0x63,
        0x6f, 0x6e, 0x73, 0x75, 0x6c, 0x74, 0x65, 0x64,     0x20, 0x64, 0x69, 0x72, 0x65, 0x63, 0x74, 0x6c,
        0x79, 0x20, 0x6f, 0x6e, 0x6c, 0x79, 0x20, 0x77,     0x68, 0x65, 0x6e, 0x20, 0x74, 0x68, 0x65, 0x20,
        0x73, 0x79, 0x73, 0x74, 0x65, 0x6d, 0x20, 0x69,     0x73, 0x20, 0x72, 0x75, 0x6e, 0x6e, 0x69, 0x6e,
        0x67, 0x0a,
    });
}

fn printReport(tty: *tp.TTY) !void {
    {
        try tty.format("\n--- HUES AND INTENSITY\n\n", .{});
        try tty.push();
        tty.indent();
        defer tty.pop();
        try tty.format("{9} {} {} {}\n", .{
            tm.hue0, "hue0",
            tm.low, tm.hue0, "low",
            tm.med, tm.hue0, "medium",
            tm.high, tm.hue0, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.hue1, "hue1",
            tm.low, tm.hue1, "low",
            tm.med, tm.hue1, "medium",
            tm.high, tm.hue1, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.hue2, "hue2",
            tm.low, tm.hue2, "low",
            tm.med, tm.hue2, "medium",
            tm.high, tm.hue2, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.info, "info",
            tm.low, tm.info, "low",
            tm.med, tm.info, "medium",
            tm.high, tm.info, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.positive, "positive",
            tm.low, tm.positive, "low",
            tm.med, tm.positive, "medium",
            tm.high, tm.positive, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.negative, "negative",
            tm.low, tm.negative, "low",
            tm.med, tm.negative, "medium",
            tm.high, tm.negative, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.caution, "caution",
            tm.low, tm.caution, "low",
            tm.med, tm.caution, "medium",
            tm.high, tm.caution, "high",
        });
        try tty.format("{9} {} {} {}\n", .{
            tm.alert, "alert",
            tm.low, tm.alert, "low",
            tm.med, tm.alert, "medium",
            tm.high, tm.alert, "high",
        });
    }

    {
        try tty.format("\n--- TYPE: bool\n\n", .{});
        try tty.push();
        tty.indent();
        defer tty.pop();

        try tty.format("format={4} → {6} / {}\n", .{tm.hue1, "{}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6e} / {e}\n", .{tm.hue1, "{e}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6o} / {o}\n", .{tm.hue1, "{o}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6p} / {p}\n", .{tm.hue1, "{p}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6t} / {t}\n", .{tm.hue1, "{t}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6y} / {y}\n", .{tm.hue1, "{y}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6tc} / {tc}\n", .{tm.hue1, "{tc}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6tl} / {tl}\n", .{tm.hue1, "{tl}", tm.info, true, tm.info, false});
        try tty.format("format={4} → {6tu} / {tu}\n", .{tm.hue1, "{tu}", tm.info, true, tm.info, false});
    }

    {
        try tty.format("\n--- TYPE: unsigned\n\n", .{});
        try tty.push();
        tty.indent();
        defer tty.pop();

        var i: u64 = 0x4a39cc0f;
        try tty.format("format={7} → {}\n", .{tm.hue1, "{}", tm.info, i});
        try tty.format("format={7} → {b}\n", .{tm.hue1, "{b}", tm.info, i});
        try tty.format("format={7} → {b064}\n", .{tm.hue1, "{b064}", tm.info, i});
        try tty.format("format={7} → {o}\n", .{tm.hue1, "{o}", tm.info, i});
        try tty.format("format={7} → {o016}\n", .{tm.hue1, "{o016}", tm.info, i});
        try tty.format("format={7} → {d}\n", .{tm.hue1, "{d}", tm.info, i});
        try tty.format("format={7} → {d012}\n", .{tm.hue1, "{d012}", tm.info, i});
        try tty.format("format={7} → {x}\n", .{tm.hue1, "{x}", tm.info, i});
        try tty.format("format={7} → {x016}\n", .{tm.hue1, "{x016}", tm.info, i});
        try tty.format("format={7} → {xp}\n", .{tm.hue1, "{xp}", tm.info, i});
        try tty.format("format={7} → {xp016}\n", .{tm.hue1, "{xp016}", tm.info, i});
        try tty.format("format={7} → {X}\n", .{tm.hue1, "{X}", tm.info, i});
        try tty.format("format={7} → {X016}\n", .{tm.hue1, "{X016}", tm.info, i});
        try tty.format("format={7} → {Xp}\n", .{tm.hue1, "{Xp}", tm.info, i});
        try tty.format("format={7} → {Xp016}\n", .{tm.hue1, "{Xp016}", tm.info, i});

        try tty.format("format={7} → {XP016}\n", .{tm.hue1, "{XP016}", tm.info, i});

        try tty.format("\nfill/center/delimit:\n\n", .{});

        try tty.format("format={11} → {^40d}\n", .{tm.hue1, "{^40d}",tm.info, i});
        try tty.format("format={11} → {^40d,}\n", .{tm.hue1, "{^40d,}",tm.info, i});
        try tty.format("format={11} → {^40d_}\n", .{tm.hue1, "{^40d_}",tm.info, i});
        try tty.format("format={11} → {^40d'}\n", .{tm.hue1, "{^40d'}",tm.info, i});
        try tty.format("format={11} → {:^40d'}\n", .{tm.hue1, "{:^40d'}", tm.info, i});
    }

    {
        try tty.format("\n--- TYPE: string\n\n", .{});
        try tty.push();
        tty.indent();
        defer tty.pop();

        var width: usize = 20;
        var fill: u8 = ':';
        try tty.format("runtime fill/center/width: `{}` → {*^*s}\n", .{tm.hue1, "format(\"{*^*s}\", .{\"hello\", fill, width});", tm.info, "hello", fill, width});
    }
}
