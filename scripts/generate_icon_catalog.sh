#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONS_DIR="$ROOT/Sources/NumiAppUI/Assets/ThiingsIcons/Resized"
CATALOG_DIR="$ROOT/Sources/NumiAppUI/Assets/ThiingsIcons.xcassets"

mkdir -p "$CATALOG_DIR"

# 创建Asset Catalog的根Contents.json
cat > "$CATALOG_DIR/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# 为每个图标创建imageset
create_imageset() {
    local icon_name="$1"
    local imageset_dir="$CATALOG_DIR/${icon_name}.imageset"

    mkdir -p "$imageset_dir"

    # 复制不同尺寸的图标
    cp "$ICONS_DIR/${icon_name}_small.png" "$imageset_dir/${icon_name}.png"
    cp "$ICONS_DIR/${icon_name}_medium.png" "$imageset_dir/${icon_name}@2x.png"
    cp "$ICONS_DIR/${icon_name}_large.png" "$imageset_dir/${icon_name}@3x.png"

    # 创建Contents.json
    cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "${icon_name}.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "${icon_name}@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "${icon_name}@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    echo "✅ 创建: ${icon_name}.imageset"
}

echo "🎨 开始创建 Asset Catalog..."
echo "📁 输出目录: $CATALOG_DIR"
echo ""

# 获取所有图标文件
icon_files=("$ICONS_DIR"/*_small.png)
total_icons=${#icon_files[@]}

echo "📊 共 $total_icons 个图标需要处理"
echo ""

# 处理每个图标
for ((i=0; i<total_icons; i++)); do
    file="${icon_files[$i]}"
    filename=$(basename "$file" _small.png)

    echo "🖼️  处理 [$((i+1))/$total_icons]: $filename"
    create_imageset "$filename"
done

echo ""
echo "✨ Asset Catalog 创建完成！"
echo "📁 位置: $CATALOG_DIR"
echo ""
echo "💡 使用方法:"
echo "  1. 在Xcode中打开项目"
echo "  2. 将 ThiingsIcons.xcassets 拖入项目"
echo "  3. 在代码中使用: Image(\"acai-bowl\")"
echo ""
echo "📝 注意:"
echo "  - 每个图标包含 1x, 2x, 3x 三个尺寸"
echo "  - 1x: 64x64 像素 (列表图标)"
echo "  - 2x: 128x128 像素 (详情图标)"
echo "  - 3x: 256x256 像素 (高清显示)"
