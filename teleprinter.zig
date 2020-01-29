pub const manipulators = @import("teleprinter/manipulators.zig");
pub const TTY = @import("teleprinter/tty.zig").TTY;
pub const Dumb_TTY = @import("teleprinter/dumb.zig").Dumb_TTY;
pub const ANSI_TTY = @import("teleprinter/ansi.zig").ANSI_TTY;

pub const std = @import("std");
const m = manipulators;

pub fn autoTTY(allocator: *std.mem.Allocator, comptime function: var, context: var, file: ?std.fs.File) !*TTY {
    const kind = switch (@TypeOf(context)) {
        std.fs.File => autoKind(context),
        else => autoKind(file),
    };
    switch (kind) {
        .dumb => {
            const T = Dumb_TTY(function);
            var result = try allocator.create(T);
            result.* = T.init(allocator, true, context);
            return &result.tty;
        },
        .ansi8 => {
            const T = ANSI_TTY(function);
            var result = try allocator.create(T);
            errdefer allocator.destroy(result);
            result.* = try T.init(allocator, true, context, .ansi8);
            return &result.tty;
        },
    }
}

pub const Kind = enum {
    dumb,
    ansi8,
};

fn autoKind(file: ?std.fs.File) Kind {
    var cached_env_color_invalid = true;
    var cached_env_color: ?[]const u8 = null;
    if (cached_env_color_invalid) {
        cached_env_color = std.os.getenv("MIK_TTY_COLOR");
        cached_env_color_invalid = false;
    }

    if (cached_env_color) |uw| {
        if (std.mem.eql(u8, uw, "always")) return Kind.ansi8;
        if (std.mem.eql(u8, uw, "never")) return Kind.dumb;
    }
    if (file) |mfile| {
        if (std.fs.File.isTty(mfile)) {
            var cached_env_term_invalid = true;
            var cached_env_term: ?[]const u8 = null;
            if (cached_env_term_invalid) {
                cached_env_term = std.os.getenv("TERM");
                cached_env_term_invalid = false;
            }

            if (cached_env_term) |uw| {
                if (std.mem.indexOf(u8, uw, "256color")) |_| return Kind.ansi8;
            }
        }
    }
    return Kind.dumb;
}
