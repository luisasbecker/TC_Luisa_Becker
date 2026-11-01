#!/usr/bin/env python3
"""Inspect the signed universal APK for the Android v1 distribution.

This is artifact validation, not an on-device or cloud integration test. It never
reads signing credentials, installs an app, or accesses the network.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
from datetime import datetime, timezone
import zipfile


PACKAGE = "br.com.luisabecker.pipeline_bucal"
ENDPOINT = "https://pipeline-bucal-qpkmvmtgra-uc.a.run.app"
ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")
ASSET_ROOT = "assets/flutter_assets/"
REQUIRED_ASSETS = (
    "AssetManifest.bin",
    "assets/fonts/Inter-Variable.ttf",
    "assets/branding/app_icon.png",
    "assets/references/manifest.json",
)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def elf_load_segments(data):
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[5] not in (1, 2):
        raise ValueError("Cabeçalho ELF inválido")
    endian = "<" if data[5] == 1 else ">"
    if data[4] == 2:
        phoff = struct.unpack_from(endian + "Q", data, 32)[0]
        entsize, count = struct.unpack_from(endian + "HH", data, 54)
        minimum, offset_at, address_at, align_at, integer = 56, 8, 16, 48, "Q"
    elif data[4] == 1:
        phoff = struct.unpack_from(endian + "I", data, 28)[0]
        entsize, count = struct.unpack_from(endian + "HH", data, 42)
        minimum, offset_at, address_at, align_at, integer = 32, 4, 8, 28, "I"
    else:
        raise ValueError("Classe ELF desconhecida")
    if entsize < minimum or phoff + entsize * count > len(data):
        raise ValueError("Tabela de segmentos ELF inválida")
    segments = []
    for index in range(count):
        start = phoff + index * entsize
        if struct.unpack_from(endian + "I", data, start)[0] != 1:
            continue
        offset = struct.unpack_from(endian + integer, data, start + offset_at)[0]
        address = struct.unpack_from(endian + integer, data, start + address_at)[0]
        alignment = struct.unpack_from(endian + integer, data, start + align_at)[0]
        segments.append({
            "offset": offset,
            "virtual_address": address,
            "alignment": alignment,
            "supports_16kb": alignment >= 16384 and offset % 16384 == address % 16384,
        })
    if not segments:
        raise ValueError("ELF sem segmentos PT_LOAD")
    return segments


def build_tools(sdk):
    candidates = []
    for path in (sdk / "build-tools").glob("*"):
        if re.fullmatch(r"\d+(?:\.\d+)+", path.name) and all(
            (path / name).is_file() for name in ("aapt", "apksigner", "zipalign")
        ):
            candidates.append(path)
    if not candidates:
        raise ValueError("Android SDK sem build-tools estáveis com aapt, apksigner e zipalign")
    return max(candidates, key=lambda path: tuple(int(part) for part in path.name.split(".")))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--sdk", type=Path, default=os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT"))
    parser.add_argument("--report", type=Path, help="Salvar relatório JSON, inclusive em caso de falha")
    args = parser.parse_args()
    report = {
        "kind": "android_release_artifact_validation",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "apk": str(args.apk.resolve()),
        "expected": {"package": PACKAGE, "version_name": "0.3.0", "version_code": 5,
                     "min_sdk": 24, "target_sdk": 36, "endpoint": ENDPOINT},
        "on_device_test": False,
        "cloud_request_performed": False,
        "checks": [],
    }

    def check(name, passed, detail=None):
        item = {"name": name, "passed": bool(passed)}
        if detail is not None:
            item["detail"] = detail
        report["checks"].append(item)

    def run_tool(name, arguments):
        completed = subprocess.run([str(tool_dir / name), *arguments], capture_output=True, text=True, timeout=120)
        output = completed.stdout + completed.stderr
        check(name, completed.returncode == 0, {"exit_code": completed.returncode, "output": output[-12000:]})
        return output if completed.returncode == 0 else None

    try:
        if not args.apk.is_file() or args.apk.stat().st_size == 0:
            raise ValueError("APK inexistente ou vazio")
        if args.sdk is None:
            raise ValueError("Informe --sdk ou configure ANDROID_HOME")
        tool_dir = build_tools(args.sdk)
        report["build_tools"] = str(tool_dir)
        report["bytes"] = args.apk.stat().st_size
        report["sha256"] = sha256_file(args.apk)
        badging = run_tool("aapt", ["dump", "badging", str(args.apk)])
        if badging is not None:
            for field, expected in (("name", PACKAGE), ("versionCode", "5"), ("versionName", "0.3.0")):
                package_line = next((line for line in badging.splitlines() if line.startswith("package:")), "")
                match = re.search(r"\b" + field + r"='([^']*)'", package_line)
                check("manifest_" + field, match is not None and match.group(1) == expected,
                      match.group(1) if match else "ausente")
            for field, expected in (("sdkVersion", "24"), ("targetSdkVersion", "36")):
                match = re.search(r"^" + field + r":'([^']*)'", badging, re.MULTILINE)
                check("manifest_" + field, match is not None and match.group(1) == expected,
                      match.group(1) if match else "ausente")
            check("not_debuggable", not re.search(r"^application-debuggable", badging, re.MULTILINE))
            check("internet_permission", "uses-permission: name='android.permission.INTERNET'" in badging)
            check("main_activity", "launchable-activity: name='" + PACKAGE + ".MainActivity'" in badging)
        signature = run_tool("apksigner", ["verify", "--verbose", "--print-certs", str(args.apk)])
        if signature is not None:
            check("not_android_debug_certificate", not re.search(r"CN\s*=\s*Android Debug", signature, re.IGNORECASE))
            fingerprints = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)", signature)
            check("signer_certificate_present", bool(fingerprints), fingerprints)
            report["certificate_sha256"] = fingerprints
        run_tool("zipalign", ["-c", "-P", "16", "-v", "4", str(args.apk)])
        with zipfile.ZipFile(args.apk) as archive:
            names = set(archive.namelist())
            for asset in REQUIRED_ASSETS:
                full = ASSET_ROOT + asset
                check("asset:" + asset, full in names and archive.getinfo(full).file_size > 0)
            manifest_path = ASSET_ROOT + "assets/references/manifest.json"
            if manifest_path in names:
                references = json.loads(archive.read(manifest_path))
                assets = references.get("assets", [])
                check("six_reference_classes", {item.get("lesion_class_index") for item in assets if item.get("lesion_class_index") is not None} == set(range(6)))
                for asset in assets:
                    full = ASSET_ROOT + "assets/references/" + asset["file"]
                    present = full in names
                    check("reference:" + asset["file"], present and hashlib.sha256(archive.read(full)).hexdigest() == asset.get("sha256"))
                report["reference_asset_count"] = len(assets)
            for abi in ABIS:
                app_path = "lib/" + abi + "/libapp.so"
                flutter_path = "lib/" + abi + "/libflutter.so"
                check("release_libraries:" + abi, app_path in names and flutter_path in names)
                if app_path in names:
                    check("cloud_endpoint:" + abi, ENDPOINT.encode("ascii") in archive.read(app_path))
            report["elf_libraries"] = {}
            for name in sorted(names):
                if not name.startswith("lib/") or not name.endswith(".so"):
                    continue
                try:
                    segments = elf_load_segments(archive.read(name))
                    report["elf_libraries"][name] = segments
                    check("elf_16kb:" + name, all(segment["supports_16kb"] for segment in segments))
                except (ValueError, struct.error) as error:
                    check("elf_16kb:" + name, False, str(error))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        check("validation_error", False, str(error))

    report["passed"] = bool(report["checks"]) and all(item["passed"] for item in report["checks"])
    if args.report:
        try:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        except OSError as error:
            print("Falha ao salvar relatório: " + str(error), file=sys.stderr)
            return 1
    if report["passed"]:
        print("APK release validado: assinatura, manifesto, recursos, endpoint e alinhamento de 16 KB.")
        print("SHA-256: " + report["sha256"])
        print("Esta validação não substitui testes no aparelho nem confirma uma requisição cloud.")
        return 0
    print("APK não aprovado para esta distribuição:", file=sys.stderr)
    for item in report["checks"]:
        if not item["passed"]:
            print("- " + item["name"] + (": " + item["detail"] if isinstance(item.get("detail"), str) else ""), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
