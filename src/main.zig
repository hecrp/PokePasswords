// main.zig
//
// Entry point of the application and CLI for generating passwords
// from Pokémon sprites.

const std = @import("std");
const Io = std.Io;
const entropy = @import("entropy");
const password = @import("password");
const zigimg = @import("zigimg");

// Constants for the binary matrix size
const TARGET_WIDTH: usize = 64;
const TARGET_HEIGHT: usize = 64;

// CLI options structure
const CliOptions = struct {
    sprite_path: ?[]const u8 = null,
    dir_path: ?[]const u8 = null,
    password_length: usize = 16,
    min_length: usize = 8,
    max_length: usize = 32,
    show_preview: bool = false,
    show_help: bool = false,
    randomize: bool = false,
    character_sets: []const u8 = "ulns",
    complexity: []const u8 = "normal",
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const start_ns = Io.Clock.awake.now(io).nanoseconds;

    var stdout_buffer: [4096]u8 = undefined;
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

    const entropy_data = try process_sprites(options, allocator, io, stdout);
    defer allocator.free(entropy_data);

    const policy = try create_password_policy(options);

    const pwd = try password.generate_password(entropy_data, policy, allocator, options.randomize, io);
    defer allocator.free(pwd);

    const end_ns = Io.Clock.awake.now(io).nanoseconds;
    const execution_time_ms = @divTrunc(end_ns - start_ns, std.time.ns_per_ms);

    try display_password(stdout, pwd, options.show_preview, execution_time_ms, options.randomize);
    try stdout.flush();
}

fn process_sprites(options: CliOptions, allocator: std.mem.Allocator, io: Io, stdout: *Io.Writer) ![]u8 {
    var sprites: std.ArrayList([]u8) = .empty;
    defer {
        for (sprites.items) |sprite| {
            allocator.free(sprite);
        }
        sprites.deinit(allocator);
    }

    if (options.sprite_path) |sprite_path| {
        try process_sprite(sprite_path, &sprites, allocator, io, stdout);
    } else if (options.dir_path) |dir_path| {
        try process_directory(dir_path, &sprites, allocator, io, stdout);
    } else {
        return error.NoSpriteSpecified;
    }

    return try entropy.extract_entropy(sprites.items, allocator);
}

fn process_sprite(
    sprite_path: []const u8,
    sprites: *std.ArrayList([]u8),
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

    // Ensure a consistent pixel format before reading bytes
    try image.convert(allocator, .rgba32);

    try stdout.print("Normalizing to 64x64 and binarizing...\n", .{});
    const binary_matrix = try image_to_binary_matrix(&image, allocator, stdout);

    try sprites.append(allocator, binary_matrix);
    try stdout.print("SHA-256 entropy extracted\n", .{});
}

fn process_directory(
    dir_path: []const u8,
    sprites: *std.ArrayList([]u8),
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

            try process_sprite(full_path, sprites, allocator, io, stdout);
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
    const lower = filename; // filenames from PokéSprite are already lowercase
    for (extensions) |ext| {
        if (std.ascii.endsWithIgnoreCase(lower, ext)) {
            return true;
        }
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

    // After convert(.rgba32), pixels are guaranteed to be rgba32
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
        try stdout.print("   \"This is a very balanced sprite with excellent bit distribution!\"\n", .{});
    } else if (percentage_ones > 15.0 and percentage_ones < 85.0) {
        try stdout.print("Very good\n", .{});
        try stdout.print("   \"This sprite has a good bit distribution for generating entropy.\"\n", .{});
    } else {
        try stdout.print("Acceptable\n", .{});
        try stdout.print("   \"This sprite has many or very few active bits, but will still generate a secure password.\"\n", .{});
    }

    return matrix;
}

fn create_password_policy(options: CliOptions) !password.PasswordPolicy {
    if (options.min_length > options.max_length) {
        return error.InvalidLengthRange;
    }

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
    if (length < options.min_length) {
        length = options.min_length;
    } else if (length > options.max_length) {
        length = options.max_length;
    }

    return password.PasswordPolicy{
        .min_length = length,
        .character_set = char_sets,
    };
}

fn display_password(stdout: *Io.Writer, pwd: []const u8, preview: bool, execution_time_ms: i96, randomize: bool) !void {
    if (preview) {
        try stdout.print("\nYour Pokémon password is ready!\n\n", .{});
        try stdout.print("Password: {s}\n", .{pwd});
        try stdout.print("Length: {d} characters\n", .{pwd.len});
        try stdout.print("Generated in: {d} ms\n", .{execution_time_ms});

        if (randomize) {
            try stdout.print("Mode: Randomized (non-deterministic)\n", .{});
        } else {
            try stdout.print("Mode: Deterministic (same sprite = same password)\n", .{});
        }

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
        try stdout.print("Generated in: {d} ms\n", .{execution_time_ms});
        if (randomize) {
            try stdout.print("Mode: Randomized (non-deterministic)\n", .{});
        }
    }
}

fn parse_cli_options(args: []const []const u8) !CliOptions {
    if (args.len < 2) {
        return CliOptions{};
    }

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
    try stdout.print("\nPOKEPASSWORDS - TRAINER'S GUIDE\n\n", .{});
    try stdout.print("Usage: pokepasswords [options]\n\n", .{});
    try stdout.print("Options:\n", .{});
    try stdout.print("  --sprite <file>        Select a sprite\n", .{});
    try stdout.print("  --dir <directory>      Load sprites from directory\n", .{});
    try stdout.print("  --length <n>           Password length (default: 16)\n", .{});
    try stdout.print("  --min-length <n>       Minimum password length (default: 8)\n", .{});
    try stdout.print("  --max-length <n>       Maximum password length (default: 32)\n", .{});
    try stdout.print("  --complexity <level>   Password complexity level\n", .{});
    try stdout.print("                         [minimal, basic, medium, high, normal, custom]\n", .{});
    try stdout.print("  --chars <categories>   Custom character types (u=upper, l=lower, n=numbers, s=symbols)\n", .{});
    try stdout.print("  --preview              Show the password\n", .{});
    try stdout.print("  --randomize, -r        Break deterministic generation using random seed\n", .{});
    try stdout.print("  --help                 Show this message\n\n", .{});
    try stdout.print("Complexity Levels:\n", .{});
    try stdout.print("  minimal    Lowercase letters only\n", .{});
    try stdout.print("  basic      Lowercase letters + numbers\n", .{});
    try stdout.print("  medium     Lowercase + uppercase + numbers\n", .{});
    try stdout.print("  high       All character sets (lowercase, uppercase, numbers, symbols)\n", .{});
    try stdout.print("  normal     Default behavior (all character sets)\n", .{});
    try stdout.print("  custom     Use character sets specified with --chars\n\n", .{});
    try stdout.print("Examples:\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --length 16\n", .{});
    try stdout.print("  pokepasswords --dir sprites/ --preview\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --complexity medium\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --chars ln --length 12\n\n", .{});
}
