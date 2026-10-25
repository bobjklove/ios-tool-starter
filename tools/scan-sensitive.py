#!/usr/bin/env python3
"""Scan source, documentation, and resources for private project material."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import sys

SKIP_DIRS = {".build", ".git", "DerivedData", "node_modules", "__pycache__", "Pods", "build", "dist"}
SKIP_SUFFIXES = {".xcodeproj", ".xcworkspace", ".framework", ".app"}

# Split spellings keep the scanner from matching its own rule table.
DENIED_WORDS = tuple("".join(parts) for parts in (
    ("Size", "Sheet"), ("ID", "Copy"), ("Pin", "Dou"), ("Mel", "tdown"), ("Brain", "Quit"),
))
ALLOWED_TEMPLATE_BUNDLES = {"com.example." + "toolstarter", "com.example." + "toolstarter.local",
                            "com.example." + "toolstarter.unlock"}
PATTERNS = {
    "private_key_or_certificate": re.compile(r"-----BEGIN (?:[A-Z ]*PRIVATE KEY|CERTIFICATE)-----", re.I),
    "chinese_phone": re.compile(r"(?<!\d)1[3-9]\d{9}(?!\d)"),
    "email_address": re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I),
    "identity_number": re.compile(r"(?<!\d)\d{17}[0-9Xx](?!\d)"),
    "old_bundle_prefix": re.compile(r"\bcom\.weifan\.[A-Za-z0-9_.-]+", re.I),
    "credential_assignment": re.compile(r"(?i)\b(?:password|passwd|token|secret|api[_-]?key)\s*[:=]\s*['\"]?\S{8,}"),
    "private_connection": re.compile(r"(?i)\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?)://[^\s<>]+"),
    "long_hex_value": re.compile(r"(?<![A-Za-z0-9])[A-Fa-f0-9]{40,}(?![A-Za-z0-9])"),
}


def files_under(root: Path):
    for parent, directories, filenames in os.walk(root):
        directories[:] = sorted(name for name in directories
                                if name not in SKIP_DIRS
                                and not any(name.endswith(suffix) for suffix in SKIP_SUFFIXES)
                                and not (Path(parent) / name).is_symlink())
        for name in sorted(filenames):
            path = Path(parent) / name
            if not path.is_symlink():
                yield path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--deny", action="append", default=[], help="additional exact product or client term")
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        parser.error("root must be an existing directory")
    rules = list(PATTERNS.items()) + [(f"forbidden_term_{index}", re.compile(re.escape(word), re.I))
                                      for index, word in enumerate((*DENIED_WORDS, *args.deny), 1)]
    count = 0
    findings: list[str] = []
    for path in files_under(root):
        count += 1
        try:
            lines = path.read_bytes().decode("utf-8").splitlines()
        except UnicodeDecodeError:
            # Latin-1 preserves ASCII strings embedded in PNG, PDF, and other resources.
            lines = path.read_bytes().decode("latin-1").splitlines()
        for number, line in enumerate(lines, 1):
            for label, pattern in rules:
                if label == "long_hex_value" and re.search(r"\b(?:sha-?256|sha-?1|checksum|fingerprint)\b", line, re.I):
                    continue
                matches = list(pattern.finditer(line))
                if label == "old_bundle_prefix":
                    matches = [match for match in matches if match.group(0).lower() not in ALLOWED_TEMPLATE_BUNDLES]
                if matches:
                    findings.append(f"{path.relative_to(root)}:{number}: {label}")
    for finding in findings:
        print(finding, file=sys.stderr)
    print(f"Scanned {count} text files; {len(findings)} finding(s).")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
