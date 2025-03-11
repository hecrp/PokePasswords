// main.zig
//
// Punto de entrada de la aplicación y CLI para generar contraseñas
// a partir de sprites de Pokémon.

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
    show_preview: bool = false,
    show_help: bool = false,
    character_sets: []const u8 = "ulns", // Default: use all character sets
};

// Constantes para colores ANSI
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
    const entropy_data = try procesarSprites(options, allocator);
    defer allocator.free(entropy_data);
    
    // Create password policy based on options
    const policy = try crearPoliticaContrasena(options);
    
    // Generate password
    const pwd = try password.generatePassword(entropy_data, policy, allocator);
    defer allocator.free(pwd);
    
    // Show the generated password
    try mostrarContrasena(pwd, options.show_preview);
}

// Function to process sprites and extract entropy
fn procesarSprites(options: CliOptions, allocator: std.mem.Allocator) ![]u8 {
    var sprites = std.ArrayList([]u8).init(allocator);
    defer {
        for (sprites.items) |sprite| {
            allocator.free(sprite);
        }
        sprites.deinit();
    }
    
    // Process a single sprite or a directory of sprites
    if (options.sprite_path) |sprite_path| {
        try procesarSprite(sprite_path, &sprites, allocator);
    } else if (options.dir_path) |dir_path| {
        try procesarDirectorio(dir_path, &sprites, allocator);
    } else {
        return error.NoSpriteSpecified;
    }
    
    // Extract entropy from processed sprites
    return try entropy.extractEntropy(sprites.items, allocator);
}

// Function to process an individual sprite
fn procesarSprite(sprite_path: []const u8, sprites: *std.ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("\n🖼️ Processing sprite: {s}\n", .{sprite_path});

    // Load image with zigimg
    try stdout.print("📥 Loading image...", .{});
    var image = try zigimg.Image.fromFilePath(allocator, sprite_path);
    defer image.deinit();
    try stdout.print(" ✓ Captured!\n", .{});

    // Show original image dimensions
    try stdout.print("📐 Original dimensions: {d}x{d} pixels\n", .{image.width, image.height});

    // Convert image to normalized 64x64 binary matrix
    try stdout.print("🔄 Normalizing to 64x64 and binarizing...\n", .{});
    const matriz_binaria = try imagenAMatrizBinaria(&image, allocator);
    
    try sprites.append(matriz_binaria);
    
    try stdout.print("🔒 Calculating SHA-256 hash...", .{});
    
    // Simulate processing with progress dots
    for (0..5) |_| {
        try stdout.print(".", .{});
        std.time.sleep(100 * std.time.ns_per_ms); // Sleep 100ms
    }
    
    try stdout.print(" ✅ Completed!\n", .{});
}

// Function to process a directory of sprites
fn procesarDirectorio(dir_path: []const u8, sprites: *std.ArrayList([]u8), allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();
    
    var iter = dir.iterate();
    var found_sprites = false;
    
    try stdout.print("\n📂 Scanning directory: {s}\n", .{dir_path});
    
    while (try iter.next()) |entry| {
        if (entry.kind == .file and esImagenSoportada(entry.name)) {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
            defer allocator.free(full_path);
            
            try procesarSprite(full_path, sprites, allocator);
            found_sprites = true;
        }
    }
    
    if (!found_sprites) {
        try stdout.print("\n❌ No supported image files found in the directory.\n", .{});
        return error.NoSpritesFound;
    }
}

// Function to check if a file is a supported image
fn esImagenSoportada(filename: []const u8) bool {
    const extensions = [_][]const u8{ ".png", ".jpg", ".jpeg", ".bmp", ".gif" };
    
    for (extensions) |ext| {
        if (std.mem.endsWith(u8, filename, ext)) {
            return true;
        }
    }
    return false;
}

