#!/usr/bin/env python3
"""
Configures generated iOS scaffolding (`flutter create --platforms=ios --org app.muxis .`)
with:
  1. `Info.plist`: MUXIS display name, background audio mode (`UIBackgroundModes: [audio]`),
     iPhone Files app visibility (`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`),
     cleartext HTTP/HLS streaming (`NSAllowsArbitraryLoads`), `muxis://auth-callback` deep link,
     and required iOS privacy descriptions (`NSAppleMusicUsageDescription`, etc.).
  2. `AppIcon.appiconset`: Generates full opaque iPhone/iPad PNG icon set (zero alpha) from
     `assets/brand/app_icon_1024.png` using Pillow, macOS `sips`, or pure-Python fallback.
  3. `Runner.xcodeproj/project.pbxproj` and `Podfile`: Sets iOS 14.0 deployment target,
     universal device family (`1,2`), and clean CocoaPods build settings (`ENABLE_BITCODE=NO`).
"""

from pathlib import Path
import json
import plistlib
import re
import shutil
import struct
import subprocess
import zlib


IOS_ICON_SPECS = [
    ("20x20", "ipad", "1x", 20),
    ("20x20", "ipad", "2x", 40),
    ("20x20", "iphone", "2x", 40),
    ("20x20", "iphone", "3x", 60),
    ("29x29", "ipad", "1x", 29),
    ("29x29", "ipad", "2x", 58),
    ("29x29", "iphone", "2x", 58),
    ("29x29", "iphone", "3x", 87),
    ("40x40", "ipad", "1x", 40),
    ("40x40", "ipad", "2x", 80),
    ("40x40", "iphone", "2x", 80),
    ("40x40", "iphone", "3x", 120),
    ("60x60", "iphone", "2x", 120),
    ("60x60", "iphone", "3x", 180),
    ("76x76", "ipad", "1x", 76),
    ("76x76", "ipad", "2x", 152),
    ("83.5x83.5", "ipad", "2x", 167),
    ("1024x1024", "ios-marketing", "1x", 1024),
]


def configure_info_plist(plist_path: Path) -> None:
    with plist_path.open("rb") as f:
        plist = plistlib.load(f)

    plist["CFBundleDisplayName"] = "MUXIS"
    plist["CFBundleName"] = "MUXIS"

    # Background audio playback for locked iPhone & Control Center / AirPlay / CarPlay
    bg_modes = list(plist.get("UIBackgroundModes") or [])
    if "audio" not in bg_modes:
        bg_modes.append("audio")
    plist["UIBackgroundModes"] = bg_modes

    # Expose MUXIS folder inside Apple's "Files -> On My iPhone -> MUXIS"
    # so users can drop MP3/FLAC/M4A/WAV files directly and scan whole accessible storage
    plist["UIFileSharingEnabled"] = True
    plist["LSSupportsOpeningDocumentsInPlace"] = True

    # Global FM Radio HTTP/HTTPS stream compatibility
    ats = dict(plist.get("NSAppTransportSecurity") or {})
    ats["NSAllowsArbitraryLoads"] = True
    plist["NSAppTransportSecurity"] = ats

    # iOS permission descriptions required by Apple frameworks / audio_session / file_picker
    plist.setdefault(
        "NSAppleMusicUsageDescription",
        "MUXIS accesses your local audio library and saved files for lossless playback.",
    )
    plist.setdefault(
        "NSMicrophoneUsageDescription",
        "MUXIS uses audio session routing metadata for DSP and headset controls.",
    )
    plist.setdefault(
        "NSPhotoLibraryUsageDescription",
        "MUXIS reads media and artwork selected from your device.",
    )

    # Custom OAuth/cloud callback deep link (`muxis://auth-callback`)
    url_types = list(plist.get("CFBundleURLTypes") or [])
    has_muxis_scheme = any(
        "muxis" in (item.get("CFBundleURLSchemes") or [])
        for item in url_types
        if isinstance(item, dict)
    )
    if not has_muxis_scheme:
        url_types.append(
            {
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": "app.muxis.muxis",
                "CFBundleURLSchemes": ["muxis"],
            }
        )
    plist["CFBundleURLTypes"] = url_types

    queries = list(plist.get("LSApplicationQueriesSchemes") or [])
    for scheme in ("https", "http", "altstore", "sidestore"):
        if scheme not in queries:
            queries.append(scheme)
    plist["LSApplicationQueriesSchemes"] = queries

    plist["ITSAppUsesNonExemptEncryption"] = False

    with plist_path.open("wb") as f:
        plistlib.dump(plist, f, sort_keys=False)


