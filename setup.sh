#!/bin/bash
# Setup script for Pokepasswords - Downloads and configures dependencies

echo "🔧 Setting up Pokepasswords dependencies..."

# Create deps directory if it doesn't exist
mkdir -p deps
cd deps

# Clean up any existing zigimg installation
if [ -d "zigimg" ]; then
    echo "⚠️ Found existing zigimg installation, removing it..."
    rm -rf zigimg
fi

echo "📥 Downloading zigimg from GitHub..."
# Usamos la rama master (versión estable)
ZIGIMG_URL="https://github.com/zigimg/zigimg/archive/refs/heads/master.tar.gz"
# Usamos -L para seguir redirecciones y -f para fallar silenciosamente si hay error
curl -L -f -o zigimg-master.tar.gz "$ZIGIMG_URL"

if [ $? -ne 0 ]; then
    echo "❌ Failed to download zigimg. Please check your internet connection."
    exit 1
fi

echo "📦 Extracting zigimg..."
tar -xzf zigimg-master.tar.gz 
mv zigimg-master zigimg
rm zigimg-master.tar.gz

if [ ! -d "zigimg" ]; then
    echo "❌ Failed to extract zigimg correctly."
    exit 1
fi

echo "🔧 Applying compatibility fixes for Zig 0.14.0..."

# Verificar que existe el archivo reader.zig
if [ -f "zigimg/src/formats/png/reader.zig" ]; then
    # Función portable para editar archivos
    safe_replace() {
        local file=$1
        local pattern=$2
        local replacement=$3
        # Crear un archivo temporal
        local tmpfile=$(mktemp)
        # Reemplazar y guardar en el archivo temporal
        sed "s/$pattern/$replacement/g" "$file" > "$tmpfile"
        # Mover el archivo temporal al original
        mv "$tmpfile" "$file"
    }
    
    # 1. Parche para el error de Allocator.VTable.remap
    echo "  - Fixing NoopAllocator definition..."
    safe_replace "zigimg/src/formats/png/reader.zig" \
        "Allocator\.VTable{ \.alloc = undefined, \.free = undefined, \.resize = undefined };" \
        "Allocator.VTable{ .alloc = undefined, .free = undefined, .resize = undefined, .remap = undefined };"
    
    # 2. Parche para el error de enum Size.One
    echo "  - Fixing Size enum reference..."
    safe_replace "zigimg/src/formats/png/reader.zig" \
        "size == \.One" \
        "size == .one"
    
    # 3. Parche para el error de isWasm()
    echo "  - Fixing isWasm check..."
    safe_replace "zigimg/src/formats/png/reader.zig" \
        "target\.isWasm()" \
        "target.os.tag == .wasi"
    
    echo "✅ Compatibility fixes applied."
else
    echo "❌ Cannot find reader.zig file. Setup failed."
    exit 1
fi

cd ..

echo "✅ Setup completed successfully!"
echo "You can now build the project with: zig build"
echo ""
echo "🚀 To generate a password, run:"
echo "zig build run -- --sprite sprites/pokemon/pikachu.png --length 16 --preview" 