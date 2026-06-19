#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT/Sources/NumiAppUI/Assets/ThiingsIcons"

mkdir -p "$OUTPUT_DIR"

# 支出分类图标
EXPENSE_ICONS=(
    "acai-bowl"
    "articulated-bus"
    "bag-of-groceries"
    "apartment-building"
    "digital-billboard"
    "cell-phone-cleaning-kit"
    "medicine-capsule"
    "ab-bench"
    "book"
    "cinema-clapperboard"
    "airplane"
    "game-controller"
    "desktop-computer"
    "lipstick"
    "button-down-shirt"
    "barber"
    "gift-box"
    "baby"
    "cat"
    "armchair"
    "computer-technician"
    "desk"
    "insurance"
    "cash-register"
    "charity-ball"
    "digital-certificate"
    "black-car"
    "coins"
)

# 收入分类图标
INCOME_ICONS=(
    "cash"
    "trophy"
    "digital-alarm-clock"
    "stock-trading-candlestick"
    "coin-jar"
    "farmhouse"
    "briefcase"
    "calligraphy-practice-book"
    "accountant"
    "checkbook"
    "atm-cash-machine"
    "health-insurance-card"
    "unboxing-gift"
    "bingo-ball"
    "coin-purse"
    "garage-sale"
    "award-ceremony"
    "golden-heart"
    "money"
)

download_icon() {
    local icon_name="$1"
    local output_file="$OUTPUT_DIR/${icon_name}.png"

    if [[ -f "$output_file" ]]; then
        echo "⏭️  跳过已存在: $icon_name"
        return 0
    fi

    echo "📥 下载中: $icon_name"

    # 获取页面内容并提取图片URL
    local page_url="https://www.thiings.co/things/${icon_name}"
    local image_url
    image_url=$(curl -s "$page_url" | grep -oE 'https://lftz25oez4aqbxpq.public.blob.vercel-storage.com/image-[^"]*\.png' | head -1)

    if [[ -z "$image_url" ]]; then
        echo "❌ 未找到图片: $icon_name"
        return 1
    fi

    # 下载图片
    curl -s -o "$output_file" "$image_url"

    if [[ -f "$output_file" ]]; then
        local size
        size=$(du -h "$output_file" | cut -f1)
        echo "✅ 完成: $icon_name ($size)"
    else
        echo "❌ 下载失败: $icon_name"
        return 1
    fi
}

echo "🎨 开始下载 Thiings.co 3D图标..."
echo "📁 输出目录: $OUTPUT_DIR"
echo ""

echo "📊 下载支出分类图标 (${#EXPENSE_ICONS[@]}个)..."
for icon in "${EXPENSE_ICONS[@]}"; do
    download_icon "$icon"
    sleep 0.5  # 避免请求过快
done

echo ""
echo "📈 下载收入分类图标 (${#INCOME_ICONS[@]}个)..."
for icon in "${INCOME_ICONS[@]}"; do
    download_icon "$icon"
    sleep 0.5
done

echo ""
echo "✨ 下载完成！"
echo "📁 图标位置: $OUTPUT_DIR"

# 统计下载结果
total_files=$(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ')
total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "📊 共下载 $total_files 个图标，总大小 $total_size"
