// main.zig
//
// Entry point of the application and CLI for generating passwords
// from Pokémon sprites.

const std = @import("std");
const Io = std.Io;
const entropy = @import("entropy");
const password = @import("password");
const render = @import("render");
const zigimg = @import("zigimg");

const TARGET_WIDTH: usize = 64;
const TARGET_HEIGHT: usize = 64;
const DEFAULT_RENDER_WIDTH: usize = 48;
const MAX_PASSWORD_COUNT: usize = 20;

const CliOptions = struct {
    sprite_path: ?[]const u8 = null,
    dir_path: ?[]const u8 = null,
    password_length: usize = 16,
    min_length: usize = 8,
    max_length: usize = 32,
    password_count: usize = 1,
    show_preview: bool = false,
    show_help: bool = false,
    show_render: bool = false,
    render_width: usize = DEFAULT_RENDER_WIDTH,
    randomize: bool = false,
    secret: ?[]const u8 = null,
    character_sets: []const u8 = "ulns",
    complexity: []const u8 = "normal",
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const start_ns = Io.Clock.awake.now(io).nanoseconds;

    var stdout_buffer: [8192]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    const options = parse_cli_options(args) catch |err| {
        if (err == error.InvalidArgument or err == error.MissingValue) {
            try print_usage(stdout);
            try stdout.flush();
            return;
        }
        return err;
    };

    if (options.show_help) {
        try print_usage(stdout);
        try stdout.flush();
        return;
    }

    try print_welcome_banner(stdout);

    const entropy_hash = try process_sprites(options, allocator, io, stdout);
    defer allocator.free(entropy_hash);

    const seed = try entropy.derive_seed(entropy_hash, options.secret, allocator);
    defer allocator.free(seed);

    const policy = try create_password_policy(options);

    const end_ns = Io.Clock.awake.now(io).nanoseconds;
    const execution_time_ms = @divTrunc(end_ns - start_ns, std.time.ns_per_ms);

    if (options.password_count == 1) {
        const pwd = try password.generate_password(seed, policy, allocator, options.randomize, io);
        defer allocator.free(pwd);
        try display_password(stdout, pwd, options, execution_time_ms);
    } else {
        const passwords = try password.generate_multiple_passwords(
            seed,
            policy,
            options.password_count,
            allocator,
            options.randomize,
            io,
        );
        defer {
            for (passwords) |pwd| allocator.free(pwd);
            allocator.free(passwords);
        }
        try display_passwords(stdout, passwords, options, execution_time_ms);
    }

    try stdout.flush();
}

fn process_sprites(options: CliOptions, allocator: std.mem.Allocator, io: Io, stdout: *Io.Writer) ![]u8 {
    var sprites: std.ArrayList([]u8) = .empty;
    defer {
        for (sprites.items) |sprite| allocator.free(sprite);
        sprites.deinit(allocator);
    }

    if (options.sprite_path) |sprite_path| {
        try process_sprite(sprite_path, &sprites, options, allocator, io, stdout);
    } else if (options.dir_path) |dir_path| {
        try process_directory(dir_path, &sprites, options, allocator, io, stdout);
    } else {
        return error.NoSpriteSpecified;
    }

    return try entropy.extract_entropy(sprites.items, allocator);
}

fn process_sprite(
    sprite_path: []const u8,
    sprites: *std.ArrayList([]u8),
    options: CliOptions,
    allocator: std.mem.Allocator,
    io: Io,
    stdout: *Io.Writer,
) !void {
    try stdout.print("\nProcessing sprite: {s}\n", .{sprite_path});

    try stdout.print("Loading image...", .{});
    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(allocator, io, sprite_path, read_buffer[0..]);
    defer image.deinit(allocator);
    try stdout.print(" Captured\n", .{});

    try stdout.print("Original dimensions: {d}x{d} pixels\n", .{ image.width, image.height });

    try image.convert(allocator, .rgba32);

    if (options.show_render) {
        try stdout.print("\nSprite preview:\n", .{});
        const rgba = image.pixels.rgba32;
        try render.render_rgba32(
            stdout,
            @as([]const render.Rgba32, @ptrCast(rgba)),
            image.width,
            image.height,
            options.render_width,
        );
    }

    try stdout.print("Normalizing to 64x64 and binarizing...\n", .{});
    const binary_matrix = try image_to_binary_matrix(&image, allocator, stdout);

    try sprites.append(allocator, binary_matrix);
    try stdout.print("SHA-256 entropy extracted\n", .{});
}

