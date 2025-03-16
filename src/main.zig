// main.zig
//
// Entry point of the application and CLI for generating passwords
// from Pokémon sprites.

const std = @import("std");
const entropy = @import("entropy.zig");
const password = @import("password.zig");
const zigimg = @import("zigimg");

// Constants for the binary matrix size
const TARGET_WIDTH: usize = 64;
const TARGET_HEIGHT: usize = 64;

// CLI options structure
const CliOptions = struct {
    sprite_path: ?[]const u8 = null,
    dir_path: ?[]const u8 = null,
    password_length: usize = 16,
    min_length: usize = 8, // New: minimum password length
    max_length: usize = 32, // New: maximum password length
    show_preview: bool = false,
    show_help: bool = false,
    randomize: bool = false, // New: option to randomize seed
    character_sets: []const u8 = "ulns", // Default: use all character sets
    complexity: []const u8 = "normal", // New: predefined complexity level
};

// Constants for ANSI colors
const ANSI_RED = "\x1b[31m";
const ANSI_GREEN = "\x1b[32m";
const ANSI_YELLOW = "\x1b[33m";
const ANSI_BLUE = "\x1b[34m";
const ANSI_MAGENTA = "\x1b[35m";
const ANSI_CYAN = "\x1b[36m";
const ANSI_WHITE = "\x1b[37m";
const ANSI_BRIGHT_RED = "\x1b[91m";
const ANSI_BRIGHT_GREEN = "\x1b[92m";
const ANSI_BRIGHT_YELLOW = "\x1b[93m";
const ANSI_BRIGHT_BLUE = "\x1b[94m";
const ANSI_BRIGHT_MAGENTA = "\x1b[95m";
const ANSI_BRIGHT_CYAN = "\x1b[96m";
const ANSI_BRIGHT_WHITE = "\x1b[97m";
const ANSI_BOLD = "\x1b[1m";
const ANSI_RESET = "\x1b[0m";

pub fn main() !void {
    // Start timing the execution
    const start_time = std.time.milliTimestamp();

    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse CLI options
    const options = parseCliOptions(args) catch |err| {
        if (err == error.InvalidArgument or err == error.MissingValue) {
            try printUsage();
            return;
        }
        return err;
    };

    // Show help if requested
    if (options.show_help) {
        try printUsage();
        return;
    }

    // Show welcome banner
    try printWelcomeBanner();

    // Process sprites and generate password
    const entropy_data = try processSprites(options, allocator);
    defer allocator.free(entropy_data);

    // Create password policy based on options
    const policy = try createPasswordPolicy(options);

    // Generate password
    const pwd = try password.generatePassword(entropy_data, policy, allocator, options.randomize);
    defer allocator.free(pwd);

    // Calculate execution time
    const end_time = std.time.milliTimestamp();
    const execution_time_ms = end_time - start_time;

    // Show the generated password
    try displayPassword(pwd, options.show_preview, execution_time_ms, options.randomize);
}

// Function to process sprites and extract entropy
fn processSprites(options: CliOptions, allocator: std.mem.Allocator) ![]u8 {
    var sprites = std.ArrayList([]u8).init(allocator);
    defer {
        for (sprites.items) |sprite| {
            allocator.free(sprite);
        }
        sprites.deinit();
    }

    // Process a single sprite or a directory of sprites
    if (options.sprite_path) |sprite_path| {
        try processSprite(sprite_path, &sprites, allocator);
    } else if (options.dir_path) |dir_path| {
        try processDirectory(dir_path, &sprites, allocator);
    } else {
        return error.NoSpriteSpecified;
    }

    // Extract entropy from processed sprites
    return try entropy.extractEntropy(sprites.items, allocator);
}

// Function to process an individual sprite
fn processSprite(sprite_path: []const u8, sprites: *std.ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\nProcessing sprite: {s}\n", .{sprite_path});

    // Load image with zigimg
    try stdout.print("Loading image...", .{});
    var image = try zigimg.Image.fromFilePath(allocator, sprite_path);
    defer image.deinit();
    try stdout.print(" Captured\n", .{});

    // Show original image dimensions
    try stdout.print("Original dimensions: {d}x{d} pixels\n", .{ image.width, image.height });

    // Convert image to normalized 64x64 binary matrix
    try stdout.print("Normalizing to 64x64 and binarizing...\n", .{});
    const binary_matrix = try imageToBinaryMatrix(&image, allocator);

    try sprites.append(binary_matrix);

    try stdout.print("Calculating SHA-256 hash...", .{});

    // Simulate processing with progress dots
    for (0..5) |_| {
        try stdout.print(".", .{});
        std.time.sleep(100 * std.time.ns_per_ms); // Sleep 100ms
    }

    try stdout.print(" Completed\n", .{});
}