def configure_pbxproj(pbxproj_path: Path) -> None:
    text = pbxproj_path.read_text(encoding="utf-8")
    text = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[0-9.]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 14.0;",
        text,
    )
    text = re.sub(
        r'TARGETED_DEVICE_FAMILY\s*=\s*"[^"]*";',
        'TARGETED_DEVICE_FAMILY = "1,2";',
        text,
    )
    pbxproj_path.write_text(text, encoding="utf-8")


def configure_podfile(podfile_path: Path) -> None:
    text = podfile_path.read_text(encoding="utf-8")
    text = re.sub(
        r"^#?\s*platform\s*:ios\s*,\s*'[0-9.]+'",
        "platform :ios, '14.0'",
        text,
        flags=re.MULTILINE,
    )

    if "MUXIS_IOS_POST_INSTALL" not in text:
        patch_block = """
  # MUXIS_IOS_POST_INSTALL: Enforce iOS 14.0+ and disable bitcode across CocoaPods
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
"""
        if "post_install do |installer|" in text:
            # Insert right after post_install header
            text = re.sub(
                r"(post_install\s+do\s+\|installer\|[^\n]*\n)",
                r"\1" + patch_block,
                text,
                count=1,
            )
        else:
            text += (
                "\npost_install do |installer|\n"
                + patch_block
                + "end\n"
            )

    podfile_path.write_text(text, encoding="utf-8")


def _flatten_png_rgba_to_rgb_pure(src_png: Path, dst_png: Path, bg_rgb=(10, 14, 24)) -> bool:
    """
    Pure-Python RGBA -> opaque RGB conversion for standard 8-bit PNGs (used when
    neither Pillow nor macOS `sips` is available). Returns False if unsupported PNG.
    """
    raw = src_png.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        return False
    pos = 8
    width = height = 0
    color_type = bit_depth = -1
    idat_chunks = []
    while pos < len(raw):
        length = struct.unpack(">I", raw[pos : pos + 4])[0]
        ctype = raw[pos + 4 : pos + 8]
        cdata = raw[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", cdata
            )
            if bit_depth != 8 or interlace != 0:
                return False
        elif ctype == b"IDAT":
            idat_chunks.append(cdata)
        elif ctype == b"IEND":
            break

    if color_type == 2:
        shutil.copy2(src_png, dst_png)
        return True
    if color_type != 6:
        return False

    decompressed = zlib.decompress(b"".join(idat_chunks))
    bpp = 4
    stride = width * bpp
    recon = bytearray(height * stride)
    in_off = 0
    for y in range(height):
        ftype = decompressed[in_off]
        in_off += 1
        row_start = y * stride
        for x in range(stride):
            val = decompressed[in_off + x]
            a = recon[row_start + x - bpp] if x >= bpp else 0
            b = recon[row_start - stride + x] if y > 0 else 0
            c = recon[row_start - stride + x - bpp] if (y > 0 and x >= bpp) else 0
            if ftype == 0:
                p_val = val
            elif ftype == 1:
                p_val = (val + a) & 0xFF
            elif ftype == 2:
                p_val = (val + b) & 0xFF
            elif ftype == 3:
                p_val = (val + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                p_val = (val + pr) & 0xFF
            else:
                return False
            recon[row_start + x] = p_val
        in_off += stride

    out_rows = bytearray()
    bg_r, bg_g, bg_b = bg_rgb
    for y in range(height):
        out_rows.append(0)
        row_start = y * stride
        for px in range(width):
            i = row_start + px * 4
            r, g, b, alpha = recon[i], recon[i + 1], recon[i + 2], recon[i + 3]
            if alpha == 255:
                out_rows.extend((r, g, b))
            elif alpha == 0:
                out_rows.extend((bg_r, bg_g, bg_b))
            else:
                inv = 255 - alpha
                out_rows.extend(
                    (
                        (r * alpha + bg_r * inv) // 255,
                        (g * alpha + bg_g * inv) // 255,
                        (b * alpha + bg_b * inv) // 255,
                    )
                )

    def make_chunk(chunk_type: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)

    ihdr_rgb = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    compressed_rgb = zlib.compress(bytes(out_rows), level=6)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + make_chunk(b"IHDR", ihdr_rgb)
        + make_chunk(b"IDAT", compressed_rgb)
        + make_chunk(b"IEND", b"")
    )
    dst_png.write_bytes(png_bytes)
    return True


