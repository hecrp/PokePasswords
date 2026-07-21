#!/bin/bash
# Wrapper script for pokepasswords with native sprite rendering
# Usage: ./pokerun.sh [standard pokepasswords options]

ALL_ARGS=()
USE_RENDER=true

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

echo "======================="
echo "GENERATING PASSWORD"
echo "======================="
zig build run -- "${ALL_ARGS[@]}"
