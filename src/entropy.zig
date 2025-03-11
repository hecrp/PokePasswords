// entropy.zig
//
// This file contains functions to convert Pokémon sprites into seeds
// for password generation.

const std = @import("std");

// Function to convert a sprite matrix to data using SHA-256
// Takes a binary matrix (0/1) and produces a SHA-256 hash as a result
// Input: 64x64 pixel binary matrix
// Output: SHA-256 hash (32 bytes)
pub fn spriteToHash(sprite: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Create a hash context for SHA-256
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    
    // Update the hash with sprite data
    hash.update(sprite);
    
    // Create buffer to store the hash
    var hash_result: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    
    // Finalize the hash calculation
    hash.final(&hash_result);
    
    // Copy the result to a buffer allocated in dynamic memory
    const result = try allocator.alloc(u8, hash_result.len);
    @memcpy(result, &hash_result);
    
    return result;
}

// Function to combine multiple hashes using bitwise XOR
// Takes several SHA-256 hashes and combines them using XOR
// Input: list of SHA-256 hashes
// Output: a single combined hash
pub fn combineHashes(hashes: []const []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Verify that there is at least one hash
    if (hashes.len == 0) {
        return error.NoHashes;
    }
    
    // Determine the hash length (we take the length of the first hash)
    const hash_length = hashes[0].len;
    
    // Verify that all hashes have the same length
    for (hashes) |hash| {
        if (hash.len != hash_length) {
            return error.InconsistentHashLength;
        }
    }
    
    // Create buffer for the result
    var result = try allocator.alloc(u8, hash_length);
    
    // Initialize the result with the first hash
    @memcpy(result, hashes[0]);
    
    // Apply XOR with the other hashes
    for (hashes[1..]) |hash| {
        for (0..hash_length) |i| {
            result[i] ^= hash[i];
        }
    }
    
    return result;
}

// Function to apply a second layer of hashing to the combined result
// Takes a combined hash and applies SHA-256 again
// Input: combined hash
// Output: final hash with optimal distribution
pub fn finalizeHash(combined_hash: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Simply apply SHA-256 to the combined hash
    return spriteToHash(combined_hash, allocator);
}

// Main function that processes one or more sprites and returns a final hash
// This function orchestrates the entire entropy extraction process
// Input: list of sprites (as file paths or binary matrices)
// Output: final hash to use as PRNG seed
pub fn extractEntropy(sprites: []const []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Verify that there is at least one sprite
    if (sprites.len == 0) {
        return error.NoSprites;
    }
    
    // Array to store the hashes of each sprite
    var sprite_hashes = try allocator.alloc([]u8, sprites.len);
    defer {
        // Free memory of each individual hash
        for (sprite_hashes) |hash| {
            if (hash.len > 0) {
                allocator.free(hash);
            }
        }
        // Free the array itself
        allocator.free(sprite_hashes);
    }
    
    // Calculate hash for each sprite
    for (sprites, 0..) |sprite, i| {
        sprite_hashes[i] = try spriteToHash(sprite, allocator);
    }
    
    // Create an array of constant slices for combineHashes
    const const_hashes = try allocator.alloc([]const u8, sprites.len);
    defer allocator.free(const_hashes);
    
    for (sprite_hashes, 0..) |hash, i| {
        const_hashes[i] = hash;
    }
    
    // Combine the hashes
    const combined = try combineHashes(const_hashes, allocator);
    defer allocator.free(combined);
    
    // Finalize with a second layer of hashing
    return finalizeHash(combined, allocator);
} 