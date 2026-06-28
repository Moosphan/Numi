from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path


def load_check_localization_module():
    script_path = Path(__file__).resolve().parents[1] / "check_localization.py"
    spec = importlib.util.spec_from_file_location("check_localization", script_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def test_duplicate_report_groups_catalog_owners_and_source_usage(tmp_path: Path):
    module = load_check_localization_module()

    app_catalog = tmp_path / "App" / "NumiApp" / "Localizable.xcstrings"
    appui_catalog = tmp_path / "Sources" / "NumiAppUI" / "Localizable.xcstrings"
    app_source = tmp_path / "App" / "NumiApp" / "RootShellView.swift"
    appui_source = tmp_path / "Sources" / "NumiAppUI" / "Pages" / "SettingsView.swift"
    core_source = tmp_path / "Sources" / "NumiCore" / "NumiTheme.swift"
    persistence_source = tmp_path / "Sources" / "NumiPersistence" / "SwiftDataBookkeepingStore.swift"

    for path in [app_catalog, appui_catalog, app_source, appui_source, core_source, persistence_source]:
        path.parent.mkdir(parents=True, exist_ok=True)

    catalog_payload = {
        "sourceLanguage": "en",
        "strings": {
            "setting.data": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Data"}}
                }
            },
            "setting.ai.enter.key": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Enter API Key"}}
                }
            },
            "subscription.delete.confirm": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Delete subscription"}}
                }
            },
            "theme.default": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Default"}}
                }
            },
        },
    }
    app_catalog.write_text(json.dumps(catalog_payload))
    appui_catalog.write_text(json.dumps(catalog_payload))

    app_source.write_text('Text("setting.data")\n')
    appui_source.write_text(
        'let title = NumiLocalized.string("setting.data")\n'
        'let placeholder = "setting.ai.enter.key \\(providerName)"\n'
        'let dialog = "subscription.delete.confirm \\(name)"\n'
    )
    core_source.write_text('let title = NumiLocalized.string("theme.default")\n')
    persistence_source.write_text('let title = NumiLocalized.string("theme.default")\n')

    report = module.build_duplicate_usage_report(
        [app_catalog, appui_catalog],
        [tmp_path / "App", tmp_path / "Sources"],
    )

    assert report["duplicate_key_count"] == 4
    assert report["keys"]["setting.data"]["catalog_owners"] == ["App", "AppUI"]
    assert report["keys"]["setting.data"]["source_usage"]["App"] == ["App/NumiApp/RootShellView.swift"]
    assert report["keys"]["setting.data"]["source_usage"]["AppUI"] == ["Sources/NumiAppUI/Pages/SettingsView.swift"]
    assert report["keys"]["setting.ai.enter.key"]["source_usage"]["AppUI"] == ["Sources/NumiAppUI/Pages/SettingsView.swift"]
    assert report["keys"]["subscription.delete.confirm"]["source_usage"]["AppUI"] == ["Sources/NumiAppUI/Pages/SettingsView.swift"]
    assert report["keys"]["theme.default"]["source_usage"]["Core"] == ["Sources/NumiCore/NumiTheme.swift"]
    assert report["keys"]["theme.default"]["source_usage"]["Persistence"] == ["Sources/NumiPersistence/SwiftDataBookkeepingStore.swift"]


def test_runtime_risk_scan_flags_localized_key_storage_and_interpolated_literals(tmp_path: Path):
    module = load_check_localization_module()

    settings_source = tmp_path / "Sources" / "NumiAppUI" / "Pages" / "SettingsView.swift"
    settings_source.parent.mkdir(parents=True, exist_ok=True)
    settings_source.write_text(
        "import SwiftUI\n"
        "struct LangOption { let key: LocalizedStringKey }\n"
        'let placeholder = "setting.ai.enter.key \\(providerName)"\n'
        'let title = NumiLocalized.string("setting.data")\n'
        'Text("setting.data")\n'
    )

    risks = module.find_runtime_localization_risks([tmp_path / "Sources"])

    assert risks == [
        "Sources/NumiAppUI/Pages/SettingsView.swift: localized interpolation literal for key 'setting.ai.enter.key'",
        "Sources/NumiAppUI/Pages/SettingsView.swift: stores LocalizedStringKey/LocalizedStringResource outside direct SwiftUI view construction",
    ]


def test_runtime_risk_scan_flags_behavior_comparison_against_localized_strings(tmp_path: Path):
    module = load_check_localization_module()

    source = tmp_path / "Sources" / "NumiAppUI" / "Components" / "NumiAmountKeypad.swift"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(
        "import SwiftUI\n"
        'if resolvedTitle == NumiLocalized.string("date.today") { return "today" }\n'
    )

    risks = module.find_runtime_localization_risks([tmp_path / "Sources"])

    assert risks == [
        "Sources/NumiAppUI/Components/NumiAmountKeypad.swift: compares behavior-critical values against localized display strings",
    ]


def test_runtime_risk_scan_flags_failure_string_payloads_in_runtime_sources(tmp_path: Path):
    module = load_check_localization_module()

    source = tmp_path / "Sources" / "NumiCore" / "BackupService.swift"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(
        "import Foundation\n"
        "enum BackupResult {\n"
        "    case success(URL)\n"
        "    case failure(String)\n"
        "}\n"
    )

    risks = module.find_runtime_localization_risks([tmp_path / "Sources"])

    assert risks == [
        "Sources/NumiCore/BackupService.swift: stores failure(String) payloads instead of semantic error state",
    ]


