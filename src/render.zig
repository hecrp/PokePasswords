// render.zig
//
// Native terminal sprite rendering using Unicode half-blocks and 24-bit ANSI colors.
// No external tools (chafa, viu, etc.) required.

const std = @import("std");
const Io = std.Io;

pub const Rgba32 = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const default_bg = Rgba32{ .r = 26, .g = 26, .b = 46, .a = 255 };

/// Render an RGBA32 image to the terminal using upper-half block characters (▀).
/// Each terminal row displays two pixel rows (top = foreground, bottom = background).
pub fn render_rgba32(
    stdout: *Io.Writer,
    pixels: []const Rgba32,
    src_width: usize,
    src_height: usize,
    max_width: usize,
) !void {
    if (src_width == 0 or src_height == 0 or pixels.len == 0) return;

    const display_w = @min(max_width, src_width);
    const display_h_pixels = @max(1, (src_height * display_w) / src_width);
    const terminal_rows = (display_h_pixels + 1) / 2;

    const scale_x = @as(f32, @floatFromInt(src_width)) / @as(f32, @floatFromInt(display_w));
    const scale_y = @as(f32, @floatFromInt(src_height)) / @as(f32, @floatFromInt(display_h_pixels));

    try stdout.print("\n", .{});

    for (0..terminal_rows) |term_row| {
        const top_row: usize = term_row * 2;
        const bottom_row: usize = top_row + 1;

        for (0..display_w) |col| {
            const top = sample_pixel(pixels, src_width, src_height, col, top_row, scale_x, scale_y);
            const bottom = if (bottom_row < display_h_pixels)
                sample_pixel(pixels, src_width, src_height, col, bottom_row, scale_x, scale_y)
            else
                default_bg;

            const top_rgb = resolve_color(top);
            const bottom_rgb = resolve_color(bottom);

            try stdout.print("\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m▀\x1b[0m", .{
                top_rgb.r, top_rgb.g, top_rgb.b,
                bottom_rgb.r, bottom_rgb.g, bottom_rgb.b,
            });
        }
        try stdout.print("\n", .{});
    }

    try stdout.print("\n", .{});
}

fn sample_pixel(
    pixels: []const Rgba32,
    src_width: usize,
    src_height: usize,
    col: usize,
    row: usize,
    scale_x: f32,
    scale_y: f32,
) Rgba32 {
    const src_x = @min(@as(usize, @intFromFloat(@as(f32, @floatFromInt(col)) * scale_x)), src_width - 1);
    const src_y = @min(@as(usize, @intFromFloat(@as(f32, @floatFromInt(row)) * scale_y)), src_height - 1);
    return pixels[src_x + src_y * src_width];
}

fn resolve_color(pixel: Rgba32) Rgba32 {
    if (pixel.a < 128) return default_bg;
    return pixel;
}

test "render dimensions" {
    const pixels = [_]Rgba32{
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 0, .g = 255, .b = 0, .a = 255 },
        .{ .r = 0, .g = 0, .b = 255, .a = 255 },
        .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    };
    try std.testing.expectEqual(@as(usize, 4), pixels.len);
}
