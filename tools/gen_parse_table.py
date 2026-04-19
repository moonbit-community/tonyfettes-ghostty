#!/usr/bin/env python3

from __future__ import annotations

import pathlib


ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET = ROOT / "src/terminal/parse_table_data.mbt"

STATES = [
    "Ground",
    "Escape",
    "EscapeIntermediate",
    "CsiEntry",
    "CsiIntermediate",
    "CsiParam",
    "CsiIgnore",
    "DcsEntry",
    "DcsParam",
    "DcsIntermediate",
    "DcsPassthrough",
    "DcsIgnore",
    "OscString",
    "SosPmApcString",
]

ACTIONS = [
    "None",
    "Ignore",
    "Print",
    "Execute",
    "Collect",
    "Param",
    "EscDispatch",
    "CsiDispatch",
    "Put",
    "OscPut",
    "ApcPut",
]


def pack(state: str, action: str) -> int:
    return (STATES.index(state) << 4) | ACTIONS.index(action)


def build_table() -> list[int]:
    table: list[int | None] = [None] * (256 * len(STATES))

    def idx(byte: int, state: str) -> int:
        return byte * len(STATES) + STATES.index(state)

    def set_single(byte: int, source: str, target: str, action: str) -> None:
        index = idx(byte, source)
        table[index] = pack(target, action)

    def set_range(
        lower: int, upper: int, source: str, target: str, action: str
    ) -> None:
        for byte in range(lower, upper + 1):
            set_single(byte, source, target, action)

    for source in STATES:
        set_single(0x18, source, "Ground", "Execute")
        set_single(0x1A, source, "Ground", "Execute")
        set_range(0x80, 0x8F, source, "Ground", "Execute")
        set_range(0x91, 0x97, source, "Ground", "Execute")
        set_single(0x99, source, "Ground", "Execute")
        set_single(0x9A, source, "Ground", "Execute")
        set_single(0x9C, source, "Ground", "None")
        set_single(0x1B, source, "Escape", "None")
        set_single(0x98, source, "SosPmApcString", "None")
        set_single(0x9E, source, "SosPmApcString", "None")
        set_single(0x9F, source, "SosPmApcString", "None")
        set_single(0x9B, source, "CsiEntry", "None")
        set_single(0x90, source, "DcsEntry", "None")
        set_single(0x9D, source, "OscString", "None")

    set_single(0x19, "Ground", "Ground", "Execute")
    set_range(0x00, 0x17, "Ground", "Ground", "Execute")
    set_range(0x1C, 0x1F, "Ground", "Ground", "Execute")
    set_range(0x20, 0x7F, "Ground", "Ground", "Print")

    set_single(0x19, "EscapeIntermediate", "EscapeIntermediate", "Execute")
    set_range(0x00, 0x17, "EscapeIntermediate", "EscapeIntermediate", "Execute")
    set_range(0x1C, 0x1F, "EscapeIntermediate", "EscapeIntermediate", "Execute")
    set_range(0x20, 0x2F, "EscapeIntermediate", "EscapeIntermediate", "Collect")
    set_single(0x7F, "EscapeIntermediate", "EscapeIntermediate", "Ignore")
    set_range(0x30, 0x7E, "EscapeIntermediate", "Ground", "EscDispatch")

    set_single(0x19, "SosPmApcString", "SosPmApcString", "ApcPut")
    set_range(0x00, 0x17, "SosPmApcString", "SosPmApcString", "ApcPut")
    set_range(0x1C, 0x1F, "SosPmApcString", "SosPmApcString", "ApcPut")
    set_range(0x20, 0x7F, "SosPmApcString", "SosPmApcString", "ApcPut")

    set_single(0x19, "Escape", "Escape", "Execute")
    set_range(0x00, 0x17, "Escape", "Escape", "Execute")
    set_range(0x1C, 0x1F, "Escape", "Escape", "Execute")
    set_single(0x7F, "Escape", "Escape", "Ignore")
    set_range(0x30, 0x4F, "Escape", "Ground", "EscDispatch")
    set_range(0x51, 0x57, "Escape", "Ground", "EscDispatch")
    set_range(0x60, 0x7E, "Escape", "Ground", "EscDispatch")
    set_single(0x59, "Escape", "Ground", "EscDispatch")
    set_single(0x5A, "Escape", "Ground", "EscDispatch")
    set_single(0x5C, "Escape", "Ground", "EscDispatch")
    set_range(0x20, 0x2F, "Escape", "EscapeIntermediate", "Collect")
    set_single(0x58, "Escape", "SosPmApcString", "None")
    set_single(0x5E, "Escape", "SosPmApcString", "None")
    set_single(0x5F, "Escape", "SosPmApcString", "None")
    set_single(0x50, "Escape", "DcsEntry", "None")
    set_single(0x5B, "Escape", "CsiEntry", "None")
    set_single(0x5D, "Escape", "OscString", "None")

    set_single(0x19, "DcsEntry", "DcsEntry", "Ignore")
    set_range(0x00, 0x17, "DcsEntry", "DcsEntry", "Ignore")
    set_range(0x1C, 0x1F, "DcsEntry", "DcsEntry", "Ignore")
    set_single(0x7F, "DcsEntry", "DcsEntry", "Ignore")
    set_range(0x20, 0x2F, "DcsEntry", "DcsIntermediate", "Collect")
    set_single(0x3A, "DcsEntry", "DcsIgnore", "None")
    set_range(0x30, 0x39, "DcsEntry", "DcsParam", "Param")
    set_single(0x3B, "DcsEntry", "DcsParam", "Param")
    set_range(0x3C, 0x3F, "DcsEntry", "DcsParam", "Collect")
    set_range(0x40, 0x7E, "DcsEntry", "DcsPassthrough", "None")

    set_single(0x19, "DcsIntermediate", "DcsIntermediate", "Ignore")
    set_range(0x00, 0x17, "DcsIntermediate", "DcsIntermediate", "Ignore")
    set_range(0x1C, 0x1F, "DcsIntermediate", "DcsIntermediate", "Ignore")
    set_range(0x20, 0x2F, "DcsIntermediate", "DcsIntermediate", "Collect")
    set_single(0x7F, "DcsIntermediate", "DcsIntermediate", "Ignore")
    set_range(0x30, 0x3F, "DcsIntermediate", "DcsIgnore", "None")
    set_range(0x40, 0x7E, "DcsIntermediate", "DcsPassthrough", "None")

    set_single(0x19, "DcsIgnore", "DcsIgnore", "Ignore")
    set_range(0x00, 0x17, "DcsIgnore", "DcsIgnore", "Ignore")
    set_range(0x1C, 0x1F, "DcsIgnore", "DcsIgnore", "Ignore")

    set_single(0x19, "DcsParam", "DcsParam", "Ignore")
    set_range(0x00, 0x17, "DcsParam", "DcsParam", "Ignore")
    set_range(0x1C, 0x1F, "DcsParam", "DcsParam", "Ignore")
    set_range(0x30, 0x39, "DcsParam", "DcsParam", "Param")
    set_single(0x3B, "DcsParam", "DcsParam", "Param")
    set_single(0x7F, "DcsParam", "DcsParam", "Ignore")
    set_single(0x3A, "DcsParam", "DcsIgnore", "None")
    set_range(0x3C, 0x3F, "DcsParam", "DcsIgnore", "None")
    set_range(0x20, 0x2F, "DcsParam", "DcsIntermediate", "Collect")
    set_range(0x40, 0x7E, "DcsParam", "DcsPassthrough", "None")

    set_single(0x19, "DcsPassthrough", "DcsPassthrough", "Put")
    set_range(0x00, 0x17, "DcsPassthrough", "DcsPassthrough", "Put")
    set_range(0x1C, 0x1F, "DcsPassthrough", "DcsPassthrough", "Put")
    set_range(0x20, 0x7E, "DcsPassthrough", "DcsPassthrough", "Put")
    set_single(0x7F, "DcsPassthrough", "DcsPassthrough", "Ignore")

    set_single(0x19, "CsiParam", "CsiParam", "Execute")
    set_range(0x00, 0x17, "CsiParam", "CsiParam", "Execute")
    set_range(0x1C, 0x1F, "CsiParam", "CsiParam", "Execute")
    set_range(0x30, 0x39, "CsiParam", "CsiParam", "Param")
    set_single(0x3A, "CsiParam", "CsiParam", "Param")
    set_single(0x3B, "CsiParam", "CsiParam", "Param")
    set_single(0x7F, "CsiParam", "CsiParam", "Ignore")
    set_range(0x40, 0x7E, "CsiParam", "Ground", "CsiDispatch")
    set_range(0x3C, 0x3F, "CsiParam", "CsiIgnore", "None")
    set_range(0x20, 0x2F, "CsiParam", "CsiIntermediate", "Collect")

    set_single(0x19, "CsiIgnore", "CsiIgnore", "Execute")
    set_range(0x00, 0x17, "CsiIgnore", "CsiIgnore", "Execute")
    set_range(0x1C, 0x1F, "CsiIgnore", "CsiIgnore", "Execute")
    set_range(0x20, 0x3F, "CsiIgnore", "CsiIgnore", "Ignore")
    set_single(0x7F, "CsiIgnore", "CsiIgnore", "Ignore")
    set_range(0x40, 0x7E, "CsiIgnore", "Ground", "None")

    set_single(0x19, "CsiIntermediate", "CsiIntermediate", "Execute")
    set_range(0x00, 0x17, "CsiIntermediate", "CsiIntermediate", "Execute")
    set_range(0x1C, 0x1F, "CsiIntermediate", "CsiIntermediate", "Execute")
    set_range(0x20, 0x2F, "CsiIntermediate", "CsiIntermediate", "Collect")
    set_single(0x7F, "CsiIntermediate", "CsiIntermediate", "Ignore")
    set_range(0x40, 0x7E, "CsiIntermediate", "Ground", "CsiDispatch")
    set_range(0x30, 0x3F, "CsiIntermediate", "CsiIgnore", "None")

    set_single(0x19, "CsiEntry", "CsiEntry", "Execute")
    set_range(0x00, 0x17, "CsiEntry", "CsiEntry", "Execute")
    set_range(0x1C, 0x1F, "CsiEntry", "CsiEntry", "Execute")
    set_single(0x7F, "CsiEntry", "CsiEntry", "Ignore")
    set_range(0x40, 0x7E, "CsiEntry", "Ground", "CsiDispatch")
    set_single(0x3A, "CsiEntry", "CsiIgnore", "None")
    set_range(0x20, 0x2F, "CsiEntry", "CsiIntermediate", "Collect")
    set_range(0x30, 0x39, "CsiEntry", "CsiParam", "Param")
    set_single(0x3B, "CsiEntry", "CsiParam", "Param")
    set_range(0x3C, 0x3F, "CsiEntry", "CsiParam", "Collect")

    set_single(0x19, "OscString", "OscString", "Ignore")
    set_range(0x00, 0x06, "OscString", "OscString", "Ignore")
    set_range(0x08, 0x17, "OscString", "OscString", "Ignore")
    set_range(0x1C, 0x1F, "OscString", "OscString", "Ignore")
    set_range(0x20, 0xFF, "OscString", "OscString", "OscPut")
    set_single(0x07, "OscString", "Ground", "None")

    final: list[int] = []
    for byte in range(256):
        for state in STATES:
            value = table[idx(byte, state)]
            if value is None:
                value = pack(state, "None")
            final.append(value)
    return final


def render(table: list[int]) -> str:
    out: list[str] = []
    out.append("///|")
    out.append("/// Generated by `python3 tools/gen_parse_table.py`. Do not edit by hand.")
    out.append("let transition_codes : ReadOnlyArray[Byte] = [")
    for offset in range(0, len(table), 14):
        chunk = table[offset : offset + 14]
        rendered = ", ".join(f"0x{value:02X}" for value in chunk)
        out.append(f"  {rendered},")
    out.append("]")
    out.append("")
    return "\n".join(out)


def main() -> None:
    TARGET.write_text(render(build_table()), encoding="utf-8")


if __name__ == "__main__":
    main()
