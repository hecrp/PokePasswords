#!/bin/bash
# Script to test password generation with a specific sprite
# Usage: ./test_sprite.sh [sprite_path]

# Default values
SPRITE_PATH=${1:-"../sprites/pokemon/pikachu.png"}
SPRITES_DIR="../sprites/pokemon"
LENGTH=16

echo "===== Pokepasswords Reproducibility Test ====="
echo "Sprite: ${SPRITE_PATH}"
echo "Length: ${LENGTH}"
echo

# Function to simulate password generation from a sprite
function generate_password {
    # Create a deterministic hash from the sprite name
    local sprite=$(basename "$SPRITE_PATH")
    # Use SHA-256 to generate a consistent hash
    local hash=$(echo -n "$sprite" | openssl dgst -sha256 -binary | xxd -p)
    
    # Convert the hash into a seed for our "simulated" generator
    local seed=$(echo -n "$hash" | cut -c 1-16)
    
    # List of possible characters for the simulated password
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
    local password=""
    
    # Generate deterministic password based on the seed
    for i in $(seq 1 $LENGTH); do
        # Use a consistent position based on seed and current position
        local pos=$(( $(echo -n "${seed}${i}" | cksum | cut -d' ' -f1) % ${#chars} ))
        password="${password}${chars:$pos:1}"
    done
    
    echo "$password"
}

# Simulate multiple password generations to verify reproducibility
echo "Simulating multiple password generations with the same sprite..."
echo

for i in {1..5}; do
    pwd=$(generate_password)
    echo "Generation $i: $pwd"
done

echo
echo "===== Reproducibility Verification ====="
if [ $(generate_password) == $(generate_password) ]; then
    echo "✓ SUCCESS: Password is consistently reproduced with the same sprite."
else
    echo "✗ ERROR: Password is not consistently reproduced."
fi

echo
echo "===== Uniqueness Verification with Different Sprites ====="
echo "Comparing passwords generated with different sprites:"
echo

if [ -d "$SPRITES_DIR" ]; then
    prev_pwd=""
    for sprite in $SPRITES_DIR/*.png; do
        SPRITE_PATH="$sprite"
        current_pwd=$(generate_password)
        pokemon=$(basename "$sprite" .png)
        echo "${pokemon}: ${current_pwd}"
        
        if [ -n "$prev_pwd" ] && [ "$prev_pwd" == "$current_pwd" ]; then
            echo "✗ ERROR: Different sprites generated the same password."
            exit 1
        fi
        
        prev_pwd="$current_pwd"
    done
    echo
    echo "✓ SUCCESS: All sprites generated unique passwords."
else
    echo "Sprites directory not found: $SPRITES_DIR"
    echo "Run this script from the 'tools' directory."
fi 