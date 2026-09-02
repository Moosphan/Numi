from __future__ import annotations

import os
import subprocess
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


def run_verify(tmp_path: Path, stages: str, statuses: dict[str, int]) -> tuple[subprocess.CompletedProcess[str], list[str]]:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls_path = tmp_path / "calls.txt"

    for command, status in statuses.items():
        executable = fake_bin / command
        executable.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s %s\\n' \"$(basename \"$0\")\" \"$*\" >> \"$NUMI_VERIFY_CALLS\"\n"
            f"exit {status}\n"
        )
        executable.chmod(0o755)

    result = subprocess.run(
        ["bash", "scripts/verify.sh"],
        cwd=REPOSITORY_ROOT,
        env={
            **os.environ,
            "NUMI_VERIFY_STAGES": stages,
            "NUMI_VERIFY_CALLS": str(calls_path),
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
        },
        capture_output=True,
        text=True,
    )
    calls = calls_path.read_text().splitlines() if calls_path.exists() else []
    return result, calls


def test_selected_stages_run_in_order(tmp_path: Path):
    result, calls = run_verify(
        tmp_path,
        "swift-test,localization",
        {"swift": 0, "python3": 0},
    )

    assert result.returncode == 0, result.stderr
    assert calls == ["swift test", "python3 scripts/check_localization.py --allow-duplicates"]
    assert "== [swift-test] Swift package tests ==" in result.stdout
    assert "== [localization] Localization catalog validation ==" in result.stdout


def test_failed_stage_is_reported_and_stops_later_stages(tmp_path: Path):
    result, calls = run_verify(
        tmp_path,
        "swift-test,localization",
        {"swift": 19, "python3": 0},
    )

    assert result.returncode == 19
    assert calls == ["swift test"]
    assert "== [swift-test] Swift package tests FAILED ==" in result.stderr
    assert "Verification stopped at stage: Swift package tests" in result.stderr


def test_checked_in_xcode_project_is_not_regenerated(tmp_path: Path):
    result, calls = run_verify(
        tmp_path,
        "xcode-project",
        {"ruby": 0},
    )

    assert result.returncode == 0, result.stderr
    assert calls == []
    assert "Using checked-in Xcode project; generation skipped." in result.stdout


def test_ui_tests_wait_for_the_simulator_to_boot(tmp_path: Path):
    result, calls = run_verify(
        tmp_path,
        "ui-tests",
        {"xcrun": 0, "xcodebuild": 0},
    )

    assert result.returncode == 0, result.stderr
    assert calls[:2] == [
        "xcrun simctl boot iPhone 15",
        "xcrun simctl bootstatus iPhone 15 -b",
    ]
    assert calls[2].startswith("xcodebuild -project Numi.xcodeproj")
