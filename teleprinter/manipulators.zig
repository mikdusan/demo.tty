const TTY = @import("tty.zig").TTY;

pub const bg = TTY.Mode.background;
pub const fg = TTY.Mode.foreground;

pub const low = TTY.Standout.low;
pub const med = TTY.Standout.medium;
pub const high = TTY.Standout.high;

pub const hue0 = TTY.Hue.hue0;
pub const hue1 = TTY.Hue.hue1;
pub const hue2 = TTY.Hue.hue2;
pub const info = TTY.Hue.info;
pub const positive = TTY.Hue.positive;
pub const negative = TTY.Hue.negative;
pub const caution = TTY.Hue.caution;
pub const alert = TTY.Hue.alert;
