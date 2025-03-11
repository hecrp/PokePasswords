#!/bin/bash

echo "=== Building optimized Docker image with Zig 0.14.0 ==="
docker build -t pokepasswords-zig:slim .

if [ $? -eq 0 ]; then
    echo "=== Image built successfully! ==="
    
    # Show image size
    echo "=== Image size information ==="
    docker images pokepasswords-zig:slim --format "{{.Size}}"
    
    # Ask the user if they want to run the image
    read -p "Do you want to run the image? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "=== Running Docker image ==="
        docker run -it --rm pokepasswords-zig:slim
    else
        echo "To run the image later, use:"
        echo "docker run -it --rm pokepasswords-zig:slim"
    fi
else
    echo "=== Error building the image ==="
    exit 1
fi 