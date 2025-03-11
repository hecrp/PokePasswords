#!/bin/bash
# Script to download Pokémon sprites from PokéSprite
# Usage: ./download_sprites.sh [number_of_sprites] [output_directory] [preview]

# Default values
NUM_SPRITES=${1:-10}
OUTPUT_DIR=${2:-"../sprites/pokemon"}
RENDER_PREVIEW=${3:-"yes"}  # New option to preview sprites

# Detect operating system
OS=$(uname -s)
# Detect terminal
TERM_PROGRAM=${TERM_PROGRAM:-""}

# Base URL of the PokéSprite repository
BASE_URL="https://raw.githubusercontent.com/msikma/pokesprite/master/pokemon-gen8/regular"

# List of popular Pokémon (valid IDs)
POKEMON=(
    "pikachu"       # 025
    "charizard"     # 006
    "bulbasaur"     # 001
    "squirtle"      # 007
    "eevee"         # 133
    "mewtwo"        # 150
    "gengar"        # 094
    "snorlax"       # 143
    "dragonite"     # 149
    "gyarados"      # 130
    "arcanine"      # 059
    "lucario"       # 448
    "greninja"      # 658
    "gardevoir"     # 282
    "rayquaza"      # 384
    "umbreon"       # 197
    "typhlosion"    # 157
    "blastoise"     # 009
    "jigglypuff"    # 039
    "alakazam"      # 065
    "metagross"     # 376
    "tyranitar"     # 248
    "blaziken"      # 257
    "mimikyu"       # 778
    "rowlet"        # 722
    "absol"         # 359
    "ampharos"      # 181
    "articuno"      # 144
    "zapdos"        # 145
    "moltres"       # 146
)

# Function to render a sprite in the console
render_sprite() {
    local sprite_file=$1
    local pokemon_name=$2
    
    echo "🎮 Previewing sprite: ${pokemon_name} 🎮"
    
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
            img2txt -f utf8 -W 40 "${sprite_file}"
        elif command -v jp2a > /dev/null; then
            jp2a --width=40 --colors "${sprite_file}"
        elif command -v catimg > /dev/null; then
            catimg -w 40 "${sprite_file}"
        elif command -v tiv > /dev/null; then
            # tiv as last resort on macOS
            tiv -w 40 -h 40 "${sprite_file}"
        else
            echo "🖼️  [For better visualization on macOS, install chafa or viu]"
            echo "   brew install chafa   # Best option for Ghostty"
            echo "   brew install viu     # Good alternative"
            echo "   brew install termpix # macOS specific"
        fi
    else
        # For non-macOS systems
        if command -v chafa > /dev/null; then
            chafa -s 40x40 "${sprite_file}"
        elif command -v img2txt > /dev/null; then
            img2txt -f utf8 -W 40 "${sprite_file}"
        elif command -v jp2a > /dev/null; then
            jp2a --width=40 --colors "${sprite_file}"
        elif command -v catimg > /dev/null; then
            catimg -w 40 "${sprite_file}"
        elif command -v tiv > /dev/null; then
            tiv -w 40 -h 40 "${sprite_file}"
        else
            echo "🖼️  [Image not renderable - you need to install a visualization tool]"
            echo "   You can install any of these utilities:"
            echo "   - chafa: Best option for modern terminals"
            echo "   - img2txt: sudo apt-get install caca-utils"
            echo "   - jp2a: sudo apt-get install jp2a"
            echo "   - catimg: sudo apt-get install catimg"
        fi
    fi
    
    echo
}

# Function to check dependencies
check_dependencies() {
    if [[ "${RENDER_PREVIEW}" == "yes" ]]; then
        local has_renderer=0
        
        # On macOS, prioritize optimized tools
        if [[ "$OS" == "Darwin" ]]; then
            for cmd in chafa viu termpix img2txt jp2a catimg tiv; do
                if command -v "${cmd}" > /dev/null; then
                    has_renderer=1
                    if [[ "${cmd}" == "chafa" ]]; then
                        echo "✅ Detected chafa - optimal for visualization on macOS"
                        break
                    elif [[ "${cmd}" == "viu" ]]; then
                        echo "✅ Detected viu - good option for macOS"
                        break
                    elif [[ "${cmd}" == "termpix" ]]; then
                        echo "✅ Detected termpix - macOS specific"
                        break
                    fi
                fi
            done
        else
            # For other operating systems
            for cmd in chafa img2txt jp2a catimg tiv; do
                if command -v "${cmd}" > /dev/null; then
                    has_renderer=1
                    break
                fi
            done
        fi
        
        if [[ ${has_renderer} -eq 0 ]]; then
            if [[ "$OS" == "Darwin" ]]; then
                echo "⚠️  Warning: No optimal tools found for rendering sprites on macOS."
                echo "   For better visualization, install:"
                echo "   - chafa:   brew install chafa   # Best option for Ghostty"
                echo "   - viu:     brew install viu     # Good alternative"
                echo "   - termpix: brew install termpix # macOS specific"
            else
                echo "⚠️  Warning: No tools found for rendering sprites."
                echo "   You can install any of these utilities:"
                echo "   - chafa: Best option for modern terminals"
                echo "   - img2txt: sudo apt-get install caca-utils"
                echo "   - jp2a: sudo apt-get install jp2a"
                echo "   - catimg: sudo apt-get install catimg"
            fi
            
            echo
            read -p "Do you want to continue without preview? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            RENDER_PREVIEW="no"
        fi
    fi
}

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

echo "==== Pokémon Sprite Downloader ===="
echo "Downloading ${NUM_SPRITES} sprites to ${OUTPUT_DIR}"
echo

# Check dependencies
check_dependencies

# Limit the number of sprites to download to the size of the list
if [ "$NUM_SPRITES" -gt "${#POKEMON[@]}" ]; then
    NUM_SPRITES=${#POKEMON[@]}
    echo "Requested number exceeds available list. Will download ${NUM_SPRITES} sprites."
fi

# Counter for successful downloads
COUNT=0

# Download the sprites
for ((i=0; i<NUM_SPRITES; i++)); do
    POKEMON_NAME="${POKEMON[$i]}"
    OUTPUT_FILE="${OUTPUT_DIR}/${POKEMON_NAME}.png"
    URL="${BASE_URL}/${POKEMON_NAME}.png"
    
    echo -n "Downloading ${POKEMON_NAME}... "
    
    if curl -s -o "${OUTPUT_FILE}" "${URL}"; then
        SIZE=$(wc -c < "${OUTPUT_FILE}")
        echo "OK (${SIZE} bytes)"
        COUNT=$((COUNT + 1))
        
        # Render the sprite if preview is enabled
        if [[ "${RENDER_PREVIEW}" == "yes" ]]; then
            render_sprite "${OUTPUT_FILE}" "${POKEMON_NAME}"
        fi
    else
        echo "ERROR"
        # Remove file in case of error
        [ -f "${OUTPUT_FILE}" ] && rm "${OUTPUT_FILE}"
    fi
done

echo
echo "Download completed: ${COUNT}/${NUM_SPRITES} sprites downloaded."
echo "Location: ${OUTPUT_DIR}"
echo
echo "To generate a password with these sprites:"
echo "  zig build run -- --dir ${OUTPUT_DIR} --length 16 --preview"
echo
echo "To explore the downloaded sprites:"
echo "  ./tools/gallery.sh ${OUTPUT_DIR}" 