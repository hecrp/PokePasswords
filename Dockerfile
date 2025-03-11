# First stage: builder
FROM alpine:3.19 as builder

# Basic dependencies installation (minimal)
RUN apk add --no-cache curl xz git bash patch

# Zig 0.14.0 installation - download, extract, and clean up in a single step
RUN curl -O https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz \
    && mkdir -p /usr/local/zig \
    && tar -xf zig-linux-x86_64-0.14.0.tar.xz --strip-components=1 -C /usr/local/zig \
    && rm zig-linux-x86_64-0.14.0.tar.xz

# Add Zig to PATH
ENV PATH="/usr/local/zig:${PATH}"

# Working directory
WORKDIR /app

# Copy only essential project files for building
COPY build.zig build.zig.zon ./
COPY src/ ./src/
COPY setup.sh ./

# Run the setup script to download and configure zigimg
RUN chmod +x setup.sh && ./setup.sh

# Download minimal test sprites
RUN mkdir -p sprites/pokemon && \
    curl -s https://raw.githubusercontent.com/msikma/pokesprite/master/pokemon-gen8/regular/pikachu.png -o sprites/pokemon/pikachu.png

# Build the application with release mode to optimize binary size
RUN zig build -Doptimize=ReleaseSafe

# Second stage: minimal runtime image
FROM alpine:3.19 as runtime

# Install only the absolute minimum required dependencies
RUN apk add --no-cache bash

# Create a non-root user to run the application
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create directories
WORKDIR /app
RUN mkdir -p /app/user_sprites && chown -R appuser:appgroup /app

# Copy only the built binary from the builder stage
COPY --from=builder /app/zig-out/bin/pokepasswords /app/pokepasswords
COPY --from=builder /app/sprites /app/sprites

# Set volume for user sprites
VOLUME /app/user_sprites

# Switch to non-root user
USER appuser

# Default command to show help
ENTRYPOINT ["/app/pokepasswords"]
CMD ["--help"] 