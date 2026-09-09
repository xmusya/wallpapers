#!/usr/bin/env bash

# =============================================================================
# Wallpaper Post-Processing & Effect Generator
# =============================================================================
# PREREQUISITES:
#   Make sure you have ImageMagick installed before running this script:
#
#     sudo pacman -S imagemagick
#
#   Or install via your distribution's package manager (e.g. apt/dnf).
# =============================================================================

# --- logging helper functions ---
log()      { echo -e "\033[1;37m[$1]\033[0m $2"; }
log_err()  { echo -e "\033[1;31m[$1]\033[0m $2" >&2; }
log_ok()   { echo -e "\033[1;32m[$1]\033[0m $2"; }
log_warn() { echo -e "\033[1;33m[$1]\033[0m $2"; }

# --- imagemagick memory and resource limits ---
export MAGICK_TMPDIR=/tmp
export MAGICK_MEMORY_LIMIT=256MB
export MAGICK_MAP_LIMIT=512MB

base_dir="$(pwd)"

# color target directories to process
target_dirs=("Red" "Orange" "Yellow" "Green" "Blue" "Indigo" "Violet" "Black" "White")

# enable case-insensitive pattern matching for extensions
shopt -s nocaseglob

# --- orphan check function ---
# inspects pixelated/ and blurred/ subdirectories and moves files 
# whose main wallpaper was deleted or moved to notfound/
check_orphans() {
    local folder="$1"
    local pixelated_dir="$folder/pixelated"
    local blurred_dir="$folder/blurred"
    local not_found_dir="$folder/notfound"

    [ -d "$pixelated_dir" ] || [ -d "$blurred_dir" ] || return 0

    mkdir -p "$not_found_dir"

    for tag in "PXL:$pixelated_dir" "BLR:$blurred_dir"; do
        local prefix="${tag%%:*}"
        local dir="${tag#*:}"

        [ -d "$dir" ] || continue

        local count=0
        for file in "$dir"/*.{jpg,jpeg,png,webp}; do
            [ -e "$file" ] || continue
            local name
            name=$(basename "$file")

            if [ ! -f "$folder/$name" ]; then
                log WARN "[$folder] $prefix orphan detected: $name → notfound"
                mv "$file" "$not_found_dir/$name"
                count=$((count + 1))
            fi
        done
        [ "$count" -gt 0 ] && log INF "[$folder] $prefix orphans moved: $count"
    done
}

# --- strip resolution strings from filenames ---
# removes tags like _1920x1080, -3840x2160, etc.
strip_resolutions() {
    local folder="$1"
    log INF "[$folder] checking resolution tags in filenames..."
    local count=0

    for wp in "$folder"/*.{jpg,jpeg,png,webp,svg}; do
        [ -e "$wp" ] || continue
        local name
        name=$(basename "$wp")

        local newname="$name"
        # _images_XXXXxXXXX (including _images_dark_XXXXxXXXX)
        newname=$(echo "$newname" | sed -E 's/_images(_dark)?_[0-9]+x[0-9]+/\1/')
        # -XXXXxXXXX (middle or end of name)
        newname=$(echo "$newname" | sed -E 's/-[0-9]+x[0-9]+//')
        # XXXXxXXXX- (prefix)
        newname=$(echo "$newname" | sed -E 's/^[0-9]+x[0-9]+-//')

        if [ "$name" != "$newname" ]; then
            if [ -e "$folder/$newname" ]; then
                log WARN "[$folder] collision: $name -> $newname (skipping)"
                continue
            fi
            log_ok RNM "[$folder] $name -> $newname"
            mv "$wp" "$folder/$newname"
            count=$((count + 1))
        fi
    done

    log INF "[$folder] renamed files: $count"
}

# --- main processing loop ---
gen_count=0
skip_count=0
resize_count=0

for folder in "${target_dirs[@]}"; do
    folder_path="$base_dir/$folder"

    [ -d "$folder_path" ] || continue

    log INF "=== Processing directory: $folder ==="

    pixelated_dir="$folder_path/pixelated"
    blurred_dir="$folder_path/blurred"

    mkdir -p "$pixelated_dir" "$blurred_dir"

    # clean up orphaned effect files
    check_orphans "$folder_path"

    # rename files containing resolution tags
    strip_resolutions "$folder_path"

    # generate missing pixelated and blurred variants
    for wp in "$folder_path"/*.{jpg,jpeg,png,webp}; do
        [ -e "$wp" ] || continue
        name=$(basename "$wp")

        pix_file="$pixelated_dir/$name"
        blur_file="$blurred_dir/$name"

        if [ ! -f "$pix_file" ] || [ ! -f "$blur_file" ]; then
            log INF "[$folder] processing: $name"

            height=$(identify -format "%h" "$wp" 2>/dev/null)
            [ -z "$height" ] && { log_err ERR "[$folder] failed to read image: $name"; continue; }

            source_img="$wp"

            # downscale if height exceeds 1440p
            if [ "$height" -gt 1440 ]; then
                log WARN "[$folder] resizing to 1440p: $name (${height}p)"
                magick "$wp" -resize x1440 "/tmp/resized_$name" 2>/dev/null
                source_img="/tmp/resized_$name"
                resize_count=$((resize_count + 1))
            fi

            # generate gaussian blur
            if [ ! -f "$blur_file" ]; then
                convert "$source_img" -blur 0x20 "$blur_file" 2>/dev/null
                log_ok BLR "[$folder] created: $name"
            fi

            # generate pixelated effect (downscale 25%, upscale 400%)
            if [ ! -f "$pix_file" ]; then
                convert "$source_img" -scale 25% -scale 400% "$pix_file" 2>/dev/null
                log_ok PXL "[$folder] created: $name"
            fi

            # cleanup temporary resized file
            if [ "$source_img" = "/tmp/resized_$name" ]; then
                rm -f "/tmp/resized_$name"
            fi

            gen_count=$((gen_count + 1))
        else
            skip_count=$((skip_count + 1))
        fi
    done
done

# disable case-insensitive globbing
shopt -u nocaseglob

echo ""
log INF "Execution finished."
log INF "  Total generated: $gen_count"
log INF "  Total skipped (already existed): $skip_count"
log INF "  Total resized to 1440p: $resize_count"