def test_runtime_risk_scan_flags_captured_localized_strings_in_stored_properties_and_state(tmp_path: Path):
    module = load_check_localization_module()

    source = tmp_path / "Sources" / "NumiAppUI" / "Pages" / "SettingsView.swift"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(
        "import SwiftUI\n"
        "struct SettingsView {\n"
        '    private let title = NumiLocalized.string("setting.data")\n'
        '    @State private var toastMessage = NumiLocalized.string("io.saved")\n'
        "}\n"
    )

    risks = module.find_runtime_localization_risks([tmp_path / "Sources"])

    assert risks == [
        "Sources/NumiAppUI/Pages/SettingsView.swift: captures localized strings into @State instead of recomputing from current language",
        "Sources/NumiAppUI/Pages/SettingsView.swift: captures localized strings into stored properties instead of recomputing from current language",
    ]


def test_runtime_risk_scan_flags_localized_accessibility_identifier_interpolation(tmp_path: Path):
    module = load_check_localization_module()

    source = tmp_path / "Sources" / "NumiAppUI" / "Pages" / "AddRecordView.swift"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(
        "import SwiftUI\n"
        'Text(category.localizedDisplayName).accessibilityIdentifier("category.\\(category.localizedDisplayName)")\n'
        'Text(row.categoryName).accessibilityIdentifier("record.\\(row.categoryName)")\n'
    )

    risks = module.find_runtime_localization_risks([tmp_path / "Sources"])

    assert risks == [
        "Sources/NumiAppUI/Pages/AddRecordView.swift: localized accessibility identifier interpolation uses 'category.localizedDisplayName'",
        "Sources/NumiAppUI/Pages/AddRecordView.swift: localized accessibility identifier interpolation uses 'row.categoryName'",
    ]


def test_cli_can_write_duplicate_report_json(tmp_path: Path):
    script_path = Path(__file__).resolve().parents[1] / "check_localization.py"
    catalog = tmp_path / "App" / "NumiApp" / "Localizable.xcstrings"
    source = tmp_path / "App" / "NumiApp" / "RootShellView.swift"
    report_path = tmp_path / "duplicate-report.json"

    catalog.parent.mkdir(parents=True, exist_ok=True)
    source.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "sourceLanguage": "en",
        "strings": {
            "setting.data": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Data"}}
                }
            }
        },
    }
    catalog.write_text(json.dumps(payload))
    source.write_text('Text("setting.data")\n')

    result = subprocess.run(
        [
            sys.executable,
            str(script_path),
            str(catalog),
            "--locales",
            "en",
            "--duplicate-report-json",
            str(report_path),
            "--source-roots",
            str(tmp_path / "App"),
        ],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert report_path.exists()
    report = json.loads(report_path.read_text())
    assert report["keys"] == {}


def test_cli_fails_on_duplicate_keys_by_default(tmp_path: Path):
    script_path = Path(__file__).resolve().parents[1] / "check_localization.py"
    app_catalog = tmp_path / "App" / "NumiApp" / "Localizable.xcstrings"
    appui_catalog = tmp_path / "Sources" / "NumiAppUI" / "Localizable.xcstrings"

    app_catalog.parent.mkdir(parents=True, exist_ok=True)
    appui_catalog.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "sourceLanguage": "en",
        "strings": {
            "setting.data": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Data"}}
                }
            }
        },
    }
    app_catalog.write_text(json.dumps(payload))
    appui_catalog.write_text(json.dumps(payload))

    result = subprocess.run(
        [
            sys.executable,
            str(script_path),
            str(app_catalog),
            str(appui_catalog),
            "--locales",
            "en",
        ],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 1
    assert "duplicate key setting.data" in result.stderr


def test_cli_fails_on_runtime_localization_risks(tmp_path: Path):
    script_path = Path(__file__).resolve().parents[1] / "check_localization.py"
    catalog = tmp_path / "Sources" / "NumiAppUI" / "Localizable.xcstrings"
    source = tmp_path / "Sources" / "NumiAppUI" / "Pages" / "SettingsView.swift"

    catalog.parent.mkdir(parents=True, exist_ok=True)
    source.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "sourceLanguage": "en",
        "strings": {
            "setting.ai.enter.key": {
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": "Enter %@ API Key"}}
                }
            }
        },
    }
    catalog.write_text(json.dumps(payload))
    source.write_text(
        "import SwiftUI\n"
        "struct LangOption { let key: LocalizedStringKey }\n"
        'let placeholder = "setting.ai.enter.key \\(providerName)"\n'
    )

    result = subprocess.run(
        [
            sys.executable,
            str(script_path),
            str(catalog),
            "--locales",
            "en",
            "--source-roots",
            str(tmp_path / "Sources"),
            "--runtime-source-roots",
            str(tmp_path / "Sources"),
        ],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 1
    assert "localized interpolation literal for key 'setting.ai.enter.key'" in result.stderr
    assert "stores LocalizedStringKey/LocalizedStringResource" in result.stderr
