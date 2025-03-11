#!/bin/bash

# Pokemon Sprite Downloader
# A helper script to download Pokemon sprites for Pokepasswords

# Base URLs for sprite sources
POKESPRITE_URL="https://raw.githubusercontent.com/msikma/pokesprite/master/pokemon-gen8/regular"
POKEDB_URL="https://img.pokemondb.net/sprites/home/normal"

# Directories
SPRITES_DIR="sprites/pokemon"
TEMP_DIR="/tmp/pokesprites"

# Make sure the sprites directory exists
mkdir -p "$SPRITES_DIR"

# Print the header
echo "========================================="
echo "     Pokemon Sprite Downloader Tool      "
echo "========================================="
echo "This tool helps you download Pokemon sprites for use with Pokepasswords."
echo ""

# Function to download a specific Pokemon sprite
download_pokemon() {
    local pokemon_name=$1
    local pokemon_lowercase=$(echo "$pokemon_name" | tr '[:upper:]' '[:lower:]')
    
    echo "Downloading sprite for $pokemon_name..."
    
    # Try from PokéSprite repository first
    if curl -s --head "$POKESPRITE_URL/$pokemon_lowercase.png" | head -1 | grep -q "200"; then
        curl -s "$POKESPRITE_URL/$pokemon_lowercase.png" -o "$SPRITES_DIR/$pokemon_lowercase.png"
        echo "✓ Downloaded $pokemon_lowercase.png from PokéSprite"
        return 0
    # Try from Pokemon Database as fallback
    elif curl -s --head "$POKEDB_URL/$pokemon_lowercase.png" | head -1 | grep -q "200"; then
        curl -s "$POKEDB_URL/$pokemon_lowercase.png" -o "$SPRITES_DIR/$pokemon_lowercase.png"
        echo "✓ Downloaded $pokemon_lowercase.png from Pokemon Database"
        return 0
    else
        echo "✗ Could not find sprite for $pokemon_name"
        return 1
    fi
}

# Function to download a range of Pokemon by ID
download_range() {
    local start_id=$1
    local end_id=$2
    
    echo "Downloading sprites for Pokemon #$start_id to #$end_id..."
    mkdir -p "$TEMP_DIR"
    
    # Download Pokemon.json for ID to name mapping (using Pokemon API)
    echo "Fetching Pokemon data..."
    for id in $(seq $start_id $end_id); do
        echo -ne "Processing Pokemon #$id...\r"
        pokemon_data=$(curl -s "https://pokeapi.co/api/v2/pokemon/$id")
        if [ -n "$pokemon_data" ]; then
            pokemon_name=$(echo $pokemon_data | grep -o '"name":"[^"]*"' | head -1 | cut -d ":" -f2 | tr -d '"')
            if [ -n "$pokemon_name" ]; then
                download_pokemon "$pokemon_name"
            fi
        fi
        # Be nice to the API
        sleep 1
    done
    
    echo "Download complete! Sprites saved to $SPRITES_DIR/"
    rm -rf "$TEMP_DIR"
}

# Function to list popular Pokemon as suggestions
list_popular() {
    echo "Popular Pokemon suggestions:"
    echo "1. pikachu     6. charizard   11. gengar     16. mewtwo"
    echo "2. bulbasaur   7. squirtle    12. dragonite  17. gyarados"
    echo "3. charmander  8. eevee       13. mew        18. snorlax"
    echo "4. jigglypuff  9. meowth      14. lugia      19. tyranitar"
    echo "5. psyduck     10. magikarp   15. rayquaza   20. lucario"
    echo ""
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo "What would you like to do?"
        echo "1. Download sprite for a specific Pokemon"
        echo "2. Download sprites for a range of Pokemon IDs"
        echo "3. View popular Pokemon suggestions"
        echo "4. Exit"
        echo ""
        read -p "Enter your choice (1-4): " choice
        
        case $choice in
            1)
                echo ""
                read -p "Enter Pokemon name (e.g., pikachu): " pokemon_name
                download_pokemon "$pokemon_name"
                ;;
            2)
                echo ""
                read -p "Enter starting Pokemon ID: " start_id
                read -p "Enter ending Pokemon ID: " end_id
                download_range $start_id $end_id
                ;;
            3)
                echo ""
                list_popular
                ;;
            4)
                echo ""
                echo "Thank you for using the Pokemon Sprite Downloader!"
                echo "You can use your downloaded sprites with Pokepasswords:"
                echo ""
                echo "Outside Docker:"
                echo "zig build run -- --sprite sprites/pokemon/pikachu.png"
                echo ""
                echo "With Docker:"
                echo "./docker-run.sh --sprite sprites/pokemon/pikachu.png"
                echo ""
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter a number between 1 and 4."
                ;;
        esac
    done
}

# Start the main menu
main_menu 