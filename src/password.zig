// password.zig
//
// This file contains functions to generate secure passwords
// using the seed derived from Pokémon sprites.

const std = @import("std");

// Definition of character sets for passwords
pub const CharacterSet = struct {
    uppercase: bool = true, // A-Z
    lowercase: bool = true, // a-z
    numbers: bool = true, // 0-9
    symbols: bool = true, // !@#$%^&*()_+-=[]{}|;:,.<>?

    // Predefined character strings for each set
    const UPPERCASE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const LOWERCASE = "abcdefghijklmnopqrstuvwxyz";
    const NUMBERS = "0123456789";
    const SYMBOLS = "!@#$%^&*()_+-=[]{}|;:,.<>?";

    // Function to get all valid characters according to the configuration
    pub fn getValidChars(self: CharacterSet, allocator: std.mem.Allocator) ![]u8 {
        // Calculate the total length needed
        var total_length: usize = 0;
        if (self.uppercase) total_length += UPPERCASE.len;
        if (self.lowercase) total_length += LOWERCASE.len;
        if (self.numbers) total_length += NUMBERS.len;
        if (self.symbols) total_length += SYMBOLS.len;

        // Verify that at least one set is enabled
        if (total_length == 0) {
            return error.NoCharacterSetsEnabled;
        }

        // Create buffer for all characters
        var result = try allocator.alloc(u8, total_length);
        var index: usize = 0;

        // Add characters from each enabled set
        if (self.uppercase) {
            @memcpy(result[index..][0..UPPERCASE.len], UPPERCASE);
            index += UPPERCASE.len;
        }

        if (self.lowercase) {
            @memcpy(result[index..][0..LOWERCASE.len], LOWERCASE);
            index += LOWERCASE.len;
        }

        if (self.numbers) {
            @memcpy(result[index..][0..NUMBERS.len], NUMBERS);
            index += NUMBERS.len;
        }

        if (self.symbols) {
            @memcpy(result[index..][0..SYMBOLS.len], SYMBOLS);
            index += SYMBOLS.len;
        }

        return result;
    }
};

// Definition of password policies
pub const PasswordPolicy = struct {
    min_length: usize = 12,
    character_set: CharacterSet = CharacterSet{},

    // Function to validate if a password meets the policy
    pub fn validatePassword(self: PasswordPolicy, password: []const u8) bool {
        // Check minimum length
        if (password.len < self.min_length) {
            return false;
        }

        // Check that it includes at least one character from each activated set
        var has_uppercase = !self.character_set.uppercase;
        var has_lowercase = !self.character_set.lowercase;
        var has_number = !self.character_set.numbers;
        var has_symbol = !self.character_set.symbols;

        for (password) |char| {
            // Check if the character is an uppercase letter
            if (self.character_set.uppercase and !has_uppercase) {
                has_uppercase = (char >= 'A' and char <= 'Z');
            }

            // Check if the character is a lowercase letter
            if (self.character_set.lowercase and !has_lowercase) {
                has_lowercase = (char >= 'a' and char <= 'z');
            }

            // Check if the character is a number
            if (self.character_set.numbers and !has_number) {
                has_number = (char >= '0' and char <= '9');
            }

            // Check if the character is a symbol
            if (self.character_set.symbols and !has_symbol) {
                has_symbol = std.mem.indexOfScalar(u8, CharacterSet.SYMBOLS, char) != null;
            }

            // If all required sets are present, the password is valid
            if (has_uppercase and has_lowercase and has_number and has_symbol) {
                return true;
            }
        }

        // If we get here, at least one required character type is missing
        return has_uppercase and has_lowercase and has_number and has_symbol;
    }
};

