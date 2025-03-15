# Pokepasswords

![Pokepasswords](https://archives.bulbagarden.net/media/upload/thumb/6/61/Red_on_computer.png/441px-Red_on_computer.png?20160406004422)

## Introduction

Pokepasswords was born from the desire to learn the Zig programming language through a meaningful low-level project. This password generator pays homage to one of the most impressive technical achievements in early game development - Game Freak's feat of fitting 151 Pokémon sprites into the limited 1MB cartridge of the original Game Boy.

In 1996, when the first Pokémon games were released, developers had to work with extreme memory constraints. Fitting detailed sprites, game mechanics, music, and the entire world into such a small space required ingenious compression techniques and clever programming. Each Pokémon sprite had to be carefully designed and optimized at the bit level.

Inspired by this technical achievement, Pokepasswords uses Pokémon sprites as sources of entropy for generating secure passwords. The project analyzes these sprites at the bit level (much like Game Freak's programmers had to do), converting them into binary matrices and using cryptographic techniques to derive secure passwords. 

### Development Note

This is a project under development that I'm using while learning the Zig programming language. I'm currently facing some issues with dependencies that have added complexity to the project. For this reason, I've included several auxiliary scripts, and the repository isn't as organized as I would like. I appreciate your understanding as I continue to improve both my ideas and Zig skills.

## How It Works

Pokepasswords generates secure passwords by:
1. Converting Pokémon sprites into binary matrices
2. Using these matrices as sources of entropy
3. Applying cryptographic functions to generate random but reproducible passwords
4. Ensuring passwords meet security requirements (length, character types)

Each sprite always produces the same password, making this a deterministic generator.

## Quick Start

### Basic Usage

```bash
# Run with a specific sprite (local)
zig build run -- --sprite sprites/pokemon/pikachu.png --length 16

# Run with Docker
./docker-run.sh --sprite /app/user_sprites/pokemon/pikachu.png --length 16

# Download sprites first (if needed)
./tools/download_sprites.sh 10 sprites/pokemon
```

### With Sprite Visualization

```bash
# Local usage with sprite preview
./tools/pokerun.sh --sprite sprites/pokemon/pikachu.png --length 16

# Docker usage with sprite preview
./tools/docker-pokerun.sh --sprite /app/user_sprites/pokemon/pikachu.png --length 16
```

## Complete Usage Guide

### Command Options

```
Options:
  --sprite <file>        Select a specific sprite
  --dir <directory>      Load sprites from a directory
  --length <n>           Set password length (default: 16)
  --min-length <n>       Minimum password length (default: 8)
  --max-length <n>       Maximum password length (default: 32)
  --complexity <level>   Password complexity level
                         [minimal, basic, medium, high, normal, custom]
  --chars <categories>   Character types (u=upper, l=lower, n=numbers, s=symbols)
  --preview              Show preview of the generated password
  --help                 Show this help message
```

### Password Complexity Levels

Pokepasswords supports different complexity levels to suit your security needs:

- **minimal**: Lowercase letters only
- **basic**: Lowercase letters + numbers
- **medium**: Lowercase + uppercase + numbers
- **high**: All character sets (lowercase, uppercase, numbers, symbols)
- **normal**: Default behavior (all character sets)
- **custom**: Use character sets specified with `--chars`

#### Examples:

```bash
# Generate a medium complexity password
zig build run -- --sprite sprites/pokemon/pikachu.png --complexity medium

# Generate a password with only lowercase and numbers
zig build run -- --sprite sprites/pokemon/pikachu.png --chars ln

# Set custom length range and complexity
zig build run -- --sprite sprites/pokemon/pikachu.png --min-length 12 --max-length 16 --complexity high
```

### For Local Use

1. **Setup (first time only)**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Download sprites**:
   ```bash
   ./tools/download_sprites.sh
   ```

3. **Generate password**:
   ```bash
   zig build run -- --sprite sprites/pokemon/pikachu.png
   ```

4. **With sprite visualization**:
   ```bash
   ./tools/pokerun.sh --sprite sprites/pokemon/pikachu.png
   ```

5. **Browse sprite gallery**:
   ```bash
   ./tools/gallery.sh sprites/pokemon
   ```

### For Docker Use

1. **Build Docker image (first time only)**:
   ```bash
   ./docker-build.sh
   ```

2. **Download sprites to local directory**:
   ```bash
   ./tools/download_sprites.sh
   ```

3. **Generate password with Docker**:
   ```bash
   ./docker-run.sh --sprite /app/user_sprites/pokemon/pikachu.png
   ```

4. **With sprite visualization**:
   ```bash
   ./tools/docker-pokerun.sh --sprite /app/user_sprites/pokemon/pikachu.png
   ```

### Visualization Requirements

For sprite visualization, install one of these tools:

**For macOS (tested)**:
- **chafa**: `brew install chafa` (best with Ghostty terminal)
- **viu**: `brew install viu`
- **termpix**: `brew install termpix`

**For Linux**:
- **chafa**: `sudo apt install chafa`
- **img2txt**: `sudo apt install caca-utils`
- **jp2a**: `sudo apt install jp2a`

## License

This project is licensed under the MIT license.

Pokémon sprites are property of Nintendo/Creatures Inc./GAME FREAK Inc. and are used for educational and non-commercial purposes only. 
