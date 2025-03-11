#!/bin/bash
# Wrapper script for pokepasswords that adds sprite rendering capability
# Usage: ./pokerun.sh [standard pokepasswords options]

# Default values
SHOW_SPRITE=true
SPRITE_PATH=""
ALL_ARGS=()

# Detect operating system
OS=$(uname -s)
# Detect terminal
TERM_PROGRAM=${TERM_PROGRAM:-""}

# Process arguments to extract sprite path
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sprite)
            SPRITE_PATH="$2"
            ALL_ARGS+=("$1" "$2")
            shift 2
            ;;
        --no-render)
            SHOW_SPRITE=false
            shift
            ;;
        *)
            ALL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Function to render a sprite in the console (copied from render_sprite.sh)
render_sprite() {
    local sprite_file=$1
    local pokemon_name=$(basename "${sprite_file}" .png)
    
    echo "🎮 Rendering sprite: ${pokemon_name} 🎮"
    echo

    # Check if we're on macOS with Ghostty or another modern terminal
    if [[ "$OS" == "Darwin" ]]; then
        if command -v chafa > /dev/null; then
            # Optimal settings for macOS with Ghostty/modern terminals
            echo "🖼️ Rendering in high quality with chafa..."
            
            # Try to detect if terminal supports sixel
            if [[ "$TERM" == *"kitty"* ]] || [[ "$TERM_PROGRAM" == *"iTerm"* ]] || [[ "$TERM" == *"ghostty"* ]]; then
                # High quality sixel mode if supported
                chafa --size=80x80 --colors=256 --symbols=block+border+space+extra --color-space=rgb --dither=floyd-steinberg --dither-grain=1x1 "${sprite_file}" 
            else
                # Good quality fallback for other terminals
                chafa --size=80x80 --colors=256 --symbols=block+border+space "${sprite_file}"
            fi
        elif command -v viu > /dev/null; then
            # viu is great for macOS
            echo "🖼️ Rendering with viu..."
            viu -w 80 -h 80 "${sprite_file}"
        elif command -v termpix > /dev/null; then
            # termpix is macOS specific
            echo "🖼️ Rendering with termpix..."
            termpix --width 80 "${sprite_file}"
        # Check for other renderers as fallback
        elif command -v img2txt > /dev/null; then
            img2txt -f utf8 -W 60 "${sprite_file}"
        elif command -v jp2a > /dev/null; then
            jp2a --width=60 --colors "${sprite_file}"
        elif command -v catimg > /dev/null; then
            catimg -w 60 "${sprite_file}"
        elif command -v tiv > /dev/null; then
            # tiv as last resort on macOS
            tiv -w 60 -h 60 "${sprite_file}"
        else
            SHOW_SPRITE=false
            echo "⚠️ Cannot render sprite - no visualization tools installed"
            echo "   For better visualization on macOS, install chafa or viu:"
            echo "   brew install chafa   # Best option for Ghostty"
            echo "   brew install viu     # Good alternative"
            echo "   brew install termpix # macOS specific"
        fi
    else
        # For non-macOS systems
        if command -v chafa > /dev/null; then
            chafa -s 60x60 "${sprite_file}"
        elif command -v img2txt > /dev/null; then
            img2txt -f utf8 -W 60 "${sprite_file}"
        elif command -v jp2a > /dev/null; then
            jp2a --width=60 --colors "${sprite_file}"
        elif command -v catimg > /dev/null; then
            catimg -w 60 "${sprite_file}"
        elif command -v tiv > /dev/null; then
            tiv -w 60 -h 60 "${sprite_file}"
        else
            SHOW_SPRITE=false
            echo "⚠️ Cannot render sprite - no visualization tools installed"
            echo "   To enable sprite rendering, install one of these utilities:"
            echo "   - chafa: Best option for modern terminals"
            echo "   - img2txt: Text-based rendering"
            echo "   - jp2a: JPEG renderer"
            echo "   - catimg: Terminal image viewer"
        fi
    fi
    
    echo
}

# Render the sprite if enabled and path is provided
if [ "$SHOW_SPRITE" = true ] && [ -n "$SPRITE_PATH" ]; then
    if [ -f "$SPRITE_PATH" ]; then
        echo "======================="
        echo "SPRITE VISUALIZATION"
        echo "======================="
        render_sprite "$SPRITE_PATH"
    else
        echo "⚠️ Warning: Sprite file not found: $SPRITE_PATH"
    fi
fi

# Execute the main program with all arguments
echo "======================="
echo "GENERATING PASSWORD"
echo "======================="
zig build run -- "${ALL_ARGS[@]}" 