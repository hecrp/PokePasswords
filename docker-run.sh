#!/bin/bash

# Check if the sprites directory exists
SPRITES_DIR="$PWD/sprites"
MOUNT_OPTION=""

if [ -d "$SPRITES_DIR" ]; then
    echo "Found local sprites directory: $SPRITES_DIR"
    echo "This directory will be mounted to the container as /app/user_sprites"
    MOUNT_OPTION="-v $SPRITES_DIR:/app/user_sprites"
fi

# Check if arguments are provided
if [ $# -eq 0 ]; then
    # Execute with default configuration (show help)
    echo "Running with default configuration (help)..."
    docker run -it --rm $MOUNT_OPTION pokepasswords-zig:slim
else
    # Execute with provided arguments
    echo "Running with arguments: $@"
    
    # Check if the argument contains a path that needs to be adjusted
    ARGS="$@"
    if [[ "$ARGS" == *"sprites/"* && -n "$MOUNT_OPTION" ]]; then
        echo "Note: Path to sprites detected. If referencing local sprites, use /app/user_sprites/ path inside the container."
        echo "Example: --sprite /app/user_sprites/pokemon/pikachu.png"
    fi
    
    docker run -it --rm $MOUNT_OPTION pokepasswords-zig:slim $@
fi 