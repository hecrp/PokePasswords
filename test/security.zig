// security.zig
//
// Tests para validar la seguridad y funcionalidad del generador de contraseñas.

const std = @import("std");
const testing = std.testing;
const entropy = @import("../src/entropy.zig");
const password = @import("../src/password.zig");

// Test de reproducibilidad: verificar que la misma semilla genera la misma contraseña
test "reproducibilidad de contraseña" {
    var allocator = testing.allocator;
    
    // 1. Crear una semilla fija para pruebas
    const test_seed = "esto_es_una_semilla_para_pruebas";
    
    // 2. Definir una política de contraseña
    const policy = password.PasswordPolicy{
        .min_length = 16,
        .character_set = password.CharacterSet{
            .uppercase = true,
            .lowercase = true,
            .numbers = true,
            .symbols = true,
        },
    };
    
    // 3. Generar una primera contraseña con la semilla
    var pwd1 = try password.generatePassword(test_seed, policy, allocator);
    defer allocator.free(pwd1);
    
    // 4. Generar una segunda contraseña con la misma semilla
    var pwd2 = try password.generatePassword(test_seed, policy, allocator);
    defer allocator.free(pwd2);
    
    // 5. Verificar que ambas contraseñas son idénticas
    try testing.expectEqualStrings(pwd1, pwd2);
    
    std.debug.print("Test de reproducibilidad: contraseña 1: {s}, contraseña 2: {s}\n", .{ pwd1, pwd2 });
    
    // 6. Prueba adicional: generar múltiples veces y verificar reproducibilidad
    for (0..5) |_| {
        var pwd_extra = try password.generatePassword(test_seed, policy, allocator);
        defer allocator.free(pwd_extra);
        try testing.expectEqualStrings(pwd1, pwd_extra);
    }
}

