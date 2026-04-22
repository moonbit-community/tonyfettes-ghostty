///|
test "surface registry/covers upstream type list in order" {
  let expected : Array[String] = [
    "GhosttyColorRgb", "GhosttyDeviceAttributes", "GhosttyDeviceAttributesPrimary",
    "GhosttyDeviceAttributesSecondary", "GhosttyDeviceAttributesTertiary", "GhosttyFormatterTerminalOptions",
    "GhosttySelection", "GhosttyFormatterTerminalExtra", "GhosttyFormatterScreenExtra",
    "GhosttyGridRef", "GhosttyMouseEncoderSize", "GhosttyMousePosition", "GhosttyPoint",
    "GhosttyPointCoordinate", "GhosttyRenderStateColors", "GhosttySizeReportSize",
    "GhosttyString", "GhosttyStyle", "GhosttyStyleColor", "GhosttyTerminalOptions",
    "GhosttyTerminalScrollbar", "GhosttyTerminalScrollViewport",
  ]
  let entries = terminal_surface_types()
  guard entries.length() == expected.length() else {
    fail("expected \{expected.length()} surface type entries")
  }
  for i in 0..<expected.length() {
    guard entries[i].upstream_name() == expected[i] else {
      fail("expected surface registry ordering to follow upstream types.zig")
    }
  }
}

///|
test "surface registry/returns direct mappings" {
  let style = terminal_surface_type("GhosttyStyle").unwrap()
  guard style.mapping() == TerminalSurfaceTypeMapping::Direct else {
    fail("expected GhosttyStyle to stay a direct mapping")
  }
  guard style.moonbit_surface() == "CellStyle" else {
    fail("expected GhosttyStyle to map to CellStyle")
  }
  guard style.note() == None else {
    fail("expected direct mappings to avoid extra notes")
  }

  let selection = terminal_surface_type("GhosttySelection").unwrap()
  guard selection.mapping() == TerminalSurfaceTypeMapping::Direct else {
    fail("expected GhosttySelection to stay direct")
  }
  guard selection.moonbit_surface() == "Selection[GridRef]" else {
    fail("expected selection to specialize on GridRef")
  }
}

///|
test "surface registry/marks native and absorbed replacements" {
  let string_info = terminal_surface_type("GhosttyString").unwrap()
  guard string_info.mapping() == TerminalSurfaceTypeMapping::Native else {
    fail("expected GhosttyString to be replaced by native MoonBit types")
  }
  guard string_info.moonbit_surface() == "String / Bytes" else {
    fail("expected GhosttyString to map to native String / Bytes")
  }
  guard string_info.note() != None else {
    fail("expected GhosttyString to explain the native replacement")
  }

  let terminal_opts = terminal_surface_type("GhosttyTerminalOptions").unwrap()
  guard terminal_opts.mapping() == TerminalSurfaceTypeMapping::Absorbed else {
    fail("expected GhosttyTerminalOptions to be absorbed into StreamTerminal")
  }
  guard terminal_opts.moonbit_surface() == "StreamTerminal" else {
    fail("expected GhosttyTerminalOptions to map to StreamTerminal")
  }
  guard terminal_opts.note() != None else {
    fail("expected absorbed terminal options to carry an audit note")
  }
}

///|
test "surface registry/lookup rejects unknown entries" {
  guard terminal_surface_type("GhosttyNotReal") == None else {
    fail("expected unknown upstream names to return None")
  }
}