// Function to process a directory of sprites
fn processDirectory(dir_path: []const u8, sprites: *std.ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    var found_sprites = false;

    try stdout.print("\nScanning directory: {s}\n", .{dir_path});

    while (try iter.next()) |entry| {
        if (entry.kind == .file and isSupportedImage(entry.name)) {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
            defer allocator.free(full_path);

            try processSprite(full_path, sprites, allocator);
            found_sprites = true;
        }
    }

    if (!found_sprites) {
        try stdout.print("\nNo supported image files found in the directory.\n", .{});
        return error.NoSpritesFound;
    }
}

// Function to check if a file is a supported image
fn isSupportedImage(filename: []const u8) bool {
    const extensions = [_][]const u8{ ".png", ".jpg", ".jpeg", ".bmp", ".gif" };

    for (extensions) |ext| {
        if (std.mem.endsWith(u8, filename, ext)) {
            return true;
        }
    }
    return false;
}

// Function to convert an image to a normalized 64x64 binary matrix
fn imageToBinaryMatrix(img: *zigimg.Image, allocator: std.mem.Allocator) ![]u8 {
    const stdout = std.io.getStdOut().writer();

    // Create a fixed size 64x64 matrix to ensure consistency
    var matrix = try allocator.alloc(u8, TARGET_WIDTH * TARGET_HEIGHT);
    errdefer allocator.free(matrix);

    // Initialize with zeros
    @memset(matrix, 0);

    // Get original image dimensions
    const src_width = img.width;
    const src_height = img.height;

    // Calculate scaling factors for normalization
    const scale_x = @as(f32, @floatFromInt(src_width)) / @as(f32, @floatFromInt(TARGET_WIDTH));
    const scale_y = @as(f32, @floatFromInt(src_height)) / @as(f32, @floatFromInt(TARGET_HEIGHT));

    // Threshold for binarization (average of the maximum values of the 3 RGB channels)
    const threshold: u32 = 3 * 128; // 3 channels * middle value (128)

    try stdout.print("   Scaling image...", .{});

    // Perform scaling and binarization
    for (0..TARGET_HEIGHT) |y| {
        // Show progress every 16 lines
        if (y % 16 == 0 and y > 0) {
            try stdout.print(" {d}%", .{(y * 100) / TARGET_HEIGHT});
        }

        for (0..TARGET_WIDTH) |x| {
            // Calculate coordinates in the original image
            const src_x = @as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) * scale_x));
            const src_y = @as(usize, @intFromFloat(@as(f32, @floatFromInt(y)) * scale_y));

            // Get pixel and calculate brightness
            if (src_x < src_width and src_y < src_height) {
                const pixel = img.pixels.asBytes()[(src_x + src_y * src_width) * 4 ..][0..4].*;
                const brightness = @as(u32, pixel[0]) + @as(u32, pixel[1]) + @as(u32, pixel[2]);

                // Binarize: if brightness > threshold -> 1, otherwise -> 0
                matrix[y * TARGET_WIDTH + x] = if (brightness > threshold) 1 else 0;
            }
        }
    }

    try stdout.print(" Completed\n", .{});

    // Print statistics about the matrix
    var ones: usize = 0;
    for (matrix) |bit| {
        if (bit == 1) ones += 1;
    }

    const percentage_ones = @as(f32, @floatFromInt(ones)) / @as(f32, @floatFromInt(TARGET_WIDTH * TARGET_HEIGHT)) * 100.0;

    // Show statistics
    try stdout.print("   Matrix statistics:\n", .{});
    try stdout.print("      Dimensions: {d}x{d} ({d} pixels)\n", .{ TARGET_WIDTH, TARGET_HEIGHT, TARGET_WIDTH * TARGET_HEIGHT });
    try stdout.print("      Active bits: {d} ({d:.2}%)\n", .{ ones, percentage_ones });
    try stdout.print("      Inactive bits: {d} ({d:.2}%)\n", .{ TARGET_WIDTH * TARGET_HEIGHT - ones, 100.0 - percentage_ones });

    // Show entropy evaluation
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

