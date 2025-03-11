# Pokemon Sprites Directory

This directory is intended to store Pokemon sprites that will be used as a source of entropy for password generation.

## Recommended Sources
- [PokéSprite](https://github.com/msikma/pokesprite): Box sprites of all Pokemon.
- [Pokémon Database](https://pokemondb.net/sprites): Organized archive of sprites by generation.

## Supported Formats
- PNG (recommended)
- JPG/JPEG
- BMP

## Copyright Note
Pokemon sprites are property of Nintendo/Creatures Inc./GAME FREAK Inc. Use them only for educational and non-commercial purposes.

## Instructions
1. Download Pokemon sprites from third generation onwards.
2. Place them in this directory.
3. Run the password generator pointing to this directory:
   ```
   zig build run -- --dir sprites/ --length 16 --preview
   ``` 