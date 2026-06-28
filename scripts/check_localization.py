#!/usr/bin/env python3
"""Validate Numi string catalogs for runtime localization readiness."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path


DEFAULT_CATALOGS = [
    Path("App/NumiApp/Localizable.xcstrings"),
    Path("Sources/NumiAppUI/Localizable.xcstrings"),
    Path("Sources/NumiCore/Localizable.xcstrings"),
    Path("NumiIntents/Localizable.xcstrings"),
]
DEFAULT_LOCALES = ["zh-Hans", "en", "zh-Hant", "ja"]
DEFAULT_SOURCE_ROOTS = [Path("App"), Path("Sources"), Path("NumiIntents")]
PLACEHOLDER_PATTERN = re.compile(r"%(?:\d+\$)?(?:[-+#0 ]*\d*(?:\.\d+)?)?(?:lld|ld|d|@|f|s)")
LOCALIZATION_KEY_PATTERN = re.compile(
    r'"([A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)+)(?:"|\s*\\\()'
)
LOCALIZATION_INTERPOLATION_PATTERN = re.compile(
    r'"([A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)+)\s*\\\('
)
LOCALIZED_RESOURCE_STORAGE_PATTERN = re.compile(r"\bLocalizedString(?:Key|Resource)\b")
FAILURE_STRING_CASE_PATTERN = re.compile(r"\bcase\s+failure\s*\(\s*String\s*\)")
LOCALIZED_STRING_CAPTURE_PATTERN = re.compile(
    r'^\s*(?:(?:private|public|internal|fileprivate)\s+(?:static\s+)?(?:let|var)|static\s+let|static\s+var)\s+\w+[^=]*=\s*NumiLocalized\.string\(',
    re.MULTILINE,
)
LOCALIZED_STRING_STATE_CAPTURE_PATTERN = re.compile(
    r'@State(?:Object)?[^\n]*=\s*NumiLocalized\.string\('
)
LOCALIZED_STRING_STATE_INITIALIZER_PATTERN = re.compile(
    r'State\s*\(\s*initialValue:\s*NumiLocalized\.string\('
)
ACCESSIBILITY_IDENTIFIER_INTERPOLATION_PATTERN = re.compile(
    r'accessibilityIdentifier\(\s*"[^"]*\\\(([^)]+)\)[^"]*"\s*\)'
)
LOCALIZED_STRING_COMPARISON_PATTERN = re.compile(
    r'(?:==|!=)\s*NumiLocalized\.string\(|NumiLocalized\.string\([^)]*\)\s*(?:==|!=)'
)
UNSTABLE_ACCESSIBILITY_IDENTIFIER_FRAGMENTS = (
    "localizedDisplayName",
    "categoryName",
    ".name",
    "title",
)


def localized_value(entry: dict, locale: str) -> str | None:
    unit = entry.get("localizations", {}).get(locale, {}).get("stringUnit")
    if not unit:
        return None
    value = unit.get("value")
    if not isinstance(value, str) or value == "":
        return None
    return value


def placeholder_count(value: str) -> int:
    return len(PLACEHOLDER_PATTERN.findall(value))


def check_catalog(path: Path, locales: list[str]) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text())

    for key, entry in sorted(data.get("strings", {}).items()):
        values = {locale: localized_value(entry, locale) for locale in locales}
        for locale, value in values.items():
            if value is None:
                errors.append(f"{path}: missing {locale} value for {key}")

        present_values = {locale: value for locale, value in values.items() if value is not None}
        if len(present_values) < 2:
            continue

        counts = {locale: placeholder_count(value) for locale, value in present_values.items()}
        if len(set(counts.values())) > 1:
            summary = ", ".join(f"{locale}={count}" for locale, count in counts.items())
            errors.append(f"{path}: placeholder mismatch for {key}: {summary}")

    return errors


def duplicate_warnings(paths: list[Path]) -> list[str]:
    owners = duplicate_key_owners(paths)

    warnings: list[str] = []
    for key, key_owners in sorted(owners.items()):
        if len(key_owners) > 1:
            warnings.append(f"duplicate key {key}: {' | '.join(key_owners)}")
    return warnings


def duplicate_key_owners(paths: list[Path]) -> dict[str, list[str]]:
    owners: dict[str, list[str]] = defaultdict(list)
    for path in paths:
        data = json.loads(path.read_text())
        for key in data.get("strings", {}):
            owners[key].append(str(path))
    return owners


def catalog_owner_name(path: Path) -> str:
    parts = path.parts
    if "App" in parts:
        return "App"
    if "NumiAppUI" in parts:
        return "AppUI"
    if "NumiCore" in parts:
        return "Core"
    if "NumiPersistence" in parts:
        return "Persistence"
    if "NumiIntents" in parts:
        return "Intents"
    path_str = path.as_posix()
    return parts[0] if parts else path_str


def source_owner_name(path: Path) -> str:
    return catalog_owner_name(path)


def find_source_key_usage(source_roots: list[Path]) -> dict[str, dict[str, list[str]]]:
    key_usage: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    existing_roots = [root for root in source_roots if root.exists()]
    if not existing_roots:
        return {}

    common_root = Path(os.path.commonpath([str(root.resolve().parent) for root in existing_roots]))
    for root in existing_roots:
        for swift_file in root.rglob("*.swift"):
            text = swift_file.read_text()
            relative_path = swift_file.resolve().relative_to(common_root).as_posix()
            owner = source_owner_name(Path(relative_path))
            for key in LOCALIZATION_KEY_PATTERN.findall(text):
                key_usage[key][owner].add(relative_path)

    return {
        key: {
            owner: sorted(paths)
            for owner, paths in sorted(owners.items())
        }
        for key, owners in sorted(key_usage.items())
    }


def build_duplicate_usage_report(catalogs: list[Path], source_roots: list[Path]) -> dict:
    duplicate_owners = duplicate_key_owners(catalogs)
    source_usage = find_source_key_usage(source_roots)
    duplicate_keys = sorted(key for key, owners in duplicate_owners.items() if len(owners) > 1)

    report_keys = {}
    for key in duplicate_keys:
        report_keys[key] = {
            "catalog_paths": sorted(duplicate_owners[key]),
            "catalog_owners": sorted({catalog_owner_name(Path(path)) for path in duplicate_owners[key]}),
            "source_usage": source_usage.get(key, {}),
        }

    return {
        "duplicate_key_count": len(duplicate_keys),
        "keys": report_keys,
    }


def find_runtime_localization_risks(source_roots: list[Path]) -> list[str]:
    risks: set[str] = set()
    existing_roots = [root for root in source_roots if root.exists()]
    if not existing_roots:
        return []

    common_root = Path(os.path.commonpath([str(root.resolve().parent) for root in existing_roots]))
    for root in existing_roots:
        for swift_file in root.rglob("*.swift"):
            text = swift_file.read_text()
            relative_path = swift_file.resolve().relative_to(common_root).as_posix()

            for key in LOCALIZATION_INTERPOLATION_PATTERN.findall(text):
                risks.add(
                    f"{relative_path}: localized interpolation literal for key '{key}'"
                )

            if LOCALIZED_RESOURCE_STORAGE_PATTERN.search(text):
                risks.add(
                    f"{relative_path}: stores LocalizedStringKey/LocalizedStringResource outside direct SwiftUI view construction"
                )

            if FAILURE_STRING_CASE_PATTERN.search(text):
                risks.add(
                    f"{relative_path}: stores failure(String) payloads instead of semantic error state"
                )

            if LOCALIZED_STRING_CAPTURE_PATTERN.search(text):
                risks.add(
                    f"{relative_path}: captures localized strings into stored properties instead of recomputing from current language"
                )

            if LOCALIZED_STRING_STATE_CAPTURE_PATTERN.search(text) or LOCALIZED_STRING_STATE_INITIALIZER_PATTERN.search(text):
                risks.add(
                    f"{relative_path}: captures localized strings into @State instead of recomputing from current language"
                )

            if LOCALIZED_STRING_COMPARISON_PATTERN.search(text):
                risks.add(
                    f"{relative_path}: compares behavior-critical values against localized display strings"
                )

            for match in ACCESSIBILITY_IDENTIFIER_INTERPOLATION_PATTERN.finditer(text):
                expression = match.group(1).strip()
                if any(fragment in expression for fragment in UNSTABLE_ACCESSIBILITY_IDENTIFIER_FRAGMENTS):
                    risks.add(
                        f"{relative_path}: localized accessibility identifier interpolation uses '{expression}'"
                    )

    return sorted(risks)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalogs", nargs="*", type=Path, default=DEFAULT_CATALOGS)
    parser.add_argument("--locales", nargs="+", default=DEFAULT_LOCALES)
    parser.add_argument(
        "--allow-duplicates",
        action="store_true",
        help="Emit duplicate-key warnings without failing the command.",
    )
    parser.add_argument("--duplicate-report-json", type=Path)
    parser.add_argument("--source-roots", nargs="+", type=Path, default=DEFAULT_SOURCE_ROOTS)
    parser.add_argument(
        "--runtime-source-roots",
        nargs="+",
        type=Path,
    )
    args = parser.parse_args()

    errors: list[str] = []
    for catalog in args.catalogs:
        errors.extend(check_catalog(catalog, args.locales))

    warnings = duplicate_warnings(args.catalogs)
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)

    if not args.allow_duplicates:
        errors.extend(warnings)

    if args.duplicate_report_json:
        report = build_duplicate_usage_report(args.catalogs, args.source_roots)
        args.duplicate_report_json.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

    runtime_source_roots = args.runtime_source_roots
    if runtime_source_roots is None:
        runtime_source_roots = [root for root in args.source_roots if root.name != "NumiIntents"]

    errors.extend(find_runtime_localization_risks(runtime_source_roots))

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print(
        f"Localization check passed: {len(args.catalogs)} catalogs, "
        f"{len(args.locales)} locales, {len(warnings)} duplicate-key warnings."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
