// security.zig
//
// Tests to validate security and functionality of the password generator.

const std = @import("std");
const testing = std.testing;
const entropy = @import("entropy");
const password = @import("password");

// Reproducibility: the same seed must produce the same password
test "password reproducibility" {
    const allocator = testing.allocator;

    const test_seed = "esto_es_una_semilla_para_pruebas";

    const policy = password.PasswordPolicy{
        .min_length = 16,
        .character_set = password.CharacterSet{
            .uppercase = true,
            .lowercase = true,
            .numbers = true,
            .symbols = true,
        },
    };

    const pwd1 = try password.generate_password(test_seed, policy, allocator, false, std.testing.io);
    defer allocator.free(pwd1);

    const pwd2 = try password.generate_password(test_seed, policy, allocator, false, std.testing.io);
    defer allocator.free(pwd2);

    try testing.expectEqualStrings(pwd1, pwd2);

    for (0..5) |_| {
        const pwd_extra = try password.generate_password(test_seed, policy, allocator, false, std.testing.io);
        defer allocator.free(pwd_extra);
        try testing.expectEqualStrings(pwd1, pwd_extra);
    }
}

// Policy compliance: generated passwords must satisfy the configured policy
test "policy compliance" {
    const allocator = testing.allocator;

    const test_seed = "semilla_para_verificar_politicas";

    const policies = [_]password.PasswordPolicy{
        .{
            .min_length = 12,
            .character_set = .{
                .uppercase = true,
                .lowercase = false,
                .numbers = false,
                .symbols = false,
            },
        },
        .{
            .min_length = 16,
            .character_set = .{
                .uppercase = true,
                .lowercase = false,
                .numbers = true,
                .symbols = false,
            },
        },
        .{
            .min_length = 20,
            .character_set = .{
                .uppercase = true,
                .lowercase = true,
                .numbers = true,
                .symbols = false,
            },
        },
        .{
            .min_length = 24,
            .character_set = .{
                .uppercase = true,
                .lowercase = true,
                .numbers = true,
                .symbols = true,
            },
        },
        .{
            .min_length = 8,
            .character_set = .{
                .uppercase = false,
                .lowercase = false,
                .numbers = true,
                .symbols = true,
            },
        },
    };

    for (policies) |policy| {
        const pwd = try password.generate_password(test_seed, policy, allocator, false, std.testing.io);
        defer allocator.free(pwd);

        try testing.expect(policy.validate_password(pwd));
        try testing.expect(pwd.len >= policy.min_length);

        var has_uppercase = false;
        var has_lowercase = false;
        var has_numbers = false;
        var has_symbols = false;

        for (pwd) |char| {
            if (char >= 'A' and char <= 'Z') has_uppercase = true;
            if (char >= 'a' and char <= 'z') has_lowercase = true;
            if (char >= '0' and char <= '9') has_numbers = true;
            if (std.mem.indexOfScalar(u8, password.CharacterSet.SYMBOLS, char) != null) has_symbols = true;
        }

        if (policy.character_set.uppercase) {
            try testing.expect(has_uppercase);
        } else {
            try testing.expect(!has_uppercase);
        }

        if (policy.character_set.lowercase) {
            try testing.expect(has_lowercase);
        } else {
            try testing.expect(!has_lowercase);
        }

        if (policy.character_set.numbers) {
            try testing.expect(has_numbers);
        } else {
            try testing.expect(!has_numbers);
        }

        if (policy.character_set.symbols) {
            try testing.expect(has_symbols);
        } else {
            try testing.expect(!has_symbols);
        }
    }
}

