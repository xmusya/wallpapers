#!/usr/bin/env python3
import os
import re

target_dir = "allwp"

if not os.path.exists(target_dir):
    print(f"[!] папка {target_dir} не найдена!")
    exit(1)

files = sorted(os.listdir(target_dir))

for file in files:
    file_path = os.path.join(target_dir, file)
    
    if not os.path.isfile(file_path):
        continue
        
    ext = os.path.splitext(file)[1].lower()
    name = os.path.splitext(file)[0]
    
    new_name = name.lower()
    
    if new_name.startswith("google-"):
        new_name = new_name[7:]
        
    new_name = re.sub(r"['\"]", "", new_name)
    new_name = re.sub(r"[-_]?(stock|wallpaper|background|mobile|ytechb|ytechs)[-_]?", "-", new_name)
    new_name = re.sub(r"[-_]?\d{3,4}x\d{3,4}[-_]?", "-", new_name)
    
    new_name = new_name.replace(" ", "-")
    new_name = re.sub(r"-+", "-", new_name).strip("-")
    
    counter = 1
    candidate_name = new_name
    candidate_path = os.path.join(target_dir, f"{candidate_name}{ext}")
    
    while os.path.exists(candidate_path) and candidate_path != file_path:
        candidate_name = f"{new_name}-{counter}"
        candidate_path = os.path.join(target_dir, f"{candidate_name}{ext}")
        counter += 1
        
    if file_path != candidate_path:
        os.rename(file_path, candidate_path)
        print(f"[RENAME] {file}  ===>  {candidate_name}{ext}")

print("\n[+] готово. все файлы переименованы и сохранены.")
