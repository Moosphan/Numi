#!/usr/bin/env python3
"""Fail when production Swift sources contain hardcoded Chinese UI text."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ROOTS = [
    Path("App/NumiApp"),
    Path("Sources/NumiAppUI"),
    Path("Sources/NumiCore"),
    Path("Sources/NumiPersistence"),
    Path("NumiIntents"),
]

DEFAULT_EXCLUDES = [
    "App/NumiUITests/",
    "Tests/",
    "Sources/NumiAppUI/PreviewSupport/",
    "Sources/NumiAppUI/Assets/ThiingsIcons/UsageExample.swift",
    "Sources/NumiAppUI/Assets/ThiingsIcons/CategoryIconPreview.swift",
    "Sources/NumiCore/AI/",
    "Sources/NumiPersistence/DemoDataSeeder.swift",
]

STRING_LITERAL_PATTERN = re.compile(r'"(?:[^"\\]|\\.)*[\u4e00-\u9fff]+(?:[^"\\]|\\.)*"')


def should_exclude(path: Path, excludes: list[str]) -> bool:
    normalized = path.as_posix()
    return any(normalized.startswith(prefix.rstrip("/")) for prefix in excludes)


def scan_file(path: Path) -> list[str]:
    hits: list[str] = []
    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        if line.lstrip().startswith("//"):
            continue
        if STRING_LITERAL_PATTERN.search(line):
            hits.append(f"{path}:{lineno}: {line.strip()}")
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("roots", nargs="*", type=Path, default=DEFAULT_ROOTS)
    parser.add_argument("--exclude", action="append", default=DEFAULT_EXCLUDES)
    args = parser.parse_args()

    findings: list[str] = []
    for root in args.roots:
        if root.is_file():
            candidates = [root]
        else:
            candidates = sorted(root.rglob("*.swift"))
        for path in candidates:
            if should_exclude(path, args.exclude):
                continue
            findings.extend(scan_file(path))

    if findings:
        for finding in findings:
            print(f"error: {finding}", file=sys.stderr)
        print(
            "\nFound hardcoded Chinese string literals in production Swift sources. "
            "Move them into localization catalogs or extend the allowlist if intentional.",
            file=sys.stderr,
        )
        return 1

    print(
        f"Hardcoded Chinese check passed: scanned {len(args.roots)} roots, "
        f"excluded {len(args.exclude)} path prefixes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