fn process_directory(
    dir_path: []const u8,
    sprites: *std.ArrayList([]u8),
    options: CliOptions,
    allocator: std.mem.Allocator,
    io: Io,
    stdout: *Io.Writer,
) !void {
    var dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);

    var iter = dir.iterate();
    var found_sprites = false;

    try stdout.print("\nScanning directory: {s}\n", .{dir_path});

    while (try iter.next(io)) |entry| {
        if (entry.kind == .file and is_supported_image(entry.name)) {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
            defer allocator.free(full_path);

            try process_sprite(full_path, sprites, options, allocator, io, stdout);
            found_sprites = true;
        }
    }

    if (!found_sprites) {
        try stdout.print("\nNo supported image files found in the directory.\n", .{});
        return error.NoSpritesFound;
    }
}

fn is_supported_image(filename: []const u8) bool {
    const extensions = [_][]const u8{ ".png", ".jpg", ".jpeg", ".bmp", ".gif" };
    for (extensions) |ext| {
        if (std.ascii.endsWithIgnoreCase(filename, ext)) return true;
    }
    return false;
}

fn image_to_binary_matrix(img: *zigimg.Image, allocator: std.mem.Allocator, stdout: *Io.Writer) ![]u8 {
    var matrix = try allocator.alloc(u8, TARGET_WIDTH * TARGET_HEIGHT);
    errdefer allocator.free(matrix);
    @memset(matrix, 0);

    const src_width = img.width;
    const src_height = img.height;

    const scale_x = @as(f32, @floatFromInt(src_width)) / @as(f32, @floatFromInt(TARGET_WIDTH));
    const scale_y = @as(f32, @floatFromInt(src_height)) / @as(f32, @floatFromInt(TARGET_HEIGHT));

    const threshold: u32 = 3 * 128;

    try stdout.print("   Scaling image...", .{});

    const rgba = img.pixels.rgba32;

    for (0..TARGET_HEIGHT) |y| {
        if (y % 16 == 0 and y > 0) {
            try stdout.print(" {d}%", .{(y * 100) / TARGET_HEIGHT});
        }

        for (0..TARGET_WIDTH) |x| {
            const src_x = @as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) * scale_x));
            const src_y = @as(usize, @intFromFloat(@as(f32, @floatFromInt(y)) * scale_y));

            if (src_x < src_width and src_y < src_height) {
                const pixel = rgba[src_x + src_y * src_width];
                const brightness = @as(u32, pixel.r) + @as(u32, pixel.g) + @as(u32, pixel.b);
                matrix[y * TARGET_WIDTH + x] = if (brightness > threshold) 1 else 0;
            }
        }
    }

    try stdout.print(" Completed\n", .{});

    var ones: usize = 0;
    for (matrix) |bit| {
        if (bit == 1) ones += 1;
    }

    const percentage_ones = @as(f32, @floatFromInt(ones)) / @as(f32, @floatFromInt(TARGET_WIDTH * TARGET_HEIGHT)) * 100.0;

    try stdout.print("   Matrix statistics:\n", .{});
    try stdout.print("      Dimensions: {d}x{d} ({d} pixels)\n", .{ TARGET_WIDTH, TARGET_HEIGHT, TARGET_WIDTH * TARGET_HEIGHT });
    try stdout.print("      Active bits: {d} ({d:.2}%)\n", .{ ones, percentage_ones });
    try stdout.print("      Inactive bits: {d} ({d:.2}%)\n", .{ TARGET_WIDTH * TARGET_HEIGHT - ones, 100.0 - percentage_ones });

    try stdout.print("\n   Entropy evaluation: ", .{});
    if (percentage_ones > 30.0 and percentage_ones < 70.0) {
        try stdout.print("Excellent\n", .{});
    } else if (percentage_ones > 15.0 and percentage_ones < 85.0) {
        try stdout.print("Very good\n", .{});
    } else {
        try stdout.print("Acceptable\n", .{});
    }

    return matrix;
}

