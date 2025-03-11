#!/bin/bash
# Docker wrapper script for pokepasswords that adds sprite rendering capability
# Usage: ./docker-pokerun.sh [standard pokepasswords options]

# Default values
SHOW_SPRITE=true
SPRITE_PATH=""
ALL_ARGS=()
SPRITES_DIR=""

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

# Render using the render_sprite.sh script if available
if [ "$SHOW_SPRITE" = true ] && [ -n "$SPRITE_PATH" ]; then
    # Check if this is a path to a user sprite
    if [[ "$SPRITE_PATH" == "/app/user_sprites"* ]]; then
        # This is a path inside Docker, convert to local path for rendering
        LOCAL_PATH=${SPRITE_PATH/\/app\/user_sprites/sprites}
        
        # If the sprite exists locally, render it
        if [ -f "$LOCAL_PATH" ]; then
            echo "======================="
            echo "SPRITE VISUALIZATION"
            echo "======================="
            ./tools/render_sprite.sh "$LOCAL_PATH"
        else
            echo "⚠️ Warning: Cannot visualize sprite - not found in local path: $LOCAL_PATH"
        fi
    elif [[ "$SPRITE_PATH" == "sprites/"* ]]; then
        # This is a regular path, render it
        if [ -f "$SPRITE_PATH" ]; then
            echo "======================="
            echo "SPRITE VISUALIZATION"
            echo "======================="
            ./tools/render_sprite.sh "$SPRITE_PATH"
        else
            echo "⚠️ Warning: Sprite file not found: $SPRITE_PATH"
        fi
    else
        echo "⚠️ Warning: Cannot visualize sprite - unsupported path format: $SPRITE_PATH"
    fi
fi

# Check if the local sprites directory exists
if [ -d "sprites" ]; then
    SPRITES_DIR="$(pwd)/sprites"
    echo "Found local sprites directory: $SPRITES_DIR"
    echo "This directory will be mounted to the container as /app/user_sprites"
else
    echo "No local sprites directory found. Only built-in sprites will be available."
fi

# Execute the Docker command with all arguments
echo "======================="
echo "GENERATING PASSWORD IN DOCKER"
echo "======================="
echo "Running with arguments: ${ALL_ARGS[@]}"

if [[ -n "$SPRITES_DIR" ]]; then
    docker run --rm -it \
        -v "$SPRITES_DIR:/app/user_sprites" \
        pokepasswords-zig:slim "${ALL_ARGS[@]}"
else
    docker run --rm -it pokepasswords-zig:slim "${ALL_ARGS[@]}"
fi 