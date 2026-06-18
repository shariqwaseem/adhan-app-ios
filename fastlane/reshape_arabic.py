#!/usr/bin/env python3
import os
import sys
import re
import subprocess

def install_deps():
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
    except ImportError:
        print("Required Python packages (arabic-reshaper, python-bidi) are missing.")
        print("Installing them now...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "arabic-reshaper", "python-bidi"])
            print("Successfully installed dependencies.")
        except subprocess.CalledProcessError:
            print("Failed with --user, trying standard install...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", "arabic-reshaper", "python-bidi"])
        
        # Add user site-packages to sys.path and invalidate import caches
        import site
        import importlib
        user_site = site.getusersitepackages()
        if user_site not in sys.path:
            sys.path.append(user_site)
        importlib.invalidate_caches()
        
        # Ensure they can be imported
        global arabic_reshaper, get_display
        import arabic_reshaper
        from bidi.algorithm import get_display

install_deps()
import arabic_reshaper
from bidi.algorithm import get_display

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
AR_DIR = os.path.join(BASE_DIR, "screenshots", "ar")
FILES = ["keyword.strings", "title.strings"]

def reshape_text(text):
    # Split by literal \n (escaped newline in the strings file)
    parts = text.split("\\n")
    reshaped_parts = []
    for part in parts:
        # Reshape Arabic characters
        reshaped = arabic_reshaper.reshape(part)
        # Apply Bidi algorithm to reverse RTL characters for LTR renderers
        bidi_text = get_display(reshaped)
        reshaped_parts.append(bidi_text)
    return "\\n".join(reshaped_parts)

def cmd_reshape():
    print("Backing up and reshaping Arabic strings files...")
    for filename in FILES:
        filepath = os.path.join(AR_DIR, filename)
        if not os.path.exists(filepath):
            print(f"File not found: {filepath}, skipping.")
            continue
        
        # Backup
        bak_filepath = filepath + ".bak"
        if not os.path.exists(bak_filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            with open(bak_filepath, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Created backup: {bak_filepath}")
        
        # Reshape
        new_lines = []
        with open(filepath, "r", encoding="utf-8") as f:
            lines = f.readlines()
        
        pattern = re.compile(r'^"([^"]+)"\s*=\s*"(.*)"\s*;\s*$')
        for line in lines:
            stripped = line.strip()
            match = pattern.match(stripped)
            if match:
                key = match.group(1)
                value = match.group(2)
                reshaped_value = reshape_text(value)
                new_line = f'"{key}" = "{reshaped_value}";\n'
                new_lines.append(new_line)
            else:
                new_lines.append(line)
        
        with open(filepath, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
        print(f"Reshaped: {filepath}")

def cmd_restore():
    print("Restoring original Arabic strings files from backup...")
    for filename in FILES:
        filepath = os.path.join(AR_DIR, filename)
        bak_filepath = filepath + ".bak"
        if os.path.exists(bak_filepath):
            with open(bak_filepath, "r", encoding="utf-8") as f:
                content = f.read()
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
            os.remove(bak_filepath)
            print(f"Restored: {filepath}")
        else:
            print(f"No backup found for: {filepath}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "restore":
        cmd_restore()
    else:
        cmd_reshape()