fn create_password_policy(options: CliOptions) !password.PasswordPolicy {
    if (options.min_length > options.max_length) return error.InvalidLengthRange;

    var char_sets = password.CharacterSet{
        .uppercase = false,
        .lowercase = false,
        .numbers = false,
        .symbols = false,
    };

    if (std.mem.eql(u8, options.complexity, "minimal")) {
        char_sets.lowercase = true;
    } else if (std.mem.eql(u8, options.complexity, "basic")) {
        char_sets.lowercase = true;
        char_sets.numbers = true;
    } else if (std.mem.eql(u8, options.complexity, "medium")) {
        char_sets.lowercase = true;
        char_sets.uppercase = true;
        char_sets.numbers = true;
    } else if (std.mem.eql(u8, options.complexity, "high")) {
        char_sets.lowercase = true;
        char_sets.uppercase = true;
        char_sets.numbers = true;
        char_sets.symbols = true;
    } else if (std.mem.eql(u8, options.complexity, "custom") or std.mem.eql(u8, options.complexity, "normal")) {
        for (options.character_sets) |c| {
            switch (c) {
                'u' => char_sets.uppercase = true,
                'l' => char_sets.lowercase = true,
                'n' => char_sets.numbers = true,
                's' => char_sets.symbols = true,
                else => return error.InvalidCharacterSet,
            }
        }
    } else {
        return error.InvalidComplexity;
    }

    if (!char_sets.uppercase and !char_sets.lowercase and
        !char_sets.numbers and !char_sets.symbols)
    {
        return error.NoCharacterSetsSelected;
    }

    var length = options.password_length;
    if (length < options.min_length) length = options.min_length;
    if (length > options.max_length) length = options.max_length;

    return password.PasswordPolicy{
        .min_length = length,
        .character_set = char_sets,
    };
}

fn display_password(stdout: *Io.Writer, pwd: []const u8, options: CliOptions, execution_time_ms: i96) !void {
    if (options.show_preview) {
        try stdout.print("\nYour Pokémon password is ready!\n\n", .{});
        try stdout.print("Password: {s}\n", .{pwd});
        try stdout.print("Length: {d} characters\n", .{pwd.len});
        try print_generation_meta(stdout, options, execution_time_ms);

        const tips = [_][]const u8{
            "Your password is as strong as a Dragonite using Hyper Beam",
            "This password is super effective against brute force attacks!",
            "Your password is rarer than a Shiny Mewtwo",
            "Not even an Alakazam could guess this password",
            "This password has the defense of a Steelix and the speed of a Jolteon",
        };
        const tip_idx = pwd[0] % tips.len;
        try stdout.print("\nProfessor Oak's Tip: {s}\n\n", .{tips[tip_idx]});
    } else {
        try stdout.print("\nPassword successfully generated!\n", .{});
        try stdout.print("(To view the password, use the --preview option)\n", .{});
        try stdout.print("\nThe password has {d} characters\n", .{pwd.len});
        try print_generation_meta(stdout, options, execution_time_ms);
    }
}

fn display_passwords(stdout: *Io.Writer, passwords: []const []const u8, options: CliOptions, execution_time_ms: i96) !void {
    if (options.show_preview) {
        try stdout.print("\nYour Pokémon password options are ready!\n\n", .{});
        for (passwords, 0..) |pwd, i| {
            try stdout.print("  {d}. {s}\n", .{ i + 1, pwd });
        }
        try stdout.print("\nGenerated {d} passwords ({d} characters each)\n", .{ passwords.len, passwords[0].len });
        try print_generation_meta(stdout, options, execution_time_ms);
        try stdout.print("\n", .{});
    } else {
        try stdout.print("\n{d} passwords successfully generated!\n", .{passwords.len});
        try stdout.print("(To view them, use the --preview option)\n", .{});
        try print_generation_meta(stdout, options, execution_time_ms);
    }
}

fn print_generation_meta(stdout: *Io.Writer, options: CliOptions, execution_time_ms: i96) !void {
    try stdout.print("Generated in: {d} ms\n", .{execution_time_ms });
    if (options.randomize) {
        try stdout.print("Mode: Randomized (non-deterministic)\n", .{});
    } else {
        try stdout.print("Mode: Deterministic (same inputs = same password)\n", .{});
    }
    if (options.secret != null) {
        try stdout.print("Secret: Protected with HMAC-SHA256\n", .{});
    }
    if (options.password_count > 1) {
        try stdout.print("Count: {d} password options\n", .{options.password_count});
    }
}