// Function to create a password policy based on CLI options
fn createPasswordPolicy(options: CliOptions) !password.PasswordPolicy {
    // Initialize all sets explicitly as false
    var char_sets = password.CharacterSet{
        .uppercase = false,
        .lowercase = false,
        .numbers = false,
        .symbols = false,
    };

    // Process predefined complexity parameter
    if (std.mem.eql(u8, options.complexity, "minimal")) {
        // Minimal: only lowercase letters
        char_sets.lowercase = true;
    } else if (std.mem.eql(u8, options.complexity, "basic")) {
        // Basic: lowercase letters + numbers
        char_sets.lowercase = true;
        char_sets.numbers = true;
    } else if (std.mem.eql(u8, options.complexity, "medium")) {
        // Medium: lowercase + uppercase + numbers
        char_sets.lowercase = true;
        char_sets.uppercase = true;
        char_sets.numbers = true;
    } else if (std.mem.eql(u8, options.complexity, "high")) {
        // High: all character sets
        char_sets.lowercase = true;
        char_sets.uppercase = true;
        char_sets.numbers = true;
        char_sets.symbols = true;
    } else if (std.mem.eql(u8, options.complexity, "custom")) {
        // Custom: use character sets specified in character_sets
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
        // Normal (default behavior): use character sets specified in character_sets
        for (options.character_sets) |c| {
            switch (c) {
                'u' => char_sets.uppercase = true,
                'l' => char_sets.lowercase = true,
                'n' => char_sets.numbers = true,
                's' => char_sets.symbols = true,
                else => return error.InvalidCharacterSet,
            }
        }
    }

    // Ensure at least one character set is selected
    if (!char_sets.uppercase and !char_sets.lowercase and
        !char_sets.numbers and !char_sets.symbols)
    {
        return error.NoCharacterSetsSelected;
    }

    // Verify that the length is within limits
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

// Function to display the generated password
fn displayPassword(pwd: []const u8, preview: bool, execution_time_ms: i64, randomize: bool) !void {
    const stdout = std.io.getStdOut().writer();

    if (preview) {
        try stdout.print("\nYour Pokémon password is ready!\n\n", .{});

        // Show password
        try stdout.print("Password: {s}\n", .{pwd});
        try stdout.print("Length: {d} characters\n", .{pwd.len});
        try stdout.print("Generated in: {d} ms\n", .{execution_time_ms});

        // Show if randomize mode was used
        if (randomize) {
            try stdout.print("Mode: Randomized (non-deterministic)\n", .{});
        } else {
            try stdout.print("Mode: Deterministic (same sprite = same password)\n", .{});
        }

        // Random Pokémon tip
        const tips = [_][]const u8{
            "Your password is as strong as a Dragonite using Hyper Beam",
            "This password is super effective against brute force attacks!",
            "Your password is rarer than a Shiny Mewtwo",
            "Not even an Alakazam could guess this password",
            "This password has the defense of a Steelix and the speed of a Jolteon",
        };

        // Use the first part of the password to select a "random" but deterministic tip
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

// Function to parse command line options
fn parseCliOptions(args: []const []const u8) !CliOptions {
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
            // Validate that it's an accepted value
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
            // If custom character sets are specified, set complexity to 'custom'
            options.complexity = "custom";
        } else {
            return error.InvalidArgument;
        }
    }

    return options;
}

// Function to print the welcome banner
fn printWelcomeBanner() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\nPokePasswords\n", .{});
    try stdout.print("Password generator based on Pokémon sprites\n", .{});
    try stdout.print("--------------------------------------------------\n\n", .{});
}

// Function to print usage instructions
fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\nPOKEPASSWORDS - TRAINER'S GUIDE\n\n", .{});

    // Basic usage
    try stdout.print("Usage: pokepasswords [options]\n\n", .{});

    // Options
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

    // Complexity levels explanation
    try stdout.print("Complexity Levels:\n", .{});
    try stdout.print("  minimal    Lowercase letters only\n", .{});
    try stdout.print("  basic      Lowercase letters + numbers\n", .{});
    try stdout.print("  medium     Lowercase + uppercase + numbers\n", .{});
    try stdout.print("  high       All character sets (lowercase, uppercase, numbers, symbols)\n", .{});
    try stdout.print("  normal     Default behavior (all character sets)\n", .{});
    try stdout.print("  custom     Use character sets specified with --chars\n\n", .{});

    // Examples
    try stdout.print("Examples:\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --length 16\n", .{});
    try stdout.print("  pokepasswords --dir sprites/ --preview\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --complexity medium\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --chars ln --length 12\n\n", .{});
}
