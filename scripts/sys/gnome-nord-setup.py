#!/usr/bin/env python3
# file: scripts/sys/gnome-nord-setup.py
#
# /** Domain: Contract: Fail-Fast: SideEffect: */
# - Domain: GNOME(사용자 세션)에서 Nord 기반 UI/터미널 테마를 gsettings로 적용한다.
# - Contract:
#   - Linux + GNOME(gsettings) 환경에서만 동작
#   - 패키지 설치(apt)는 여기서 하지 않는다(SSOT: scripts/sys/bootstrap.sh)
#   - 배경화면 소스는 LEGION_SETUP_ROOT/background/background.jpg 로 고정(호출 cwd에 의존하지 않음)
# - Fail-Fast: 전제조건/키 부재/프로필 UUID 불일치 시 즉시 예외
# - SideEffect: gsettings write(테마/폰트/dash-to-dock/배경/터미널 팔레트)

from __future__ import annotations

import os
import sys
import subprocess
from dataclasses import dataclass
from pathlib import Path


# =============================================================================
# SSOT (Top-level constants only; derived must be computed, not input)
# =============================================================================
NORD = {
    "nord0":  "#2E3440",
    "nord1":  "#3B4252",
    "nord2":  "#434C5E",
    "nord3":  "#4C566A",
    "nord4":  "#D8DEE9",
    "nord5":  "#E5E9F0",
    "nord6":  "#ECEFF4",
    "nord7":  "#8FBCBB",
    "nord8":  "#88C0D0",
    "nord9":  "#81A1C1",
    "nord10": "#5E81AC",
    "nord11": "#BF616A",
    "nord12": "#D08770",
    "nord13": "#EBCB8B",
    "nord14": "#A3BE8C",
    "nord15": "#B48EAD",
}

PALETTE16 = [
    NORD["nord1"], NORD["nord11"], NORD["nord14"], NORD["nord13"],
    NORD["nord9"], NORD["nord15"], NORD["nord8"], NORD["nord5"],
    NORD["nord3"], NORD["nord11"], NORD["nord14"], NORD["nord13"],
    NORD["nord9"], NORD["nord15"], NORD["nord7"], NORD["nord6"],
]


# =============================================================================
# Utilities (IO/Adapter)
# =============================================================================
def _run_or_throw(cmd: list[str]) -> str:
    out = subprocess.check_output(cmd, text=True)
    return out.strip()


def _call_or_throw(cmd: list[str]) -> None:
    subprocess.check_call(cmd)