// Randomness: different seeds must produce different passwords
test "password randomness" {
    const allocator = testing.allocator;

    const seeds = [_][]const u8{
        "semilla_uno",
        "semilla_dos",
        "semilla_tres",
        "semilla_cuatro",
        "semilla_cinco",
        "semilla_seis",
        "semilla_siete",
        "semilla_ocho",
        "semilla_nueve",
        "semilla_diez",
    };

    const policy = password.PasswordPolicy{
        .min_length = 16,
        .character_set = .{},
    };

    var passwords = try allocator.alloc([]u8, seeds.len);
    defer {
        for (passwords) |pwd| {
            allocator.free(pwd);
        }
        allocator.free(passwords);
    }

    for (seeds, 0..) |seed, i| {
        passwords[i] = try password.generate_password(seed, policy, allocator, false, std.testing.io);
    }

    for (0..passwords.len) |i| {
        for (i + 1..passwords.len) |j| {
            try testing.expect(!std.mem.eql(u8, passwords[i], passwords[j]));
        }
    }

    var distances: f32 = 0;
    var pairs: usize = 0;

    for (0..passwords.len) |i| {
        for (i + 1..passwords.len) |j| {
            var differences: usize = 0;
            const min_len = @min(passwords[i].len, passwords[j].len);

            for (0..min_len) |k| {
                if (passwords[i][k] != passwords[j][k]) {
                    differences += 1;
                }
            }

            const distance = @as(f32, @floatFromInt(differences)) / @as(f32, @floatFromInt(min_len));
            distances += distance;
            pairs += 1;
        }
    }

    const average_distance = distances / @as(f32, @floatFromInt(pairs));
    try testing.expect(average_distance > 0.5);
}

// Entropy: hashes extracted from sprites must be well distributed
test "sprite entropy" {
    const allocator = testing.allocator;

    var sprite1 = [_]u8{0} ** 64;
    var sprite2 = [_]u8{1} ** 64;
    var sprite3 = [_]u8{ 0, 1, 0, 1, 0, 1 } ** 10 ++ [_]u8{0} ** 4;

    var sprite4 = [_]u8{0} ** 64;
    var sprite5 = [_]u8{0} ** 64;

    for (0..64) |i| {
        if ((i / 8 + i % 8) % 2 == 0) {
            sprite4[i] = 1;
        }
        if (i % 9 == 0 or i % 7 == 0) {
            sprite5[i] = 1;
        }
    }

    sprite1[10] = 1;
    sprite1[20] = 1;
    sprite1[30] = 1;

    sprite2[15] = 0;
    sprite2[25] = 0;
    sprite2[35] = 0;

    const hash1 = try entropy.sprite_to_hash(&sprite1, allocator);
    defer allocator.free(hash1);

    const hash2 = try entropy.sprite_to_hash(&sprite2, allocator);
    defer allocator.free(hash2);

    const hash3 = try entropy.sprite_to_hash(&sprite3, allocator);
    defer allocator.free(hash3);

    const hash4 = try entropy.sprite_to_hash(&sprite4, allocator);
    defer allocator.free(hash4);

    const hash5 = try entropy.sprite_to_hash(&sprite5, allocator);
    defer allocator.free(hash5);

    try testing.expect(!std.mem.eql(u8, hash1, hash2));
    try testing.expect(!std.mem.eql(u8, hash1, hash3));
    try testing.expect(!std.mem.eql(u8, hash1, hash4));
    try testing.expect(!std.mem.eql(u8, hash1, hash5));
    try testing.expect(!std.mem.eql(u8, hash2, hash3));
    try testing.expect(!std.mem.eql(u8, hash2, hash4));
    try testing.expect(!std.mem.eql(u8, hash2, hash5));
    try testing.expect(!std.mem.eql(u8, hash3, hash4));
    try testing.expect(!std.mem.eql(u8, hash3, hash5));
    try testing.expect(!std.mem.eql(u8, hash4, hash5));

    try testing.expectEqual(@as(usize, 32), hash1.len);
    try testing.expectEqual(@as(usize, 32), hash2.len);
    try testing.expectEqual(@as(usize, 32), hash3.len);
    try testing.expectEqual(@as(usize, 32), hash4.len);
    try testing.expectEqual(@as(usize, 32), hash5.len);

    var bit_counts = [_]usize{0} ** 5;

    for (hash1) |byte| {
        bit_counts[0] += @popCount(byte);
    }
    for (hash2) |byte| {
        bit_counts[1] += @popCount(byte);
    }
    for (hash3) |byte| {
        bit_counts[2] += @popCount(byte);
    }
    for (hash4) |byte| {
        bit_counts[3] += @popCount(byte);
    }
    for (hash5) |byte| {
        bit_counts[4] += @popCount(byte);
    }

    const total_bits = hash1.len * 8;
    const lower_bound = @as(usize, @intFromFloat(@as(f32, @floatFromInt(total_bits)) * 0.4));
    const upper_bound = @as(usize, @intFromFloat(@as(f32, @floatFromInt(total_bits)) * 0.6));

    for (bit_counts) |count| {
        try testing.expect(count >= lower_bound and count <= upper_bound);
    }

    const sprites = [_][]const u8{ &sprite1, &sprite2, &sprite3, &sprite4, &sprite5 };
    const final_hash = try entropy.extract_entropy(&sprites, allocator);
    defer allocator.free(final_hash);

    try testing.expectEqual(@as(usize, 32), final_hash.len);
}