// Test de políticas: verificar que las contraseñas generadas cumplen con las políticas definidas
test "cumplimiento de políticas" {
    var allocator = testing.allocator;
    
    // 1. Crear una semilla para pruebas
    const test_seed = "semilla_para_verificar_politicas";
    
    // 2. Definir varias políticas con diferentes requisitos
    const politicas = [_]password.PasswordPolicy{
        // Sólo mayúsculas, longitud 12
        .{
            .min_length = 12,
            .character_set = .{ 
                .uppercase = true,
                .lowercase = false,
                .numbers = false,
                .symbols = false,
            },
        },
        // Mayúsculas y números, longitud 16
        .{
            .min_length = 16,
            .character_set = .{ 
                .uppercase = true,
                .lowercase = false,
                .numbers = true,
                .symbols = false,
            },
        },
        // Todo excepto símbolos, longitud 20
        .{
            .min_length = 20,
            .character_set = .{ 
                .uppercase = true,
                .lowercase = true,
                .numbers = true,
                .symbols = false,
            },
        },
        // Todos los caracteres, longitud 24
        .{
            .min_length = 24,
            .character_set = .{ 
                .uppercase = true,
                .lowercase = true,
                .numbers = true,
                .symbols = true,
            },
        },
        // Solo símbolos y números, longitud corta (8)
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
    
    // 3. Probar cada política
    for (politicas) |policy| {
        // Generar una contraseña con la política actual
        var pwd = try password.generatePassword(test_seed, policy, allocator);
        defer allocator.free(pwd);
        
        // Verificar que la contraseña cumple con la política
        try testing.expect(policy.validatePassword(pwd));
        
        // Verificar la longitud mínima
        try testing.expect(pwd.len >= policy.min_length);
        
        // Verificar conjuntos de caracteres
        var tiene_mayusculas = false;
        var tiene_minusculas = false;
        var tiene_numeros = false;
        var tiene_simbolos = false;
        
        for (pwd) |char| {
            if (char >= 'A' and char <= 'Z') tiene_mayusculas = true;
            if (char >= 'a' and char <= 'z') tiene_minusculas = true;
            if (char >= '0' and char <= '9') tiene_numeros = true;
            if (std.mem.indexOfScalar(u8, password.CharacterSet.SYMBOLS, char) != null) tiene_simbolos = true;
        }
        
        // Verificar que solo están presentes los conjuntos solicitados
        if (policy.character_set.uppercase) {
            try testing.expect(tiene_mayusculas);
        } else {
            try testing.expect(!tiene_mayusculas);
        }
        
        if (policy.character_set.lowercase) {
            try testing.expect(tiene_minusculas);
        } else {
            try testing.expect(!tiene_minusculas);
        }
        
        if (policy.character_set.numbers) {
            try testing.expect(tiene_numeros);
        } else {
            try testing.expect(!tiene_numeros);
        }
        
        if (policy.character_set.symbols) {
            try testing.expect(tiene_simbolos);
        } else {
            try testing.expect(!tiene_simbolos);
        }
        
        std.debug.print("Test de política (longitud: {d}): {s}\n", .{ policy.min_length, pwd });
    }
}

// Test de seguridad: verificar que las contraseñas generadas no son predecibles
test "aleatoriedad de contraseña" {
    var allocator = testing.allocator;
    
    // 1. Generar varias contraseñas con diferentes semillas
    var semillas = [_][]const u8{
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
    
    var contraseñas = try allocator.alloc([]u8, semillas.len);
    defer {
        for (contraseñas) |pwd| {
            allocator.free(pwd);
        }
        allocator.free(contraseñas);
    }
    
    // Generar contraseñas con diferentes semillas
    for (semillas, 0..) |seed, i| {
        contraseñas[i] = try password.generatePassword(seed, policy, allocator);
    }
    
    // 2. Verificar que todas las contraseñas son diferentes entre sí
    for (0..contraseñas.len) |i| {
        for (i+1..contraseñas.len) |j| {
            try testing.expect(!std.mem.eql(u8, contraseñas[i], contraseñas[j]));
        }
    }
    
    // 3. Calcular distancia Hamming entre contraseñas
    var distancias: f32 = 0;
    var pares: usize = 0;
    
    for (0..contraseñas.len) |i| {
        for (i+1..contraseñas.len) |j| {
            var diferencias: usize = 0;
            const lon_min = @min(contraseñas[i].len, contraseñas[j].len);
            
            for (0..lon_min) |k| {
                if (contraseñas[i][k] != contraseñas[j][k]) {
                    diferencias += 1;
                }
            }
            
            const distancia = @as(f32, @floatFromInt(diferencias)) / @as(f32, @floatFromInt(lon_min));
            distancias += distancia;
            pares += 1;
            
            std.debug.print("Distancia entre contraseñas {d} y {d}: {d:.2}%\n", 
                           .{ i + 1, j + 1, distancia * 100 });
        }
    }
    
    // Calcular distancia promedio
    const distancia_promedio = distancias / @as(f32, @floatFromInt(pares));
    std.debug.print("Distancia promedio entre contraseñas: {d:.2}%\n", .{distancia_promedio * 100});
    
    // Esperamos que la distancia promedio sea relativamente alta (> 50%)
    try testing.expect(distancia_promedio > 0.5);
    
    // Imprimir las contraseñas generadas
    std.debug.print("Test de aleatoriedad: contraseñas con diferentes semillas:\n", .{});
    for (contraseñas, 0..) |pwd, i| {
        std.debug.print("  Semilla {d}: {s}\n", .{ i + 1, pwd });
    }
}

// Test de entropía: verificar que la entropía extraída de sprites es suficiente
test "entropía de sprites" {
    var allocator = testing.allocator;
    
    // 1. Simular matrices binarias de sprites
    var sprite1 = [_]u8{0} ** 64;
    var sprite2 = [_]u8{1} ** 64;
    var sprite3 = [_]u8{0, 1, 0, 1, 0, 1} ** 10 ++ [_]u8{0} ** 4;
    
    // Crear sprites más complejos
    var sprite4 = [_]u8{0} ** 64;
    var sprite5 = [_]u8{0} ** 64;
    
    // Crear patrones más complejos
    for (0..64) |i| {
        // Patrón de tablero de ajedrez
        if ((i / 8 + i % 8) % 2 == 0) {
            sprite4[i] = 1;
        }
        
        // Patrón diagonal
        if (i % 9 == 0 or i % 7 == 0) {
            sprite5[i] = 1;
        }
    }
    
    // Modificar algunos bits para simular sprites
    sprite1[10] = 1;
    sprite1[20] = 1;
    sprite1[30] = 1;
    
    sprite2[15] = 0;
    sprite2[25] = 0;
    sprite2[35] = 0;
    
    // 2. Extraer entropía de cada sprite
    var hash1 = try entropy.spriteToHash(&sprite1, allocator);
    defer allocator.free(hash1);
    
    var hash2 = try entropy.spriteToHash(&sprite2, allocator);
    defer allocator.free(hash2);
    
    var hash3 = try entropy.spriteToHash(&sprite3, allocator);
    defer allocator.free(hash3);
    
    var hash4 = try entropy.spriteToHash(&sprite4, allocator);
    defer allocator.free(hash4);
    
    var hash5 = try entropy.spriteToHash(&sprite5, allocator);
    defer allocator.free(hash5);
    
    // 3. Verificar que los hashes son diferentes
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
    
    // 4. Verificar tamaño del hash (SHA-256 = 32 bytes)
    try testing.expectEqual(hash1.len, 32);
    try testing.expectEqual(hash2.len, 32);
    try testing.expectEqual(hash3.len, 32);
    try testing.expectEqual(hash4.len, 32);
    try testing.expectEqual(hash5.len, 32);
    
    // 5. Comprobar distribución de bits en los hashes
    var bit_counts = [_]usize{0} ** 5;
    
    for (hash1) |byte| {
        bit_counts[0] += @popCount(u8, byte);
    }
    
    for (hash2) |byte| {
        bit_counts[1] += @popCount(u8, byte);
    }
    
    for (hash3) |byte| {
        bit_counts[2] += @popCount(u8, byte);
    }
    
    for (hash4) |byte| {
        bit_counts[3] += @popCount(u8, byte);
    }
    
    for (hash5) |byte| {
        bit_counts[4] += @popCount(u8, byte);
    }
    
    // Cada hash debe tener aproximadamente el 50% de bits activos
    // (permitiendo un margen de error del 20%)
    const total_bits = hash1.len * 8;
    const lower_bound = @as(usize, @intFromFloat(@as(f32, @floatFromInt(total_bits)) * 0.4));
    const upper_bound = @as(usize, @intFromFloat(@as(f32, @floatFromInt(total_bits)) * 0.6));
    
    for (bit_counts, 0..) |count, i| {
        std.debug.print("Sprite {d} - Bits activos en hash: {d}/{d} ({d:.2}%)\n", 
                       .{ i + 1, count, total_bits, @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(total_bits)) * 100 });
                       
        try testing.expect(count >= lower_bound and count <= upper_bound);
    }
    
    std.debug.print("Test de entropía: hashes de los sprites simulados:\n", .{});
    imprimirHash("Sprite 1", hash1);
    imprimirHash("Sprite 2", hash2);
    imprimirHash("Sprite 3", hash3);
    imprimirHash("Sprite 4", hash4);
    imprimirHash("Sprite 5", hash5);
    
    // 6. Probar extracción de entropía con múltiples sprites
    var sprites = [_][]const u8{&sprite1, &sprite2, &sprite3, &sprite4, &sprite5};
    var hash_final = try entropy.extractEntropy(&sprites, allocator);
    defer allocator.free(hash_final);
    
    // Verificar tamaño del hash final
    try testing.expectEqual(hash_final.len, 32);
    
    imprimirHash("Hash final combinado", hash_final);
}

// Test de resistencia: verificar que el sistema es resistente a ataques conocidos
test "resistencia a ataques" {
    var allocator = testing.allocator;
    
    // 1. Simular un escenario donde un atacante conoce parte del sprite
    // Creamos dos sprites casi idénticos con una pequeña diferencia
    var sprite_base = [_]u8{0} ** 64;
    sprite_base[32] = 1;
    
    var sprite_variante = [_]u8{0} ** 64;
    sprite_variante[32] = 1;
    sprite_variante[33] = 1;  // Un solo bit diferente
    
    // 2. Extraer entropía de ambos sprites
    var hash_base = try entropy.spriteToHash(&sprite_base, allocator);
    defer allocator.free(hash_base);
    
    var hash_variante = try entropy.spriteToHash(&sprite_variante, allocator);
    defer allocator.free(hash_variante);
    
    // 3. Verificar que los hashes son completamente diferentes a pesar de la pequeña diferencia
    // en los sprites originales (propiedad de avalancha de SHA-256)
    var diferencias: usize = 0;
    for (0..hash_base.len) |i| {
        const bits_diferentes = @popCount(u8, hash_base[i] ^ hash_variante[i]);
        diferencias += bits_diferentes;
    }
    
    // Con SHA-256, esperamos aproximadamente 128 bits diferentes (50% de 256 bits)
    // debido a la propiedad de avalancha
    const bits_totales = hash_base.len * 8;
    const porcentaje_diferencia = @as(f32, @floatFromInt(diferencias)) / @as(f32, @floatFromInt(bits_totales));
    
    std.debug.print("Test de resistencia: bits diferentes: {d}/{d} ({d:.2}%)\n", 
                   .{ diferencias, bits_totales, porcentaje_diferencia * 100 });
    
    // Verificar que el porcentaje de diferencia es cercano al 50%
    // (permitimos un rango entre 30% y 70% para evitar falsos positivos)
    try testing.expect(porcentaje_diferencia >= 0.3 and porcentaje_diferencia <= 0.7);
    
    imprimirHash("Hash sprite base", hash_base);
    imprimirHash("Hash sprite variante", hash_variante);
    
    // 4. Verificar que pequeños cambios en la semilla producen contraseñas muy diferentes
    var seed1 = "semilla_de_prueba";
    var seed2 = "semilla_de_pruebA"; // Cambio de una letra
    
    const policy = password.PasswordPolicy{
        .min_length = 20,
        .character_set = .{},
    };
    
    var pwd1 = try password.generatePassword(seed1, policy, allocator);
    defer allocator.free(pwd1);
    
    var pwd2 = try password.generatePassword(seed2, policy, allocator);
    defer allocator.free(pwd2);
    
    // Contar caracteres diferentes
    var chars_diferentes: usize = 0;
    for (0..@min(pwd1.len, pwd2.len)) |i| {
        if (pwd1[i] != pwd2[i]) {
            chars_diferentes += 1;
        }
    }
    
    const porcentaje_chars_diferentes = @as(f32, @floatFromInt(chars_diferentes)) / @as(f32, @floatFromInt(pwd1.len));
    std.debug.print("Caracteres diferentes en contraseñas: {d}/{d} ({d:.2}%)\n", 
                   .{ chars_diferentes, pwd1.len, porcentaje_chars_diferentes * 100 });
    
    // Esperamos que la mayoría de los caracteres sean diferentes
    try testing.expect(porcentaje_chars_diferentes > 0.7);
    
    std.debug.print("Contraseña 1: {s}\n", .{pwd1});
    std.debug.print("Contraseña 2: {s}\n", .{pwd2});
}

// Test para verificar la generación de múltiples contraseñas
test "generación de múltiples contraseñas" {
    var allocator = testing.allocator;
    
    // 1. Definir semilla y política
    const test_seed = "semilla_para_multiples_contraseñas";
    const policy = password.PasswordPolicy{
        .min_length = 12,
        .character_set = .{},
    };
    
    // 2. Generar múltiples contraseñas
    const numero_contraseñas: usize = 5;
    var contraseñas = try password.generateMultiplePasswords(test_seed, policy, numero_contraseñas, allocator);
    defer {
        for (contraseñas) |pwd| {
            allocator.free(pwd);
        }
        allocator.free(contraseñas);
    }
    
    // 3. Verificar que se generaron el número correcto de contraseñas
    try testing.expectEqual(contraseñas.len, numero_contraseñas);
    
    // 4. Verificar que todas cumplen con la política
    for (contraseñas) |pwd| {
        try testing.expect(policy.validatePassword(pwd));
    }
    
    // 5. Verificar que todas son diferentes entre sí
    for (0..contraseñas.len) |i| {
        for (i+1..contraseñas.len) |j| {
            try testing.expect(!std.mem.eql(u8, contraseñas[i], contraseñas[j]));
        }
    }
    
    std.debug.print("Múltiples contraseñas generadas con la misma semilla:\n", .{});
    for (contraseñas, 0..) |pwd, i| {
        std.debug.print("  Contraseña {d}: {s}\n", .{ i + 1, pwd });
    }
}

// Función auxiliar para imprimir un hash en formato hexadecimal
fn imprimirHash(etiqueta: []const u8, hash: []const u8) void {
    std.debug.print("  {s}: ", .{etiqueta});
    for (hash) |byte| {
        std.debug.print("{x:0>2}", .{byte});
    }
    std.debug.print("\n", .{});
} 