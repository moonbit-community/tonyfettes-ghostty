///|
test "kitty graphics wb/skips placements whose backing image is missing" {
  let bridge = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(),
  )
  bridge.kitty_graphics.placements = [
    {
      image_id: 9U,
      placement_id: 1U,
      external: true,
      location: Grid(GridRef::new(TerminalScreen::Primary, 0UL, 0)),
      x_offset: 0U,
      y_offset: 0U,
      source_x: 0U,
      source_y: 0U,
      source_width: 0U,
      source_height: 0U,
      columns: 1U,
      rows: 1U,
      z: 0,
    },
  ]

  let graphics : KittyGraphics = { bridge, screen: TerminalScreen::Primary }
  guard !(graphics.placement_iterator().next() is Some(_)) else {
    fail("expected missing-image placements to be skipped")
  }
}

///|
test "kitty graphics wb/format and compression helpers stay total" {
  let rgba_image : KittyImage = {
    id: 1U,
    number: 2U,
    width: 1U,
    height: 1U,
    format_: KittyGraphicsFormat::Rgba,
    compression_: KittyGraphicsCompression::ZlibDeflate,
    data: b"\x00\x00\x00\x00",
  }
  let rgba_private = kitty_private_image(rgba_image)
  let rgba_round_trip = kitty_public_image(rgba_private)
  let png_image : KittyImage = {
    id: 3U,
    number: 4U,
    width: 1U,
    height: 1U,
    format_: KittyGraphicsFormat::Png,
    compression_: KittyGraphicsCompression::None,
    data: b"\x89PNG",
  }
  let png_private = kitty_private_image(png_image)
  let png_round_trip = kitty_public_image(png_private)

  guard rgba_private.format == KittyImageFormat::Rgba &&
    rgba_private.compression == KittyImageCompression::ZlibDeflate &&
    rgba_round_trip.format() == KittyGraphicsFormat::Rgba &&
    rgba_round_trip.compression() == KittyGraphicsCompression::ZlibDeflate &&
    png_private.format == KittyImageFormat::Png &&
    png_round_trip.format() == KittyGraphicsFormat::Png else {
    fail("expected kitty image helper conversions to stay exhaustive")
  }
}

///|
test "kitty graphics wb/rect guards impossible zero-row state" {
  let bridge = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(),
  )
  bridge.grid = { rows: 0, cols: 1, row_states: [], cells: [] }
  bridge.scrollback.visible_row_ids = [7UL]

  let placement : KittyPlacement = {
    bridge,
    screen: TerminalScreen::Primary,
    image_snapshot: {
      id: 1U,
      number: 0U,
      width: 1U,
      height: 1U,
      format_: KittyGraphicsFormat::Rgb,
      compression_: KittyGraphicsCompression::None,
      data: b"\x00\x00\x00",
    },
    placement: {
      image_id: 1U,
      placement_id: 1U,
      external: true,
      location: Grid(GridRef::new(TerminalScreen::Primary, 7UL, 0)),
      x_offset: 0U,
      y_offset: 0U,
      source_x: 0U,
      source_y: 0U,
      source_width: 0U,
      source_height: 0U,
      columns: 1U,
      rows: 1U,
      z: 0,
    },
  }

  guard placement.rect() == None else {
    fail("expected zero-row synthetic state to trip the total-row guard")
  }
}
