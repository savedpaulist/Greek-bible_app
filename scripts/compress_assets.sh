#!/bin/bash
#
# Сжатие SQLite-ассетов с помощью gzip для уменьшения размера APK.
# Запуск из корня проекта: bash scripts/compress_assets.sh
#
set -e

ASSETS_DIR="assets"
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════════════════"
echo "  Сжатие SQLite-ассетов  →  .gz"
echo "═══════════════════════════════════════════════════"
echo ""

TOTAL_ORIG=0
TOTAL_GZ=0

for f in "$ASSETS_DIR"/*.SQLite3 "$ASSETS_DIR"/*.sqlite3; do
    [ -f "$f" ] || continue

    # Пропускаем копию Дворецкого
    if [[ "$f" == *"copy"* ]]; then
        echo "  ✗ ПРОПУСК (дубликат): $(basename "$f")"
        continue
    fi

    GZ="${f}.gz"

    if [ -f "$GZ" ]; then
        echo "  ✓ Уже сжат: $(basename "$GZ")"
        GZ_SIZE=$(stat -f%z "$GZ" 2>/dev/null || stat --format=%s "$GZ")
        TOTAL_GZ=$((TOTAL_GZ + GZ_SIZE))
        ORIG_SIZE=$(stat -f%z "$f" 2>/dev/null || stat --format=%s "$f")
        TOTAL_ORIG=$((TOTAL_ORIG + ORIG_SIZE))
        continue
    fi

    ORIG_SIZE=$(stat -f%z "$f" 2>/dev/null || stat --format=%s "$f")
    TOTAL_ORIG=$((TOTAL_ORIG + ORIG_SIZE))

    printf "  ⏳ Сжимаю: %-45s" "$(basename "$f")"
    gzip -k -9 "$f"

    GZ_SIZE=$(stat -f%z "$GZ" 2>/dev/null || stat --format=%s "$GZ")
    TOTAL_GZ=$((TOTAL_GZ + GZ_SIZE))

    RATIO=$(echo "scale=0; $GZ_SIZE * 100 / $ORIG_SIZE" | bc)
    echo " → $(echo "scale=1; $GZ_SIZE / 1048576" | bc)MB  (${RATIO}%)"
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Оригинал: $(echo "scale=1; $TOTAL_ORIG / 1048576" | bc) MB"
echo "  Сжатый:   $(echo "scale=1; $TOTAL_GZ / 1048576"   | bc) MB"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Дальнейшие шаги:"
echo "  1. Удалите оригиналы .SQLite3/.sqlite3 из assets/"
echo "       rm assets/*.SQLite3 assets/*.sqlite3"
echo "  2. Удалите дубликат 'DvorFull copy.sqlite3':"
echo "       rm \"assets/DvorFull copy.sqlite3\""
echo "  3. Пересоберите APK:"
echo "       flutter build apk --release"
echo ""
