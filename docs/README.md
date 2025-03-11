# Pokepasswords Documentation

This directory contains detailed documentation about the operation of the Pokepasswords password generator.

## Contents

- [Generation Process](#generation-process)
- [Security](#security)
- [Examples](#examples)

## Generation Process

The process of generating passwords based on Pokemon sprites follows these steps:

1. **Sprite Selection**: The user selects one or more Pokemon sprites via the command line.

2. **Preprocessing**: Each sprite is converted to a 64x64 pixel binary matrix. This process involves:
   - Size normalization to 64x64 pixels
   - Binarization: each pixel is converted to 0 or 1 based on its brightness

3. **Entropy Extraction**: A SHA-256 hash is generated for each binary matrix.

4. **Entropy Combination**: If multiple sprites are used, their hashes are combined through bitwise XOR operations.

5. **Application of Second Hashing Layer**: SHA-256 is applied to the combined hash to maximize entropy.

6. **Password Generation**: The final hash is used as a seed for the Xoshiro256++ pseudorandom generator, which generates random characters according to the specified policy.

### Process Diagram

```
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
|    Pokemon     | --> | Normalization  | --> |    Binary      |
|    Sprite(s)   |     | & Binarization |     |    Matrix(es)  |
|                |     |                |     |                |
+----------------+     +----------------+     +----------------+
                                                      |
                                                      v
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
|     Secure     | <-- |  Pseudorandom  | <-- |  Final SHA-256 |
|    Password    |     |    Generator   |     |     Hash       |
|                |     |                |     |                |
+----------------+     +----------------+     +----------------+
```

## Security

The system provides security for several reasons:

1. **Unique Entropy Source**: Pokemon sprites provide a visually memorable but mathematically robust source of entropy.

2. **Attack Resistance**:
   - The SHA-256 function ensures that even a minimal change in the sprite produces a completely different hash (avalanche property).
   - The XOR combination of multiple sprites increases total entropy.
   - The second layer of hashing eliminates predictable patterns.

3. **Controlled Reproducibility**: The same inputs always produce the same passwords, allowing them to be regenerated if necessary.

4. **Policy Compliance**: Generated passwords comply with configurable security policies (length, character types).

## Examples

### Example 1: Generation with a Single Sprite

```bash
pokepasswords --sprite sprites/pokemon/pikachu.png --length 16 --preview
```

This command will generate a 16-character password using the Pikachu sprite as an entropy source.

### Example 2: Generation with Multiple Sprites

```bash
pokepasswords --dir sprites/pokemon/ --length 20 --chars upper,lower,numbers --preview
```

This command will generate a 20-character password using all available sprites in the directory, including only uppercase letters, lowercase letters, and numbers (without symbols). 