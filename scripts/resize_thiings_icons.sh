#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT/Sources/NumiAppUI/Assets/ThiingsIcons"
OUTPUT_DIR="$ROOT/Sources/NumiAppUI/Assets/ThiingsIcons/Resized"

mkdir -p "$OUTPUT_DIR"

# 定义尺寸变体
SIZES=(
    "64:small"      # 列表图标
    "128:medium"    # 详情图标
    "256:large"     # 高清显示
)

resize_icon() {
    local input_file="$1"
    local filename=$(basename "$input_file" .png)

    for size_spec in "${SIZES[@]}"; do
        local size="${size_spec%%:*}"
        local suffix="${size_spec##*:}"
        local output_file="$OUTPUT_DIR/${filename}_${suffix}.png"

        if [[ -f "$output_file" ]]; then
            echo "⏭️  跳过已存在: ${filename}_${suffix}.png"
            continue
        fi

        # 使用sips调整尺寸（macOS内置工具）
        sips -z "$size" "$size" "$input_file" --out "$output_file" > /dev/null 2>&1

        if [[ -f "$output_file" ]]; then
            local file_size
            file_size=$(du -h "$output_file" | cut -f1)
            echo "✅ 完成: ${filename}_${suffix}.png ($size x $size, $file_size)"
        else
            echo "❌ 失败: ${filename}_${suffix}.png"
        fi
    done
}

echo "🔧 开始调整图标尺寸..."
echo "📁 源目录: $SOURCE_DIR"
echo "📁 输出目录: $OUTPUT_DIR"
echo ""

# 获取所有PNG文件
png_files=("$SOURCE_DIR"/*.png)
total_files=${#png_files[@]}

echo "📊 共 $total_files 个图标需要处理"
echo ""

# 处理每个图标
for ((i=0; i<total_files; i++)); do
    file="${png_files[$i]}"
    filename=$(basename "$file")

    echo "🖼️  处理 [$((i+1))/$total_files]: $filename"
    resize_icon "$file"
done

echo ""
echo "✨ 尺寸调整完成！"

# 统计结果
echo ""
echo "📊 统计信息:"
for size_spec in "${SIZES[@]}"; do
    size="${size_spec%%:*}"
    suffix="${size_spec##*:}"
    count=$(ls -1 "$OUTPUT_DIR"/*_${suffix}.png 2>/dev/null | wc -l | tr -d ' ')
    total_size=$(du -sh "$OUTPUT_DIR"/*_${suffix}.png 2>/dev/null | tail -1 | cut -f1)
    echo "  - ${suffix} (${size}x${size}): $count 个文件, 总大小 $total_size"
done

echo ""
echo "📁 图标位置: $OUTPUT_DIR"
echo ""
echo "💡 使用建议:"
echo "  - 列表图标: 使用 _small 版本 (64x64)"
echo "  - 详情图标: 使用 _medium 版本 (128x128)"
echo "  - 高清显示: 使用 _large 版本 (256x256)"
