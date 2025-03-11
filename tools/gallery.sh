#!/bin/bash
# Script to explore a gallery of Pokémon sprites
# Usage: ./gallery.sh [sprites_directory]

SPRITES_DIR=${1:-"../sprites/pokemon"}

# Detect operating system
OS=$(uname -s)
# Detect terminal
TERM_PROGRAM=${TERM_PROGRAM:-""}

# Check that the directory exists
if [ ! -d "${SPRITES_DIR}" ]; then
    echo "❌ Error: The directory '${SPRITES_DIR}' does not exist."
    echo "   Use './download_sprites.sh' to download sprites first."
    exit 1
fi

# Count how many sprites there are
SPRITES=()
for file in "${SPRITES_DIR}"/*.png; do
    if [ -f "$file" ]; then
        SPRITES+=("$file")
    fi
done

TOTAL_SPRITES=${#SPRITES[@]}

if [ ${TOTAL_SPRITES} -eq 0 ]; then
    echo "❌ No sprites found in '${SPRITES_DIR}'."
    echo "   Use './download_sprites.sh' to download sprites first."
    exit 1
fi

# Function to render a sprite in the console
render_sprite() {
    local sprite_file=$1
    local pokemon_name=$(basename "${sprite_file}" .png)
    
    clear
    echo "🎮 Pokémon Sprite Gallery 🎮"
    echo "================================="
    echo "Sprite ${CURRENT_INDEX}/${TOTAL_SPRITES}: ${pokemon_name}"
    echo
    
    # Check if we're on macOS with Ghostty or another modern terminal
    if [[ "$OS" == "Darwin" ]]; then
        if command -v chafa > /dev/null; then
            # Optimal settings for macOS with Ghostty/modern terminals
            
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
            viu -w 80 -h 80 "${sprite_file}"
        elif command -v termpix > /dev/null; then
            # termpix is macOS specific
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
            echo "🖼️  [For better visualization on macOS, install chafa or viu]"
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
            echo "🖼️  [Image not renderable - you need to install a visualization tool]"
            echo "   File: ${sprite_file}"
        fi
    fi
    
    echo
    echo "🔄 Controls: "
    echo "   'n' - Next sprite"
    echo "   'p' - Previous sprite"
    echo "   'g' - Go to a specific sprite"
    echo "   'u' - Use this sprite to generate password"
    echo "   'q' - Quit"
    echo
    echo "✨ Current sprite: ${pokemon_name} ✨"
}

# Function to generate a password with the current sprite
generate_password() {
    local sprite_file=$1
    
    clear
    echo "🔐 Generating password with sprite: $(basename "${sprite_file}" .png) 🔐"
    echo
    
    # Command to generate the password
    echo "Running: zig build run -- --sprite ${sprite_file} --length 16 --preview"
    echo
    
    # Ask if they really want to run the command
    read -p "Do you want to run this command now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Run the command and return to the gallery when finished
        zig build run -- --sprite "${sprite_file}" --length 16 --preview
        echo
        read -p "Press ENTER to return to the gallery..." -n 1 -r
    fi
}

# Function to go to a specific sprite
goto_sprite() {
    clear
    echo "🔍 Go to a specific sprite"
    echo "=========================="
    echo "Total sprites: ${TOTAL_SPRITES}"
    echo
    
    # Show list of available sprites
    echo "Available sprites:"
    for i in "${!SPRITES[@]}"; do
        echo "  $((i+1)). $(basename "${SPRITES[$i]}" .png)"
    done
    
    echo
    read -p "Enter the sprite number you want to go to (1-${TOTAL_SPRITES}): " number
    
    # Validate input
    if [[ $number =~ ^[0-9]+$ ]] && [ $number -ge 1 ] && [ $number -le ${TOTAL_SPRITES} ]; then
        CURRENT_INDEX=$number
    else
        echo "Invalid number. Returning to gallery..."
        sleep 2
    fi
}

# Check dependencies
check_dependencies() {
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
        
        if [[ ${has_renderer} -eq 0 ]]; then
            echo "⚠️  Warning: No optimal tools found for rendering sprites on macOS."
            echo "   For better visualization, install:"
            echo "   - chafa:   brew install chafa   # Best option for Ghostty"
            echo "   - viu:     brew install viu     # Good alternative"
            echo "   - termpix: brew install termpix # macOS specific"
            echo
            read -p "Do you want to continue without optimal visualization? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        # For other operating systems
        for cmd in chafa img2txt jp2a catimg tiv; do
            if command -v "${cmd}" > /dev/null; then
                has_renderer=1
                break
            fi
        done
        
        if [[ ${has_renderer} -eq 0 ]]; then
            echo "⚠️  Warning: No tools found for rendering sprites."
            echo "   The gallery will work, but you won't be able to see the sprites."
            echo "   You can install any of these utilities:"
            echo "   - chafa: Best option for modern terminals"
            echo "   - img2txt: sudo apt-get install caca-utils"
            echo "   - jp2a: sudo apt-get install jp2a"
            echo "   - catimg: sudo apt-get install catimg"
            echo
            read -p "Press ENTER to continue..." -n 1 -r
            echo
        fi
    fi
}

# Check dependencies
check_dependencies

# Start the gallery with the first sprite
CURRENT_INDEX=1

# Main gallery loop
while true; do
    # Calculate the real array index (base 0)
    ARRAY_INDEX=$((CURRENT_INDEX-1))
    
    # Render the current sprite
    render_sprite "${SPRITES[$ARRAY_INDEX]}"
    
    # Read user input
    read -n 1 -s action
    
    case "$action" in
        'n')
            # Next sprite
            CURRENT_INDEX=$((CURRENT_INDEX % TOTAL_SPRITES + 1))
            ;;
        'p')
            # Previous sprite
            if [ $CURRENT_INDEX -eq 1 ]; then
                CURRENT_INDEX=$TOTAL_SPRITES
            else
                CURRENT_INDEX=$((CURRENT_INDEX - 1))
            fi
            ;;
        'g')
            # Go to a specific sprite
            goto_sprite
            ;;
        'u')
            # Use this sprite to generate password
            generate_password "${SPRITES[$ARRAY_INDEX]}"
            ;;
        'q')
            # Quit
            clear
            echo "Thank you for using the Pokémon Sprite Gallery!"
            exit 0
            ;;
    esac
done 