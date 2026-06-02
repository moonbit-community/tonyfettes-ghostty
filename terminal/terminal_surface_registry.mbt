///|
pub(all) enum TerminalSurfaceTypeMapping {
  Direct
  Native
  Absorbed
} derive(Eq, Debug)

///|
struct TerminalSurfaceTypeInfo {
  upstream_name : String
  mapping : TerminalSurfaceTypeMapping
  moonbit_surface : String
  note : String?
} derive(Eq, Debug)

///|
pub fn TerminalSurfaceTypeInfo::upstream_name(
  self : TerminalSurfaceTypeInfo,
) -> String {
  self.upstream_name
}

///|
pub fn TerminalSurfaceTypeInfo::mapping(
  self : TerminalSurfaceTypeInfo,
) -> TerminalSurfaceTypeMapping {
  self.mapping
}

///|
pub fn TerminalSurfaceTypeInfo::moonbit_surface(
  self : TerminalSurfaceTypeInfo,
) -> String {
  self.moonbit_surface
}

///|
pub fn TerminalSurfaceTypeInfo::note(self : TerminalSurfaceTypeInfo) -> String? {
  self.note
}

///|
pub fn terminal_surface_types() -> ReadOnlyArray[TerminalSurfaceTypeInfo] {
  terminal_surface_type_entries
}

///|
pub fn terminal_surface_type(
  upstream_name : String,
) -> TerminalSurfaceTypeInfo? {
  for entry in terminal_surface_type_entries {
    if entry.upstream_name == upstream_name {
      return Some(entry)
    }
  }
  None
}

///|
fn terminal_surface_type_info(
  upstream_name : String,
  mapping : TerminalSurfaceTypeMapping,
  moonbit_surface : String,
  note? : String? = None,
) -> TerminalSurfaceTypeInfo {
  { upstream_name, mapping, moonbit_surface, note }
}

///|
let terminal_surface_type_entries : ReadOnlyArray[TerminalSurfaceTypeInfo] = [
  terminal_surface_type_info("GhosttyColorRgb", Direct, "RGB"),
  terminal_surface_type_info(
    "GhosttyDeviceAttributes",
    Direct,
    "DeviceAttributes",
  ),
  terminal_surface_type_info(
    "GhosttyDeviceAttributesPrimary",
    Direct,
    "PrimaryDeviceAttributes",
  ),
  terminal_surface_type_info(
    "GhosttyDeviceAttributesSecondary",
    Direct,
    "SecondaryDeviceAttributes",
  ),
  terminal_surface_type_info(
    "GhosttyDeviceAttributesTertiary",
    Direct,
    "TertiaryDeviceAttributes",
  ),
  terminal_surface_type_info(
    "GhosttyFormatterTerminalOptions",
    Direct,
    "FormatterOptions",
  ),
  terminal_surface_type_info("GhosttySelection", Direct, "Selection"),
  terminal_surface_type_info("GhosttyGridRef", Direct, "Pin"),
  terminal_surface_type_info(
    "GhosttyFormatterTerminalExtra",
    Direct,
    "FormatterTerminalExtra",
  ),
  terminal_surface_type_info(
    "GhosttyFormatterScreenExtra",
    Direct,
    "FormatterScreenExtra",
  ),
  terminal_surface_type_info(
    "GhosttyMouseEncoderSize",
    Direct,
    "MouseEncoderSize",
  ),
  terminal_surface_type_info("GhosttyMousePosition", Direct, "MousePosition"),
  terminal_surface_type_info("GhosttyPoint", Direct, "Point"),
  terminal_surface_type_info("GhosttyPointCoordinate", Direct, "Coordinate"),
  terminal_surface_type_info(
    "GhosttyRenderStateColors",
    Absorbed,
    "RenderState",
    note=Some(
      "RenderState exposes background, foreground, cursor, and palette colors with getters instead of a standalone Colors wrapper.",
    ),
  ),
  terminal_surface_type_info("GhosttySizeReportSize", Direct, "Size"),
  terminal_surface_type_info(
    "GhosttyString",
    Native,
    "String / Bytes",
    note=Some(
      "Native MoonBit text and byte results replace the C ABI string wrapper.",
    ),
  ),
  terminal_surface_type_info("GhosttyStyle", Direct, "CellStyle"),
  terminal_surface_type_info("GhosttyStyleColor", Direct, "StyleColor"),
  terminal_surface_type_info(
    "GhosttyTerminalOptions",
    Absorbed,
    "StreamTerminal",
    note=Some(
      "Construction, resize, and dimension/color query methods absorb the C terminal options wrapper.",
    ),
  ),
  terminal_surface_type_info(
    "GhosttyTerminalScrollbar",
    Direct,
    "TerminalScrollbar",
  ),
  terminal_surface_type_info(
    "GhosttyTerminalScrollViewport",
    Absorbed,
    "StreamTerminal",
    note=Some(
      "scroll_viewport_top, scroll_viewport_bottom, and scroll_viewport_delta replace the viewport command struct.",
    ),
  ),
]
