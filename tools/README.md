# Pokémon Sprite Tools

This directory contains utility scripts for working with Pokémon sprites in PokePasswords.

## Available Scripts

### 1. `download_sprites.sh`

Downloads Pokémon sprites from PokéSprite repository and optionally displays a preview of each sprite.

**Usage:**
```bash
./download_sprites.sh [number_of_sprites] [output_directory] [preview]
```

**Parameters:**
- `number_of_sprites`: Number of sprites to download (default: 10)
- `output_directory`: Directory where sprites will be saved (default: "../sprites/pokemon")
- `preview`: Whether to display a preview of each sprite ("yes" or "no", default: "yes")

**Example:**
```bash
./download_sprites.sh 20 sprites/pokemon yes
```

### 2. `render_sprite.sh`

Displays a single Pokémon sprite in the console using the best available rendering tool.

**Usage:**
```bash
./render_sprite.sh [sprite_path]
```

**Parameters:**
- `sprite_path`: Path to the sprite PNG file (default: "../sprites/pokemon/pikachu.png")

**Example:**
```bash
./render_sprite.sh sprites/pokemon/charizard.png
```

### 3. `gallery.sh`

Interactive gallery to explore all downloaded Pokémon sprites with navigation controls.

**Usage:**
```bash
./gallery.sh [sprites_directory]
```

**Parameters:**
- `sprites_directory`: Directory containing the sprite PNG files (default: "../sprites/pokemon")

**Controls in gallery mode:**
- `n`: Next sprite
- `p`: Previous sprite
- `g`: Go to a specific sprite (shows a list)
- `u`: Use current sprite to generate password
- `q`: Quit gallery

**Example:**
```bash
./gallery.sh sprites/pokemon
```

### 4. `test_sprite.sh`

Tests the reproducibility of password generation for a given sprite.

**Usage:**
```bash
./test_sprite.sh [sprite_path]
```

**Parameters:**
- `sprite_path`: Path to the sprite PNG file (default: "../sprites/pokemon/pikachu.png")

**Example:**
```bash
./test_sprite.sh sprites/pokemon/eevee.png
```

### 5. `pokerun.sh`

Enhanced script for running the password generator with sprite visualization.

**Usage:**
```bash
./pokerun.sh [standard pokepasswords options]
```

**Parameters:**
- All standard pokepasswords parameters are supported
- `--no-render`: Disables sprite visualization

**Example:**
```bash
./pokerun.sh --sprite sprites/pokemon/pikachu.png --length 16 --preview
```

### 6. `docker-pokerun.sh`

Docker version of the enhanced runner with sprite visualization.

**Usage:**
```bash
./docker-pokerun.sh [standard pokepasswords options]
```

**Parameters:**
- All standard pokepasswords parameters are supported
- `--no-render`: Disables sprite visualization

**Example:**
```bash
./docker-pokerun.sh --sprite /app/user_sprites/pokemon/pikachu.png --length 16
```

**Note:** This script visualizes sprites on your local machine before running the password generation in Docker.

## Rendering Tools

For the best visualization experience, these scripts can use various terminal-based image rendering tools:

### Recommended for macOS (especially with Ghostty terminal):
1. **chafa**: `brew install chafa` - Best option, supports Sixel protocol
2. **viu**: `brew install viu` - Good Rust-based viewer
3. **termpix**: `brew install termpix` - macOS specific

### For other systems:
- **img2txt**: `sudo apt-get install caca-utils`
- **jp2a**: `sudo apt-get install jp2a`
- **catimg**: `sudo apt-get install catimg`

The scripts will automatically detect your terminal and use the best available tool. 