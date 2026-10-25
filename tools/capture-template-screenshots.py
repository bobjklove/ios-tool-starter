#!/usr/bin/env python3
"""Capture and export template screenshots for the iOS tool app.

The UI tests run once per language and attach every requested page/mode PNG.
This script runs those three tests serially, exports the attachments, and copies
them to .build/screens/<locale>/<mode>/<page>.png.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

RUNS = (
    ("en", "US", ("light", "dark")),
    ("zh-Hans", "CN", ("light", "dark")),
    ("ja", "JP", ("light",)),
)
PAGES = ("home", "empty", "paywall")


def command(args: list[str], *, log: Path | None = None) -> str:
    result = subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        tail = "\n".join(result.stdout.splitlines()[-40:])
        raise RuntimeError(f"command exited {result.returncode}: {Path(args[0]).name}\n{tail}")
    return result.stdout


def simulator_id() -> str:
    payload = json.loads(
        command(["xcrun", "simctl", "list", "devices", "available", "--json"])
    )
    devices = [device for group in payload["devices"].values() for device in group]
    matches = [device for device in devices if device.get("name") == "iPhone 18 Pro Max"]
    if not matches:
        raise RuntimeError("iPhone 18 Pro Max simulator is unavailable")
    return matches[0]["udid"]


def export_attachments(bundle: Path, locale: str, modes: tuple[str, ...], destination: Path) -> list[Path]:
    summary = json.loads(
        command(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle)])
    )
    if summary.get("result") != "Passed" or summary.get("failedTests") != 0:
        raise RuntimeError(f"UI test did not pass for {locale}: {bundle}")

    raw = ROOT / ".build" / f"template-screens-{locale}-attachments"
    shutil.rmtree(raw, ignore_errors=True)
    command(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle), "--output-path", str(raw)]
    )
    manifest = json.loads((raw / "manifest.json").read_text(encoding="utf-8"))

    exported: list[Path] = []
    for test in manifest:
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "").split("_0_")[0]
            filename = attachment.get("exportedFileName", "")
            if not filename.lower().endswith(".png"):
                continue
            page = next((item for item in PAGES if name.endswith(f"-{item}")), None)
            mode = next((item for item in modes if f"-{item}-" in name), None)
            if page is None or mode is None or not name.startswith(f"{locale}-"):
                continue
            source = raw / filename
            data = source.read_bytes()
            if data[:8] != b"\x89PNG\r\n\x1a\n":
                raise RuntimeError(f"Attachment is not a valid PNG: {source}")
            target = destination / locale / mode / f"{page}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            exported.append(target)
    return exported


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="ToolStarter.xcodeproj")
    parser.add_argument("--scheme", default="ToolStarterScreenshots")
    parser.add_argument("--output", default=".build/screens")
    args = parser.parse_args()

    project = (ROOT / args.project).resolve()
    destination = (ROOT / args.output).resolve()
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    device_id = simulator_id()

    shutil.rmtree(destination, ignore_errors=True)
    destination.mkdir(parents=True, exist_ok=True)
    exported_all: list[Path] = []

    try:
        for locale, region, modes in RUNS:
            bundle = build / f"template-screens-{locale}.xcresult"
            shutil.rmtree(bundle, ignore_errors=True)
            invocation = [
                "xcodebuild",
                "test",
                "-project",
                str(project),
                "-scheme",
                args.scheme,
                "-derivedDataPath",
                str(build / "dd"),
                "-destination",
                f"platform=iOS Simulator,id={device_id}",
                "-only-testing:ToolStarterUITests/StoreScreenshotTests",
                "-testLanguage",
                locale,
                "-testRegion",
                region,
                "-resultBundlePath",
                str(bundle),
            ]
            command(
                [
                    "bash",
                    os.path.expanduser("~/.claude/bin/slot.sh"),
                    "run",
                    "build",
                    "1",
                    "--",
                    *invocation,
                ],
                log=build / f"template-screens-{locale}.log",
            )
            exported_all.extend(export_attachments(bundle, locale, modes, destination))
    except (OSError, RuntimeError, KeyError, ValueError) as error:
        print(f"capture-template-screenshots: {error}", file=sys.stderr)
        return 1
    finally:
        subprocess.run(
            ["xcrun", "simctl", "shutdown", device_id],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

    print(f"Exported {len(exported_all)} PNGs to {destination}")
    for path in exported_all:
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