// Avalanche resistance: tiny input changes must produce very different outputs
test "attack resistance" {
    const allocator = testing.allocator;

    var base_sprite = [_]u8{0} ** 64;
    base_sprite[32] = 1;

    var variant_sprite = [_]u8{0} ** 64;
    variant_sprite[32] = 1;
    variant_sprite[33] = 1;

    const base_hash = try entropy.sprite_to_hash(&base_sprite, allocator);
    defer allocator.free(base_hash);

    const variant_hash = try entropy.sprite_to_hash(&variant_sprite, allocator);
    defer allocator.free(variant_hash);

    var differences: usize = 0;
    for (0..base_hash.len) |i| {
        differences += @popCount(base_hash[i] ^ variant_hash[i]);
    }

    const total_bits = base_hash.len * 8;
    const difference_ratio = @as(f32, @floatFromInt(differences)) / @as(f32, @floatFromInt(total_bits));
    try testing.expect(difference_ratio >= 0.3 and difference_ratio <= 0.7);

    const seed1 = "semilla_de_prueba";
    const seed2 = "semilla_de_pruebA";

    const policy = password.PasswordPolicy{
        .min_length = 20,
        .character_set = .{},
    };

    const pwd1 = try password.generate_password(seed1, policy, allocator, false, std.testing.io);
    defer allocator.free(pwd1);

    const pwd2 = try password.generate_password(seed2, policy, allocator, false, std.testing.io);
    defer allocator.free(pwd2);

    var different_chars: usize = 0;
    for (0..@min(pwd1.len, pwd2.len)) |i| {
        if (pwd1[i] != pwd2[i]) {
            different_chars += 1;
        }
    }

    const char_difference_ratio = @as(f32, @floatFromInt(different_chars)) / @as(f32, @floatFromInt(pwd1.len));
    try testing.expect(char_difference_ratio > 0.7);
}

// Multiple password generation must produce distinct valid passwords
test "multiple password generation" {
    const allocator = testing.allocator;

    const test_seed = "semilla_para_multiples_contraseñas";
    const policy = password.PasswordPolicy{
        .min_length = 12,
        .character_set = .{},
    };

    const password_count: usize = 5;
    const passwords = try password.generate_multiple_passwords(test_seed, policy, password_count, allocator, false, std.testing.io);
    defer {
        for (passwords) |pwd| {
            allocator.free(pwd);
        }
        allocator.free(passwords);
    }

    try testing.expectEqual(password_count, passwords.len);

    for (passwords) |pwd| {
        try testing.expect(policy.validate_password(pwd));
    }

    for (0..passwords.len) |i| {
        for (i + 1..passwords.len) |j| {
            try testing.expect(!std.mem.eql(u8, passwords[i], passwords[j]));
        }
    }
}
