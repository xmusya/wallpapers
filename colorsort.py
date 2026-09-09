#!/usr/bin/env python3
"""
=============================================================================
Wallpaper Color Classifier & Sorter
=============================================================================
PREREQUISITES:
  Make sure you have Pillow installed before running this script:

    pip install pillow

  Or install it via system package manager (e.g., Arch/CachyOS):

    sudo pacman -S python-pillow
=============================================================================
"""

import os
import shutil
from PIL import Image

# Destination color directories based on Hue
COLOR_DIRS = ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet", "Black", "White"]

def get_dominant_color(image_path):
    """
    Analyzes average color of an image and returns matching color folder name.
    Uses HSV space to determine Hue value.
    """
    try:
        with Image.open(image_path) as img:
            img = img.convert('RGB')
            # Downscale for performance optimization
            img = img.resize((50, 50))
            
            total_r, total_g, total_b = 0, 0, 0
            count = 0
            
            for r, g, b in img.getdata():
                total_r += r
                total_g += g
                total_b += b
                count += 1
                
            avg_r = total_r / count
            avg_g = total_g / count
            avg_b = total_b / count
            
            # Normalize RGB values
            r_n, g_n, b_n = avg_r / 255.0, avg_g / 255.0, avg_b / 255.0
            mx = max(r_n, g_n, b_n)
            mn = min(r_n, g_n, b_n)
            df = mx - mn
            
            # Calculate Hue angle (0-360)
            if mx == mn:
                h = 0
            elif mx == r_n:
                h = (60 * ((g_n - b_n) / df) + 360) % 360
            elif mx == g_n:
                h = (60 * ((b_n - r_n) / df) + 120) % 360
            elif mx == b_n:
                h = (60 * ((r_n - g_n) / df) + 240) % 360
                
            # Calculate Saturation and Value
            s = 0 if mx == 0 else df / mx
            v = mx

            # Low saturation = achromatic (black/white/gray)
            if s < 0.1:
                if v < 0.3:
                    return "Black"
                elif v > 0.7:
                    return "White"

            # Classify by Hue range
            if 0 <= h < 15 or 345 <= h <= 360:
                return "Red"
            elif 15 <= h < 45:
                return "Orange"
            elif 45 <= h < 70:
                return "Yellow"
            elif 70 <= h < 165:
                return "Green"
            elif 165 <= h < 225:
                return "Blue"
            elif 225 <= h < 270:
                return "Indigo"
            elif 270 <= h < 345:
                return "Violet"
    except Exception as e:
        print(f"[ERR] Failed to process '{image_path}': {e}")
        return None

def main():
    # Detect available directories in current path
    current_items = [d for d in os.listdir('.') if os.path.isdir(d) and not d.startswith('.')]
    
    if not current_items:
        print("[!] No subdirectories found in current location.")
        return

    print("==================================================")
    print("           SELECT SOURCE DIRECTORY                ")
    print("==================================================")
    for idx, folder in enumerate(current_items, 1):
        print(f" [{idx}] {folder}")
    print("==================================================")
        
    choice = input("\nEnter directory index or folder name: ").strip()
    
    source_dir = None
    if choice.isdigit():
        index = int(choice) - 1
        if 0 <= index < len(current_items):
            source_dir = current_items[index]
    elif choice in current_items:
        source_dir = choice

    if not source_dir or not os.path.exists(source_dir):
        print("[!] Invalid choice. Aborting execution.")
        return

    print(f"\n[+] Processing source directory: '{source_dir}'...\n")

    # Create destination directories if they don't exist
    for cdir in COLOR_DIRS:
        os.makedirs(cdir, exist_ok=True)

    valid_exts = ('.jpg', '.jpeg', '.png', '.webp')
    copied_count = 0

    # Process files recursively
    for root, dirs, files in os.walk(source_dir):
        for file in files:
            if file.lower().endswith(valid_exts) and not file.startswith('screenshot'):
                file_path = os.path.join(root, file)
                color = get_dominant_color(file_path)
                
                if color:
                    # Sanitize & prefix destination filename (e.g., gnome_adwaita.jpg)
                    rel_dir = os.path.relpath(root, source_dir).split(os.sep)[0]
                    dest_file_name = f"{rel_dir}_{file}" if rel_dir != "." else file
                    dest_file_name = dest_file_name.replace("'", "").replace('"', '').replace(' ', '_')
                    
                    dest_path = os.path.join(color, dest_file_name)
                    shutil.copy(file_path, dest_path)
                    print(f"  [-> {color:6}] {file} -> {dest_file_name}")
                    copied_count += 1

    print(f"\n[+] Done! Total processed and copied files: {copied_count}")

if __name__ == "__main__":
    main()