def _must_cmd_or_throw(cmd: str) -> None:
    if subprocess.call(["which", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) != 0:
        raise RuntimeError(f"[Contract] required command not found: {cmd}")


def _gs_get_or_throw(schema: str, key: str) -> str:
    return _run_or_throw(["gsettings", "get", schema, key])


def _gs_set_or_throw(schema: str, key: str, value_literal: str) -> None:
    _call_or_throw(["gsettings", "set", schema, key, value_literal])


def _quote_gvariant_str(value: str) -> str:
    # Contract: gsettings set string literal must be single-quoted
    # Fail-Fast: escape is not supported; keep input SSOT-only
    if "'" in value:
        raise RuntimeError(f"[Contract] single-quote is not allowed in gsettings string literal: {value}")
    return f"'{value}'"


def _quote_gvariant_str_list(values: list[str]) -> str:
    return "[" + ", ".join(_quote_gvariant_str(v) for v in values) + "]"


# =============================================================================
# Domain (Business)
# =============================================================================
@dataclass(frozen=True)
class GnomeNordSetupContext:
    root_path: Path
    background_src: Path


def _build_context_or_throw() -> GnomeNordSetupContext:
    # Contract: Platform
    if sys.platform != "linux":
        raise RuntimeError("[Contract] this script runs only on Linux (GNOME session expected)")

    # Contract: commands (minimal)
    for c in ["gsettings", "dconf"]:
        _must_cmd_or_throw(c)

    root_dir = os.environ.get("LEGION_SETUP_ROOT")
    if not root_dir:
        raise RuntimeError("[Contract] LEGION_SETUP_ROOT required")

    root_path = Path(root_dir)
    background_src = root_path / "background" / "background.jpg"
    if not background_src.exists():
        raise FileNotFoundError(f"[Contract] background source not found: {background_src}")

    return GnomeNordSetupContext(root_path=root_path, background_src=background_src)


def _get_gnome_terminal_default_profile_uuid_or_throw() -> str:
    default_uuid = _gs_get_or_throw("org.gnome.Terminal.ProfilesList", "default").strip().strip("'")
    if not default_uuid:
        raise RuntimeError("[Fail-Fast] GNOME Terminal default profile UUID is empty")

    # list is a GVariant array of strings: ['uuid1', 'uuid2', ...]
    raw = _gs_get_or_throw("org.gnome.Terminal.ProfilesList", "list").strip()
    # Fail-Fast: cheap parse with strict token check (not substring)
    token = _quote_gvariant_str(default_uuid)
    if token not in raw.replace(" ", "") and token not in raw:
        raise RuntimeError(
            "[Fail-Fast] GNOME Terminal profile UUID not found in profile list. "
            "Open GNOME Terminal once and retry."
        )

    return default_uuid


def _apply_gnome_ui_theme_and_font_or_throw() -> None:
    print("[INFO] GNOME 다크모드 + 폰트 설정")
    _gs_set_or_throw("org.gnome.desktop.interface", "color-scheme", _quote_gvariant_str("prefer-dark"))
    _gs_set_or_throw("org.gnome.desktop.interface", "monospace-font-name", _quote_gvariant_str("JetBrains Mono 12"))


def _apply_dash_to_dock_bottom_center_or_throw() -> None:
    # Domain: dash-to-dock 확장 존재가 전제. 없으면 바로 실패.
    print("[INFO] Dock 하단-가운데 정렬 (dash-to-dock 전제)")
    # Fail-Fast: schema 접근 가능 여부를 먼저 확인해 메시지 품질 확보
    try:
        _gs_get_or_throw("org.gnome.shell.extensions.dash-to-dock", "dock-position")
    except Exception as e:
        raise RuntimeError("[Contract] dash-to-dock schema not available. Install/enable dash-to-dock first.") from e

    _gs_set_or_throw("org.gnome.shell.extensions.dash-to-dock", "dock-position", _quote_gvariant_str("BOTTOM"))
    _gs_set_or_throw("org.gnome.shell.extensions.dash-to-dock", "extend-height", "false")


def _apply_background_or_throw(ctx: GnomeNordSetupContext) -> None:
    print("[INFO] background.jpg 파일 설정")

    bg_dir = Path.home() / ".local" / "share" / "backgrounds"
    bg_dir.mkdir(parents=True, exist_ok=True)

    dst = bg_dir / "background.jpg"
    dst.write_bytes(ctx.background_src.read_bytes())

    uri = f"file://{dst}"
    _gs_set_or_throw("org.gnome.desktop.background", "picture-uri", _quote_gvariant_str(uri))
    _gs_set_or_throw("org.gnome.desktop.background", "picture-uri-dark", _quote_gvariant_str(uri))
    _gs_set_or_throw("org.gnome.desktop.background", "picture-options", _quote_gvariant_str("zoom"))


def _apply_gnome_terminal_nord_palette_or_throw() -> None:
    print("[INFO] GNOME Terminal Nord 팔레트 적용")

    default_uuid = _get_gnome_terminal_default_profile_uuid_or_throw()
    profile_path = f"/org/gnome/terminal/legacy/profiles:/:{default_uuid}/"
    schema_with_path = f"org.gnome.Terminal.Legacy.Profile:{profile_path}"

    def term_set(key: str, value_literal: str) -> None:
        _call_or_throw(["gsettings", "set", schema_with_path, key, value_literal])

    palette_gsettings = _quote_gvariant_str_list(PALETTE16)

    bg = NORD["nord0"]
    fg = NORD["nord4"]
    bold = NORD["nord6"]
    cursor_fg = NORD["nord0"]
    cursor_bg = NORD["nord4"]

    term_set("use-theme-colors", "false")
    term_set("palette", palette_gsettings)
    term_set("background-color", _quote_gvariant_str(bg))
    term_set("foreground-color", _quote_gvariant_str(fg))
    term_set("bold-color-same-as-fg", "false")
    term_set("bold-color", _quote_gvariant_str(bold))
    term_set("cursor-colors-set", "true")
    term_set("cursor-foreground-color", _quote_gvariant_str(cursor_fg))
    term_set("cursor-background-color", _quote_gvariant_str(cursor_bg))
    term_set("use-transparent-background", "false")
    term_set("visible-name", _quote_gvariant_str("Nord"))


def gnome_nord_setup_main() -> None:
    # Contract: validate once at entry
    ctx = _build_context_or_throw()

    # SideEffect: grouped, explicit
    _apply_gnome_ui_theme_and_font_or_throw()
    _apply_dash_to_dock_bottom_center_or_throw()
    _apply_background_or_throw(ctx)
    _apply_gnome_terminal_nord_palette_or_throw()

    print("\n[OK] Nord 테마, Dock, 배경화면(background.jpg), 폰트, 터미널 컬러 설정 완료!")
    print("GNOME Shell 재시작(Alt+F2 → r → Enter) 또는 재로그인을 권장합니다.")


if __name__ == "__main__":
    gnome_nord_setup_main()
