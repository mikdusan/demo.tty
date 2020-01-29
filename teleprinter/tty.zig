const std = @import("std");

pub const TTY = struct {
    pub const Virtual = struct {
        startup: fn (self: *TTY) (error {WriteFailure})!void,
        shutdown: fn (self: *TTY) (error {WriteFailure})!void,
        deinit: fn (self: *TTY) void,
        write: fn (self: *TTY, bytes: []const u8) (error {WriteFailure})!void,
        writeDirect: fn (self: *TTY, bytes: []const u8) (error {WriteFailure})!void,
        push: fn (self: *TTY, state: State) (error {OutOfMemory,WriteFailure})!void,
        pop: fn (self: *TTY) ?State,
        setPersistent: fn (self: *TTY, attr: PersistentAttribute) void,
        setTransient: fn (self: *TTY, attr: TransientAttribute) void,
        endTransient: fn (self: *TTY) void,
    };
    virtual: Virtual,

    pub const Private = struct {
        destroy_self: ?*std.mem.Allocator,
        indent: u8,
        pending_indent: bool,
        tab: []const u8,
    };
    private: Private,

    pub const State = struct {
        indent: u8,
    };

    pub fn startup(self: *TTY) (error {WriteFailure})!void {
        try self.virtual.startup(self);
    }

    pub fn shutdown(self: *TTY) (error {WriteFailure})!void {
        try self.virtual.shutdown(self);
    }

    pub fn deinit(self: *TTY) void {
        self.virtual.deinit(self);
    }

    pub fn write(self: *TTY, bytes: []const u8) (error {WriteFailure})!void {
        return self.virtual.write(self, bytes);
    }

    pub fn writeByte(self: *TTY, byte: u8) (error {WriteFailure})!void {
        return self.virtual.write(self, &[_]u8{ byte });
    }

    pub fn writeDirect(self: *TTY, bytes: []const u8) (error {WriteFailure})!void {
        return self.virtual.writeDirect(self, bytes);
    }

    pub fn writeDirectByte(self: *TTY, byte: u8) (error {WriteFailure})!void {
        return self.virtual.writeDirect(self, &[_]u8{ byte });
    }

    pub fn push(self: *TTY) (error {OutOfMemory,WriteFailure})!void {
        try self.virtual.push(self, State{ .indent = self.private.indent });
    }

    pub fn pop(self: *TTY) void {
        if (self.virtual.pop(self)) |item| {
            self.private.indent = item.indent;
            self.private.pending_indent = true;
        }
    }

    pub fn setPersistent(self: *TTY, attr: PersistentAttribute) void {
        switch (attr) {
            .indent => {
                if (self.private.indent != std.math.maxInt(@TypeOf(self.private.indent))) {
                    self.private.indent += 1;
                    self.private.pending_indent = true;
                }
            },
            .dedent => {
                if (self.private.indent != 0) self.private.indent -= 1;
            },
            .nodent => {
                self.private.indent = 0;
            },
            else => self.virtual.setPersistent(self, attr),
        }
    }

    pub fn setTransient(self: *TTY, attr: TransientAttribute) void {
        self.virtual.setTransient(self, attr);
    }

    pub fn endTransient(self: *TTY) void {
        self.virtual.endTransient(self);
    }

    pub fn format(self: *TTY, comptime fmt: []const u8, args: var) Error!void {
        return @import("format/parser.zig").parse(self, fmt, args);
    }

    pub fn reset(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .hue0 });
        self.setPersistent(PersistentAttribute{ .standout = .medium });
        self.setPersistent(PersistentAttribute{ .mode = .foreground });
    }

    pub fn resetAll(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .nodent = {}});
        self.reset();
    }

    pub fn indent(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .indent = {}});
    }

    pub fn dedent(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .dedent = {}});
    }

    pub fn nodent(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .nodent = {}});
    }

    pub fn hue0(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .hue0 });
    }

    pub fn hue1(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .hue1 });
    }

    pub fn hue2(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .hue2 });
    }

    pub fn info(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .info });
    }

    pub fn positive(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .positive });
    }

    pub fn negative(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .negative });
    }

    pub fn caution(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .caution });
    }

    pub fn alert(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .hue = .alert });
    }

    pub fn low(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .standout = .low });
    }

    pub fn medium(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .standout = .medium });
    }

    pub fn high(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .standout = .high });
    }

    pub fn bg(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .mode = .background });
    }

    pub fn fg(self: *TTY) void {
        self.setPersistent(PersistentAttribute{ .mode = .foreground });
    }

    pub fn nocolorWrite(self: *TTY, bytes: []const u8) (error {WriteFailure})!void {
        var pending = bytes[0..0];
        for (bytes) |char,pos| {
            switch (char) {
                '\n' => {
                    if (pending.len != 0) self.writeDirect(pending) catch return error.WriteFailure;
                    self.writeDirect("\n") catch return error.WriteFailure;
                    self.private.pending_indent = self.private.indent != 0;
                    pending = bytes[pos+1..pos+1];
                },
                '\r' => {
                    self.writeDirect("\r") catch return error.WriteFailure;
                },
                else => {
                    if (self.private.pending_indent) {
                        var i: usize = 0;
                        while (i < self.private.indent) : (i += 1) self.writeDirect(self.private.tab) catch return error.WriteFailure;
                        self.private.pending_indent = false;
                    }
                    pending.len += 1;
                },
            }
        }

        if (pending.len != 0) self.writeDirect(pending) catch return error.WriteFailure;
    }

    pub const Error = error {
        WriteFailure,
        FormatFailure,
    };

    pub const PersistentAttribute = union(enum) {
        indent: void,
        dedent: void,
        nodent: void,
        hue: Hue,
        standout: Standout,
        mode: Mode,
    };

    pub const TransientAttribute = union(enum) {
        hue: Hue,
        standout: Standout,
        mode: Mode,
    };

    pub const Hue = enum {
        hue0,
        hue1,
        hue2,
        info,
        positive,
        negative,
        caution,
        alert,

        const _Manipulator = Trait.Manipulator;
    };

    pub const Standout = enum {
        low,
        medium,
        high,

        const _Manipulator = Trait.Manipulator;
    };

    pub const Mode = enum {
        background,
        foreground,

        const _Manipulator = Trait.Manipulator;
    };

    pub const Trait = struct {
        pub const Manipulator = struct{};
    };
};