// Function to generate a password using the Xoshiro256++ algorithm
// Input: seed derived from sprites and password policy
// Output: generated password
pub fn generatePassword(seed: []const u8, policy: PasswordPolicy, allocator: std.mem.Allocator, randomize: bool) ![]u8 {
    // Get valid characters according to the policy
    const valid_chars = try policy.character_set.getValidChars(allocator);
    defer allocator.free(valid_chars);

    // Create buffer for the password with the minimum length
    var password = try allocator.alloc(u8, policy.min_length);

    // Initialize the random generator with the seed or with a random seed if randomize is true
    var prng = if (randomize) initPrngWithRandomSeed() else initPrngFromSeed(seed);
    var random = prng.random();

    // Generate a random password
    for (0..policy.min_length) |i| {
        // Select a random character from the valid set
        const index = random.intRangeLessThan(usize, 0, valid_chars.len);
        password[i] = valid_chars[index];
    }

    // Verify that the password meets the policy
    // If not, regenerate until it does
    var attempts: usize = 0;
    const max_attempts = 100;

    while (!policy.validatePassword(password)) {
        // Generate a new password
        for (0..policy.min_length) |i| {
            const index = random.intRangeLessThan(usize, 0, valid_chars.len);
            password[i] = valid_chars[index];
        }

        attempts += 1;
        if (attempts >= max_attempts) {
            // If we can't generate a valid password after several attempts,
            // it means there's probably a problem with the policy
            return error.CouldNotGenerateValidPassword;
        }
    }

    return password;
}

// Function to generate multiple passwords using the same seed
// Useful when the user wants several password options
// Input: seed, policy, and number of passwords
// Output: list of generated passwords
pub fn generateMultiplePasswords(seed: []const u8, policy: PasswordPolicy, count: usize, allocator: std.mem.Allocator, randomize: bool) ![][]u8 {
    // Create array to store passwords
    var passwords = try allocator.alloc([]u8, count);

    // Variable to track errors and clean up memory in case of failure
    var success_count: usize = 0;
    errdefer {
        for (0..success_count) |i| {
            allocator.free(passwords[i]);
        }
        allocator.free(passwords);
    }

    // Generate 'count' different passwords
    for (0..count) |i| {
        // For each generated password, we use a slightly different seed
        // derived from the original seed plus the index
        var modified_seed = try allocator.alloc(u8, seed.len + 8);
        defer allocator.free(modified_seed);

        @memcpy(modified_seed[0..seed.len], seed);
        std.mem.writeIntLittle(u64, modified_seed[seed.len..][0..8], i);

        // Generate the password with the modified seed
        passwords[i] = try generatePassword(modified_seed, policy, allocator, randomize);
        success_count += 1;
    }

    return passwords;
}

// Helper function to initialize a PRNG from a seed
fn initPrngFromSeed(seed: []const u8) std.Random.DefaultPrng {
    // We use Xoshiro256 as a pseudorandom generator
    var seed_int: u64 = 0;

    // Convert the hash to an integer for the seed
    // If the hash is shorter than 8 bytes, we pad with zeros
    // If it's longer, we take only the first 8 bytes
    if (seed.len >= 8) {
        seed_int = @as(u64, seed[0]) |
            (@as(u64, seed[1]) << 8) |
            (@as(u64, seed[2]) << 16) |
            (@as(u64, seed[3]) << 24) |
            (@as(u64, seed[4]) << 32) |
            (@as(u64, seed[5]) << 40) |
            (@as(u64, seed[6]) << 48) |
            (@as(u64, seed[7]) << 56);
    } else {
        var temp_buffer: [8]u8 = [_]u8{0} ** 8;
        @memcpy(temp_buffer[0..seed.len], seed);
        seed_int = @as(u64, temp_buffer[0]) |
            (@as(u64, temp_buffer[1]) << 8) |
            (@as(u64, temp_buffer[2]) << 16) |
            (@as(u64, temp_buffer[3]) << 24) |
            (@as(u64, temp_buffer[4]) << 32) |
            (@as(u64, temp_buffer[5]) << 40) |
            (@as(u64, temp_buffer[6]) << 48) |
            (@as(u64, temp_buffer[7]) << 56);
    }

    return std.Random.DefaultPrng.init(seed_int);
}

// Helper function to initialize a PRNG with a true random seed
fn initPrngWithRandomSeed() std.Random.DefaultPrng {
    // Get a secure random seed from the system
    var seed_int: u64 = undefined;
    std.crypto.random.bytes(std.mem.asBytes(&seed_int));

    return std.Random.DefaultPrng.init(seed_int);
}
