#!/bin/bash
# Docker wrapper for pokepasswords with native sprite rendering
# Usage: ./docker-pokerun.sh [standard pokepasswords options]

ALL_ARGS=()
USE_RENDER=true
SPRITES_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-render)
            USE_RENDER=false
            shift
            ;;
        *)
            ALL_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$USE_RENDER" = true ]; then
    ALL_ARGS=(--render "${ALL_ARGS[@]}")
fi

if [ -d "sprites" ]; then
    SPRITES_DIR="$(pwd)/sprites"
    echo "Found local sprites directory: $SPRITES_DIR"
    echo "Mounted to /app/user_sprites inside the container"
else
    echo "No local sprites directory found. Only built-in sprites will be available."
fi

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