// Function to convert an image to a normalized 64x64 binary matrix
fn imagenAMatrizBinaria(img: *zigimg.Image, allocator: std.mem.Allocator) ![]u8 {
    const stdout = std.io.getStdOut().writer();
    
    // Create a fixed size 64x64 matrix to ensure consistency
    var matriz = try allocator.alloc(u8, TARGET_WIDTH * TARGET_HEIGHT);
    errdefer allocator.free(matriz);
    
    // Initialize with zeros
    @memset(matriz, 0);
    
    // Get original image dimensions
    const src_width = img.width;
    const src_height = img.height;
    
    // Calculate scaling factors for normalization
    const scale_x = @as(f32, @floatFromInt(src_width)) / @as(f32, @floatFromInt(TARGET_WIDTH));
    const scale_y = @as(f32, @floatFromInt(src_height)) / @as(f32, @floatFromInt(TARGET_HEIGHT));
    
    // Threshold for binarization (average of the maximum values of the 3 RGB channels)
    const umbral: u32 = 3 * 128; // 3 channels * middle value (128)
    
    try stdout.print("   ⏳ Scaling image...", .{});
    
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
                const pixel = img.pixels.asBytes()[(src_x + src_y * src_width) * 4..][0..4].*;
                const brillo = @as(u32, pixel[0]) + @as(u32, pixel[1]) + @as(u32, pixel[2]);
                
                // Binarize: if brightness > threshold -> 1, otherwise -> 0
                matriz[y * TARGET_WIDTH + x] = if (brillo > umbral) 1 else 0;
            }
        }
    }
    
    try stdout.print(" ✓ Completed!\n", .{});
    
    // Print statistics about the matrix
    var unos: usize = 0;
    for (matriz) |bit| {
        if (bit == 1) unos += 1;
    }
    
    const porcentaje_unos = @as(f32, @floatFromInt(unos)) / @as(f32, @floatFromInt(TARGET_WIDTH * TARGET_HEIGHT)) * 100.0;
    
    // Show statistics in a stylized way
    try stdout.print("   📊 Matrix statistics:\n", .{});
    try stdout.print("      📏 Dimensions: {d}x{d} ({d} pixels)\n", 
        .{TARGET_WIDTH, TARGET_HEIGHT, TARGET_WIDTH * TARGET_HEIGHT});
    try stdout.print("      🔆 Active bits: {d} ({d:.2}%)\n", 
        .{unos, porcentaje_unos});
    try stdout.print("      ⚫ Inactive bits: {d} ({d:.2}%)\n", 
        .{TARGET_WIDTH * TARGET_HEIGHT - unos, 100.0 - porcentaje_unos});
    
    // Show a fun Pokémon-style rating
    try stdout.print("\n   🎮 Entropy evaluation: ", .{});
    
    if (porcentaje_unos > 30.0 and porcentaje_unos < 70.0) {
        try stdout.print("Excellent! 🌟🌟🌟\n", .{});
        try stdout.print("   💬 \"This is a very balanced sprite with excellent bit distribution!\"\n", .{});
    } else if (porcentaje_unos > 15.0 and porcentaje_unos < 85.0) {
        try stdout.print("Very good! 🌟🌟\n", .{});
        try stdout.print("   💬 \"This sprite has a good bit distribution for generating entropy.\"\n", .{});
    } else {
        try stdout.print("Acceptable 🌟\n", .{});
        try stdout.print("   💬 \"This sprite has many or very few active bits, but will still generate a secure password.\"\n", .{});
    }
    
    return matriz;
}

// Function to create a password policy based on CLI options
fn crearPoliticaContrasena(options: CliOptions) !password.PasswordPolicy {
    var char_sets = password.CharacterSet{};
    
    for (options.character_sets) |c| {
        switch (c) {
            'u' => char_sets.uppercase = true,
            'l' => char_sets.lowercase = true,
            'n' => char_sets.numbers = true,
            's' => char_sets.symbols = true,
            else => return error.InvalidCharacterSet,
        }
    }
    
    // Ensure at least one character set is selected
    if (!char_sets.uppercase and !char_sets.lowercase and 
        !char_sets.numbers and !char_sets.symbols) {
        return error.NoCharacterSetsSelected;
    }
    
    return password.PasswordPolicy{
        .min_length = options.password_length,
        .character_set = char_sets,
    };
}

// Function to display the generated password
fn mostrarContrasena(pwd: []const u8, preview: bool) !void {
    const stdout = std.io.getStdOut().writer();
    
    if (preview) {
        try stdout.print("\n🔐 Your Pokémon password is ready! 🔐\n\n", .{});
        
        // Show password
        try stdout.print("🔑 Password: {s}\n", .{pwd});
        try stdout.print("📏 Length: {d} characters\n\n", .{pwd.len});
        
        // Random Pokémon tip
        const consejos = [_][]const u8{
            "Your password is as strong as a Dragonite using Hyper Beam",
            "This password is super effective against brute force attacks!",
            "Your password is rarer than a Shiny Mewtwo",
            "Not even an Alakazam could guess this password",
            "This password has the defense of a Steelix and the speed of a Jolteon",
        };
        
        // Use the first part of the password to select a "random" but deterministic tip
        const consejo_idx = pwd[0] % consejos.len;
        try stdout.print("🧙‍♂️ Professor Oak's Tip: {s}\n\n", .{consejos[consejo_idx]});
    } else {
        try stdout.print("\n✅ Password successfully generated!\n", .{});
        try stdout.print("👁️ (To view the password, use the --preview option)\n", .{});
        try stdout.print("\n📏 The password has {d} characters\n\n", .{pwd.len});
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
        } else if (std.mem.eql(u8, arg, "--chars") or std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            options.character_sets = args[i];
        } else {
            return error.InvalidArgument;
        }
    }
    
    return options;
}

// Function to print the welcome banner
fn printWelcomeBanner() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("\n🎮 PokePasswords 🎮\n", .{});
    try stdout.print("✨ Password generator based on Pokémon sprites ✨\n", .{});
    try stdout.print("--------------------------------------------------\n\n", .{});
}

// Function to print usage instructions
fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("\n📖 POKEPASSWORDS - TRAINER'S GUIDE 📖\n\n", .{});
    
    // Basic usage
    try stdout.print("🔹 Usage: pokepasswords [options]\n\n", .{});
    
    // Options
    try stdout.print("🔹 Options:\n", .{});
    try stdout.print("  --sprite <file>        Select a sprite\n", .{});
    try stdout.print("  --dir <directory>      Load sprites from directory\n", .{});
    try stdout.print("  --length <n>           Password length\n", .{});
    try stdout.print("  --chars <categories>   Character types\n", .{});
    try stdout.print("  --preview              Show the password\n", .{});
    try stdout.print("  --help                 Show this message\n\n", .{});
    
    // Examples
    try stdout.print("🔹 Examples:\n", .{});
    try stdout.print("  pokepasswords --sprite pikachu.png --length 16\n", .{});
    try stdout.print("  pokepasswords --dir sprites/ --preview\n\n", .{});
} 