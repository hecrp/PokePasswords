# First stage: builder
FROM alpine:3.21 AS builder

# Basic dependencies installation (minimal)
RUN apk add --no-cache curl xz git bash

# Zig 0.16.0 installation
RUN curl -fsSL -o /tmp/zig.tar.xz https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz \
    && mkdir -p /usr/local/zig \
    && tar -xf /tmp/zig.tar.xz --strip-components=1 -C /usr/local/zig \
    && rm /tmp/zig.tar.xz

ENV PATH="/usr/local/zig:${PATH}"

WORKDIR /app

# Copy only essential project files for building
COPY build.zig build.zig.zon ./
COPY src/ ./src/
COPY test/ ./test/
COPY setup.sh ./

# Fetch dependencies and build
RUN chmod +x setup.sh && ./setup.sh
RUN zig build -Doptimize=ReleaseSafe

# Download a minimal test sprite for the runtime image
RUN mkdir -p sprites/pokemon && \
    curl -fsSL https://raw.githubusercontent.com/msikma/pokesprite/master/pokemon-gen8/regular/pikachu.png \
      -o sprites/pokemon/pikachu.png

# Second stage: minimal runtime image
FROM alpine:3.21 AS runtime

RUN apk add --no-cache bash

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
RUN mkdir -p /app/user_sprites && chown -R appuser:appgroup /app

COPY --from=builder /app/zig-out/bin/pokepasswords /app/pokepasswords
COPY --from=builder /app/sprites /app/sprites

VOLUME /app/user_sprites

USER appuser

ENTRYPOINT ["/app/pokepasswords"]
CMD ["--help"]
