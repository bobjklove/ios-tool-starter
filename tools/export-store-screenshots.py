#!/usr/bin/env python3
"""Run the six store screenshot captures serially and export native PNGs."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCALES = (("en", "US"), ("zh-Hans", "CN"), ("ja", "JP"))
DEVICES = (("iphone-6.9", ("iphone", "pro-max")), ("ipad-13", ("ipad", "pro-13-inch")))


def command(args: list[str], *, log: Path | None = None, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, env=env)
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        tail = "\n".join(result.stdout.splitlines()[-30:])
        raise RuntimeError(f"command exited {result.returncode}: {Path(args[0]).name}\n{tail}")
    return result.stdout


def simulator_ids() -> dict[str, str]:
    payload = json.loads(command(["xcrun", "simctl", "list", "devices", "available", "--json"]))
    result: dict[str, str] = {}
    devices = [device for group in payload["devices"].values() for device in group]
    for key, type_fragments in DEVICES:
        matches = [device for device in devices
                   if all(fragment in device.get("deviceTypeIdentifier", "").lower()
                          for fragment in type_fragments)]
        if not matches:
            raise RuntimeError(f"Required simulator type is unavailable for {key}. Install no runtime; provide an existing device.")
        result[key] = matches[0]["udid"]
    return result


def export_result(bundle: Path, locale: str, device_key: str, expected_device_id: str,
                  destination: Path) -> None:
    summary = json.loads(command(["xcrun", "xcresulttool", "get", "test-results", "summary",
                                  "--path", str(bundle)]))
    if summary.get("result") != "Passed" or summary.get("failedTests") != 0 or summary.get("passedTests") != 1:
        raise RuntimeError(f"Screenshot UI test did not pass: {bundle}")
    raw = ROOT / ".build" / (bundle.stem + "-attachments")
    shutil.rmtree(raw, ignore_errors=True)
    command(["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle),
             "--output-path", str(raw)])
    manifest = json.loads((raw / "manifest.json").read_text(encoding="utf-8"))
    found = []
    for test in manifest:
        for attachment in test.get("attachments", []):
            label = attachment.get("suggestedHumanReadableName", "").split("_0_")[0]
            filename = attachment.get("exportedFileName", "")
            if label == "store-home" and filename.lower().endswith(".png"):
                found.append((attachment, raw / filename))
    if len(found) != 1:
        raise RuntimeError(f"Expected exactly one store-home PNG in {bundle}; found {len(found)}")
    attachment, source = found[0]
    device_id = attachment.get("deviceId")
    if device_id != expected_device_id:
        raise RuntimeError("Screenshot attachment came from a different simulator")
    data = source.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 24:
        raise RuntimeError("Exported attachment is not a valid PNG")
    width, height = struct.unpack(">II", data[16:24])
    expected_size = {"iphone-6.9": (1320, 2868), "ipad-13": (2064, 2752)}[device_key]
    if (width, height) != expected_size:
        raise RuntimeError(f"Unexpected native screenshot dimensions: {width}x{height}; expected {expected_size}")
    target = destination / device_key / locale / "store-home.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="ToolStarter.xcodeproj")
    parser.add_argument("--scheme", default="ToolStarterScreenshots")
    parser.add_argument("--output", default=".build/store-screenshots")
    args = parser.parse_args()
    project = (ROOT / args.project).resolve()
    destination = (ROOT / args.output).resolve()
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    try:
        if not project.exists():
            raise RuntimeError(f"Xcode project does not exist: {project}; run xcodegen generate first")
        ids = simulator_ids()
        for device_key, _ in DEVICES:
            for locale, region in LOCALES:
                name = f"store-{device_key}-{locale}"
                bundle = build / f"{name}.xcresult"
                shutil.rmtree(bundle, ignore_errors=True)
                invocation = ["xcodebuild", "test", "-project", str(project), "-scheme", args.scheme,
                              "-derivedDataPath", str(build / "dd"),
                              "-destination", f"platform=iOS Simulator,id={ids[device_key]}",
                              "-only-testing:ToolStarterUITests/StoreScreenshotTests/testStoreScreenshot",
                              "-testLanguage", locale, "-testRegion", region,
                              "-resultBundlePath", str(bundle)]
                try:
                    command(["bash", os.path.expanduser("~/.claude/bin/slot.sh"), "run", "build", "1", "--", *invocation],
                            log=build / f"{name}.log")
                    export_result(bundle, locale, device_key, ids[device_key], destination)
                finally:
                    subprocess.run(["xcrun", "simctl", "shutdown", "all"], cwd=ROOT,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        print(f"Exported six native PNGs to {destination}")
        return 0
    except (OSError, RuntimeError, KeyError, ValueError) as error:
        print(f"export-store-screenshots: {error}", file=sys.stderr)
        return 1
    finally:
        subprocess.run(["xcrun", "simctl", "shutdown", "all"], cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


if __name__ == "__main__":
    raise SystemExit(main())