fn parse_cli_options(args: []const []const u8) !CliOptions {
    if (args.len < 2) return CliOptions{};

    var options = CliOptions{};
    var i: usize = 1;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.show_help = true;
        } else if (std.mem.eql(u8, arg, "--preview") or std.mem.eql(u8, arg, "-p")) {
            options.show_preview = true;
        } else if (std.mem.eql(u8, arg, "--randomize") or std.mem.eql(u8, arg, "-r")) {
            options.randomize = true;
        } else if (std.mem.eql(u8, arg, "--render")) {
            options.show_render = true;
        } else if (std.mem.eql(u8, arg, "--no-render")) {
            options.show_render = false;
        } else if (std.mem.eql(u8, arg, "--sprite") or std.mem.eql(u8, arg, "-s")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.sprite_path = args[i];
        } else if (std.mem.eql(u8, arg, "--dir") or std.mem.eql(u8, arg, "-d")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.dir_path = args[i];
        } else if (std.mem.eql(u8, arg, "--length") or std.mem.eql(u8, arg, "-l")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.password_length = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--min-length")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.min_length = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--max-length")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.max_length = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--count") or std.mem.eql(u8, arg, "-n")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.password_count = try std.fmt.parseInt(usize, args[i], 10);
            if (options.password_count == 0 or options.password_count > MAX_PASSWORD_COUNT) {
                return error.InvalidCount;
            }
        } else if (std.mem.eql(u8, arg, "--secret")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.secret = args[i];
        } else if (std.mem.eql(u8, arg, "--render-width")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.render_width = try std.fmt.parseInt(usize, args[i], 10);
            if (options.render_width < 8 or options.render_width > 120) {
                return error.InvalidRenderWidth;
            }
        } else if (std.mem.eql(u8, arg, "--complexity")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.complexity = args[i];
            if (!std.mem.eql(u8, options.complexity, "minimal") and
                !std.mem.eql(u8, options.complexity, "basic") and
                !std.mem.eql(u8, options.complexity, "medium") and
                !std.mem.eql(u8, options.complexity, "high") and
                !std.mem.eql(u8, options.complexity, "custom") and
                !std.mem.eql(u8, options.complexity, "normal"))
            {
                return error.InvalidComplexity;
            }
        } else if (std.mem.eql(u8, arg, "--chars") or std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.character_sets = args[i];
            options.complexity = "custom";
        } else {
            return error.InvalidArgument;
        }
    }

    return options;
}

fn print_welcome_banner(stdout: *Io.Writer) !void {
    try stdout.print("\nPokePasswords\n", .{});
    try stdout.print("Password generator based on Pokémon sprites\n", .{});
    try stdout.print("--------------------------------------------------\n\n", .{});
}

fn print_usage(stdout: *Io.Writer) !void {
    try stdout.print(
        \\POKEPASSWORDS - TRAINER'S GUIDE
        \\
        \\Usage: pokepasswords [options]
        \\
        \\Options:
        \\  --sprite <file>        Select a sprite
        \\  --dir <directory>      Load sprites from directory
        \\  --length <n>           Password length (default: 16)
        \\  --min-length <n>       Minimum password length (default: 8)
        \\  --max-length <n>       Maximum password length (default: 32)
        \\  --count, -n <n>        Generate N password options (default: 1, max: 20)
        \\  --secret <phrase>      Private secret mixed via HMAC-SHA256
        \\  --render               Show sprite preview in terminal (no external tools)
        \\  --no-render            Disable sprite preview
        \\  --render-width <n>     Terminal preview width in columns (default: 48)
        \\  --complexity <level>   [minimal, basic, medium, high, normal, custom]
        \\  --chars <categories>   Character types (u/l/n/s)
        \\  --preview, -p          Show the generated password(s)
        \\  --randomize, -r        Non-deterministic generation
        \\  --help, -h             Show this message
        \\
        \\Examples:
        \\  pokepasswords --sprite pikachu.png --render --preview
        \\  pokepasswords --sprite pikachu.png --secret "my phrase" --preview
        \\  pokepasswords --sprite pikachu.png --count 5 --preview
        \\
    , .{});
}
