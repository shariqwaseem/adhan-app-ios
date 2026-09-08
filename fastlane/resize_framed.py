#!/usr/bin/env python3
"""Rescale framed screenshots to an App Store Connect 6.5" display size.

frameit composes at the capture resolution of the simulator in Snapfile
(iPhone 17 Pro -> 1206x2622), which App Store Connect only accepts in its
6.1"/6.3" slot. The 6.5" slot wants 1242x2688 or 1284x2778, and no current
iPhone captures at those sizes, so the finished composition is rescaled here
instead. Framing still happens at native resolution, so the device frame keeps
fitting the screenshot exactly; only the final image is resized.
"""
import os
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCREENSHOTS_DIR = os.path.join(BASE_DIR, "screenshots")
TARGET_WIDTH = 1242
TARGET_HEIGHT = 2688


def current_size(path):
    out = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path], text=True)
    dims = {}
    for line in out.splitlines():
        key, _, value = line.strip().partition(": ")
        if key in ("pixelWidth", "pixelHeight"):
            dims[key] = int(value)
    return dims.get("pixelWidth"), dims.get("pixelHeight")


def main():
    if not os.path.isdir(SCREENSHOTS_DIR):
        print(f"No screenshots directory at {SCREENSHOTS_DIR}")
        return 0

    resized = skipped = 0
    for root, _, files in os.walk(SCREENSHOTS_DIR):
        for name in sorted(files):
            if not name.endswith("_framed.png"):
                continue
            path = os.path.join(root, name)
            if current_size(path) == (TARGET_WIDTH, TARGET_HEIGHT):
                skipped += 1
                continue
            # `!` forces the exact size; the aspect change is ~0.4% and invisible.
            subprocess.check_call([
                "magick", path,
                "-filter", "Lanczos",
                "-resize", f"{TARGET_WIDTH}x{TARGET_HEIGHT}!",
                path
            ])
            print(f"Resized to {TARGET_WIDTH}x{TARGET_HEIGHT}: {path}")
            resized += 1

    print(f"Done. {resized} resized, {skipped} already at {TARGET_WIDTH}x{TARGET_HEIGHT}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
