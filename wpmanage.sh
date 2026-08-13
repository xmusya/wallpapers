#!/usr/bin/env bash

# --- логи ---
log() { echo -e "\033[1;37m[$1]\033[0m $2"; }
log_err()  { echo -e "\033[1;31m[$1]\033[0m $2" >&2; }
log_ok()   { echo -e "\033[1;32m[$1]\033[0m $2"; }
log_warn() { echo -e "\033[1;33m[$1]\033[0m $2"; }

# --- тишина от imagemagick ---
export MAGICK_TMPDIR=/tmp
export MAGICK_MEMORY_LIMIT=256MB
export MAGICK_MAP_LIMIT=512MB

base_dir="$(pwd)"
pixelated_dir="$base_dir/pixelated"
blurred_dir="$base_dir/blurred"
not_found_dir="$base_dir/notfound"

mkdir -p "$pixelated_dir" "$blurred_dir" "$not_found_dir"

shopt -s nocaseglob

log INF "проверяю orphans в pixelated и blurred..."

# функция для проверки сирот
check_orphans() {
    local target_dir="$1"
    local tag="$2"
    local count=0
    for file in "$target_dir"/*.{jpg,jpeg,png,webp}; do
        [ -e "$file" ] || continue
        local name=$(basename "$file")

        if [ ! -f "$base_dir/$name" ]; then
            log WARN "$tag орфан: $name → notfound"
            mv "$file" "$not_found_dir/$name"
            count=$((count + 1))
        fi
    done
    [ "$count" -gt 0 ] && log INF "$tag перемещено орфанов: $count"
}

check_orphans "$pixelated_dir" "PXL"
check_orphans "$blurred_dir" "BLR"

log INF "генерация недостающих эффектов..."

gen_count=0
skip_count=0
resize_count=0

for wp in "$base_dir"/*.{jpg,jpeg,png,webp}; do
    [ -e "$wp" ] || continue
    name=$(basename "$wp")

    pix_file="$pixelated_dir/$name"
    blur_file="$blurred_dir/$name"

    if [ ! -f "$pix_file" ] || [ ! -f "$blur_file" ]; then
        log INF "обрабатываю: $name"

        height=$(identify -format "%h" "$wp" 2>/dev/null)
        [ -z "$height" ] && { log_err ERR "не удалось прочитать: $name"; continue; }

        source_img="$wp"

        if [ "$height" -gt 1440 ]; then
            log LWR "resize до 1440p: $name (${height}p)"
            magick "$wp" -resize x1440 "/tmp/resized_$name" 2>/dev/null
            source_img="/tmp/resized_$name"
            resize_count=$((resize_count + 1))
        fi

        if [ ! -f "$blur_file" ]; then
            convert "$source_img" -blur 0x20 "$blur_file" 2>/dev/null
            log_ok BLR "создан: $name"
        fi

        if [ ! -f "$pix_file" ]; then
            convert "$source_img" -scale 25% -scale 400% "$pix_file" 2>/dev/null
            log_ok PXL "создан: $name"
        fi

        if [ "$source_img" = "/tmp/resized_$name" ]; then
            rm -f "/tmp/resized_$name"
        fi

        gen_count=$((gen_count + 1))
    else
        skip_count=$((skip_count + 1))
    fi
done

shopt -u nocaseglob

echo ""
log INF "готово."
log INF "  сгенерировано: $gen_count"
log INF "  пропущено (уже были): $skip_count"
log INF "  уменьшено до 1440p: $resize_count"
