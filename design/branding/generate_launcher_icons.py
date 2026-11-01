"""Export the approved icon artwork to the native iOS/Android launcher sizes.

Uses macOS sips only for lossless-format resizing; does not redraw the artwork.
Run from any directory with Python 3 on macOS.
"""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "design/branding/app_icon.png"
IOS = ROOT / "mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID = ROOT / "mobile/android/app/src/main/res"


def resize(size: int, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-z", str(size), str(size), str(SOURCE), "--out", str(target)],
        check=True, stdout=subprocess.DEVNULL,
    )


def main() -> None:
    entries = json.loads((IOS / "Contents.json").read_text())["images"]
    exported = set()
    for entry in entries:
        target = IOS / entry["filename"]
        if target not in exported:
            size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
            resize(size, target)
            exported.add(target)
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        target = ANDROID / f"mipmap-{density}" / "ic_launcher.png"
        resize(size, target)
        exported.add(target)
    print(f"Exported {len(exported)} launcher files from {SOURCE.name}.")


if __name__ == "__main__":
    main()