def _resize_with_pillow(base_rgb_png: Path, size: int, dst_png: Path) -> bool:
    try:
        from PIL import Image  # type: ignore
    except Exception:
        return False

    with Image.open(base_rgb_png) as img:
        rgb = img.convert("RGB")
        resized = rgb.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(dst_png, format="PNG")
    return True


def _resize_with_sips(base_rgb_png: Path, size: int, dst_png: Path) -> bool:
    sips_path = shutil.which("sips")
    if not sips_path:
        return False
    res = subprocess.run(
        [sips_path, "-z", str(size), str(size), str(base_rgb_png), "--out", str(dst_png)],
        capture_output=True,
        text=True,
    )
    return res.returncode == 0 and dst_png.exists()


def configure_ios_icons(repo_root: Path, iconset_dir: Path) -> None:
    iconset_dir.mkdir(parents=True, exist_ok=True)
    src_icon = repo_root / "assets" / "brand" / "app_icon_1024.png"
    if not src_icon.exists():
        src_icon = repo_root / "assets" / "brand" / "icons" / "macos" / "app_icon_1024.png"
    if not src_icon.exists():
        return

    # Flatten RGBA transparency onto opaque obsidian backdrop cleanly (Apple forbids icon alpha)
    opaque_master = iconset_dir / "_master_opaque_1024.png"
    if not _flatten_png_rgba_to_rgb_pure(src_icon, opaque_master):
        shutil.copy2(src_icon, opaque_master)

    images_json = []
    seen_filenames = set()
    for size_label, idiom, scale, px_size in IOS_ICON_SPECS:
        filename = f"Icon-App-{size_label}@{scale}.png"
        images_json.append(
            {
                "size": size_label,
                "idiom": idiom,
                "filename": filename,
                "scale": scale,
            }
        )
        if filename in seen_filenames:
            continue
        seen_filenames.add(filename)

        dst_png = iconset_dir / filename
        if px_size == 1024:
            shutil.copy2(opaque_master, dst_png)
        elif not _resize_with_pillow(opaque_master, px_size, dst_png):
            if not _resize_with_sips(opaque_master, px_size, dst_png):
                # Fallback to nearest existing opaque icon if neither PIL nor sips exists
                shutil.copy2(opaque_master, dst_png)

    if opaque_master.exists():
        opaque_master.unlink()

    contents = {
        "images": images_json,
        "info": {"version": 1, "author": "xcode"},
    }
    (iconset_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    repo_root = Path.cwd()
    ios_dir = repo_root / "ios"
    if not ios_dir.exists():
        print("No ios/ directory found; skipping iOS configuration.")
        return

    plist_path = ios_dir / "Runner" / "Info.plist"
    if plist_path.exists():
        configure_info_plist(plist_path)

    pbxproj_path = ios_dir / "Runner.xcodeproj" / "project.pbxproj"
    if pbxproj_path.exists():
        configure_pbxproj(pbxproj_path)

    podfile_path = ios_dir / "Podfile"
    if podfile_path.exists():
        configure_podfile(podfile_path)

    iconset_dir = (
        ios_dir / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    )
    configure_ios_icons(repo_root, iconset_dir)
    print("Configured iOS Info.plist, Podfile, Xcode settings, and AppIcon set.")


if __name__ == "__main__":
    main()
