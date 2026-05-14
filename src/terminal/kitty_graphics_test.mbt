///|
fn next_placement(
  graphics : KittyGraphics,
  layer? : KittyPlacementLayer = KittyPlacementLayer::All,
) -> KittyPlacement raise {
  let iter = graphics.placement_iterator(layer~)
  match iter.next() {
    Some(placement) => placement
    None => fail("expected kitty graphics placement")
  }
}

///|
fn placement_count(
  graphics : KittyGraphics,
  layer? : KittyPlacementLayer = KittyPlacementLayer::All,
) -> Int {
  let iter = graphics.placement_iterator(layer~)
  let mut count = 0
  while iter.next() is Some(_) {
    count += 1
  }
  count
}

///|
test "kitty graphics/exposes build info and empty owner defaults" {
  let terminal = StreamTerminal::new()
  let graphics = terminal.kitty_graphics()

  guard build_info().kitty_graphics() &&
    graphics.image_storage_limit() == 320_000_000U &&
    !graphics.supports_file_medium() &&
    !graphics.supports_temporary_file_medium() &&
    !graphics.supports_shared_memory_medium() &&
    graphics.image(999U) == None &&
    !(graphics.placement_iterator().next() is Some(_)) else {
    fail("expected default kitty graphics owner state")
  }

  terminal.deinit()
}

///|
test "kitty graphics/png transmit uses the installed terminal decoder" {
  let decoded_payloads : Array[Bytes] = []
  terminal_system_clear_decode_png()
  terminal_system_set_decode_png(fn(data) {
    decoded_payloads.push(data)
    Some(SystemImage::new(1U, 1U, b"\x10\x20\x30\x40"))
  })

  let terminal = StreamTerminal::new()
  terminal.next_slice(b"\x1B_Ga=t,t=d,f=100,i=1;QUJD\x1B\\")

  let image = terminal.kitty_graphics().image(1U).unwrap()
  guard decoded_payloads == [b"ABC"] &&
    image.id() == 1U &&
    image.width() == 1U &&
    image.height() == 1U &&
    image.format() == KittyGraphicsFormat::Rgba &&
    image.compression() == KittyGraphicsCompression::None &&
    image.data() == b"\x10\x20\x30\x40" else {
    fail("expected png image transmit to use the installed decoder")
  }

  terminal.deinit()
  terminal_system_clear_decode_png()
}

///|
test "kitty graphics/image lookup and placement geometry match transmitted state" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 24, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics geometry test")
  }

  terminal.next_slice(
    b"\x1B_Ga=T,t=d,f=24,i=1,p=1,s=1,v=2,c=10,r=1;////////\x1B\\",
  )

  let graphics = terminal.kitty_graphics()
  let image = graphics.image(1U).unwrap()
  let placement = next_placement(graphics)
  let rect = placement.rect().unwrap()
  let pixel_size = placement.pixel_size()
  let grid_size = placement.grid_size()
  let viewport = placement.viewport_position().unwrap()
  let source_rect = placement.source_rect()
  let render_info = placement.render_info()

  guard image.id() == 1U &&
    image.number() == 0U &&
    image.width() == 1U &&
    image.height() == 2U &&
    image.format() == KittyGraphicsFormat::Rgb &&
    image.compression() == KittyGraphicsCompression::None &&
    image.data().length() == 6 &&
    placement.image().id() == 1U &&
    placement.image_id() == 1U &&
    placement.placement_id() == 1U &&
    !placement.is_virtual() &&
    placement.x_offset() == 0U &&
    placement.y_offset() == 0U &&
    placement.source_x() == 0U &&
    placement.source_y() == 0U &&
    placement.source_width() == 0U &&
    placement.source_height() == 0U &&
    placement.columns() == 10U &&
    placement.rows() == 1U &&
    placement.z() == 0 &&
    rect.rectangle() &&
    rect.start() == Coordinate::new(0, 0U) &&
    rect.end() == Coordinate::new(9, 0U) &&
    pixel_size.width() == 100U &&
    pixel_size.height() == 20U &&
    grid_size.cols() == 10U &&
    grid_size.rows() == 1U &&
    viewport.col() == 0 &&
    viewport.row() == 0 &&
    source_rect.x() == 0U &&
    source_rect.y() == 0U &&
    source_rect.width() == 1U &&
    source_rect.height() == 2U &&
    render_info.pixel_size() == pixel_size &&
    render_info.grid_size() == grid_size &&
    render_info.viewport_position() == Some(viewport) &&
    render_info.source_rect() == source_rect else {
    fail("expected translated kitty graphics geometry surface")
  }

  let iter = graphics.placement_iterator()
  ignore(iter.next())
  guard !(iter.next() is Some(_)) else {
    fail("expected exactly one placement")
  }

  terminal.deinit()
}

///|
test "kitty graphics/placement pin survives column resize reflow" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(8, 3, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics reflow-pin test")
  }

  terminal.next_slice(
    b"\x1B_Ga=T,t=d,f=24,i=1,p=1,s=1,v=2,c=2,r=1;////////\x1B\\",
  )

  let placement = next_placement(terminal.kitty_graphics())
  guard terminal.resize(4, 3, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize after kitty graphics placement")
  }
  let rect = placement.rect().unwrap()
  let viewport = placement.viewport_position().unwrap()
  guard rect.start() == Coordinate::new(0, 0U) &&
    viewport.col() == 0 &&
    viewport.row() == 0 else {
    fail("expected kitty placement pin to remap across column reflow")
  }

  terminal.deinit()
}

///|
test "kitty graphics/source rect and virtual placement stay typed" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 24, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics source-rect test")
  }

  terminal.next_slice(b"\x1B_Ga=t,t=d,f=24,i=1,s=1,v=2;////////\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,i=1,p=7,x=0,y=1,w=1,h=1;\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,U=1,i=1,p=8;\x1B\\")

  let graphics = terminal.kitty_graphics()
  let explicit = next_placement(graphics)
  let virtual_iter = graphics.placement_iterator()
  ignore(virtual_iter.next())
  let virtual_placement = virtual_iter.next().unwrap()

  let explicit_source = explicit.source_rect()
  guard explicit_source.x() == 0U &&
    explicit_source.y() == 1U &&
    explicit_source.width() == 1U &&
    explicit_source.height() == 1U &&
    explicit.render_info().source_rect() == explicit.source_rect() &&
    virtual_placement.is_virtual() &&
    virtual_placement.rect() == None &&
    virtual_placement.viewport_position() == None else {
    fail("expected explicit source rect and virtual placement behavior")
  }

  terminal.deinit()
}

///|
test "kitty graphics/zero cell metrics keep geometry absent" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 24, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics zero-metric test")
  }

  terminal.next_slice(b"\x1B_Ga=T,t=d,f=24,i=1,p=1,s=1,v=2;////////\x1B\\")

  let placement = next_placement(terminal.kitty_graphics())
  let pixel_size = placement.pixel_size()
  let grid_size = placement.grid_size()
  guard pixel_size.width() == 1U &&
    pixel_size.height() == 2U &&
    grid_size.cols() == 0U &&
    grid_size.rows() == 0U &&
    placement.rect() == None &&
    placement.viewport_position() == None &&
    placement.render_info().viewport_position() == None else {
    fail("expected zero pixel cell metrics to suppress grid geometry")
  }

  terminal.deinit()
}

///|
test "kitty graphics/stale placements drop coordinate queries after reset" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 5, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics stale-placement test")
  }

  terminal.next_slice(b"\n\n\n\n\n\n\n\n\n\n")
  terminal.next_slice(
    b"\x1B_Ga=T,t=d,f=24,i=1,p=1,s=1,v=2,c=1,r=1;////////\x1B\\",
  )

  let placement = next_placement(terminal.kitty_graphics())
  terminal.reset()
  guard placement.rect() == None && placement.viewport_position() == None else {
    fail("expected reset to invalidate stale placement row-id queries")
  }

  terminal.deinit()
}

///|
test "kitty graphics/layer filters and inactive screen handles stay queryable" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 24, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics layer-filter test")
  }
  terminal.next_slice(b"\x1B_Ga=t,t=d,f=24,i=1,s=1,v=2;////////\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,i=1,p=1,c=1,r=1,z=5;\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,i=1,p=2,c=1,r=1,z=-1;\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,i=1,p=3,c=1,r=1,z=-1073741825;\x1B\\")

  let primary = terminal.kitty_graphics()
  let primary_placement = next_placement(primary)
  guard placement_count(primary) == 3 &&
    placement_count(primary, layer=KittyPlacementLayer::AboveText) == 1 &&
    placement_count(primary, layer=KittyPlacementLayer::BelowText) == 1 &&
    placement_count(primary, layer=KittyPlacementLayer::BelowBackground) == 1 else {
    fail("expected kitty placement layer filtering")
  }

  terminal.mode_set(Mode::AltScreenLegacy, true)
  let alternate = terminal.kitty_graphics()
  guard alternate.image(1U) == None &&
    !(alternate.placement_iterator().next() is Some(_)) &&
    primary.image(1U) is Some(_) &&
    primary_placement.image_id() == 1U &&
    primary_placement.rect().unwrap().rectangle() else {
    fail(
      "expected primary kitty graphics handle to survive active-screen switch",
    )
  }

  terminal.deinit()
}

///|
test "kitty graphics/alternate owner survives screen switches" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 24, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics alternate-owner test")
  }

  terminal.mode_set(Mode::AltScreenLegacy, true)
  terminal.next_slice(
    b"\x1B_Ga=T,t=d,f=24,i=7,p=9,s=1,v=2,c=2,r=1;////////\x1B\\",
  )

  let alternate = terminal.kitty_graphics()
  let alternate_placement = next_placement(alternate)
  terminal.mode_set(Mode::AltScreenLegacy, false)

  let rect = alternate_placement.rect().unwrap()
  let viewport = alternate_placement.viewport_position().unwrap()
  guard alternate.image(7U).unwrap().id() == 7U &&
    alternate_placement.image_id() == 7U &&
    alternate_placement.placement_id() == 9U &&
    rect.rectangle() &&
    viewport.col() == 0 &&
    viewport.row() == 0 else {
    fail("expected alternate-screen kitty graphics handles to stay live")
  }

  terminal.deinit()
}

///|
test "kitty graphics/viewport position tracks visible and off-screen placements" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 5, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics viewport test")
  }

  terminal.next_slice(b"\x1B_Ga=t,t=d,f=24,i=1,s=1,v=2;////////\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,i=1,p=1,c=1,r=2;\x1B\\")
  terminal.next_slice(b"\n\n\n")

  let partially_visible = next_placement(terminal.kitty_graphics())
  let partial_position = partially_visible.viewport_position().unwrap()
  guard partial_position.col() == 0 && partial_position.row() < 0 else {
    fail(
      "expected partially off-screen placement to keep negative viewport row",
    )
  }

  terminal.next_slice(b"\n\n\n\n\n\n\n")
  guard next_placement(terminal.kitty_graphics()).viewport_position() == None else {
    fail("expected fully off-screen placement to report no viewport position")
  }

  terminal.deinit()
}

///|
test "kitty graphics/rgba placement clamps to screen bounds" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 5, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics rgba-clamp test")
  }

  terminal.next_slice(
    b"\x1B_Ga=T,t=d,f=32,i=3,p=4,s=1,v=1,c=200,r=10;AAAAAA==\x1B\\",
  )

  let placement = next_placement(terminal.kitty_graphics())
  let image = placement.image()
  let rect = placement.rect().unwrap()
  let viewport = placement.viewport_position().unwrap()
  guard image.format() == KittyGraphicsFormat::Rgba else {
    fail("expected rgba image format")
  }
  guard image.compression() == KittyGraphicsCompression::None else {
    fail("expected uncompressed rgba image")
  }
  guard image.data().length() == 4 else { fail("expected four rgba bytes") }
  guard placement.grid_size().cols() == 200U else {
    fail("expected explicit rgba columns to be preserved")
  }
  guard placement.grid_size().rows() == 10U else {
    fail("expected explicit rgba rows to be preserved")
  }
  guard rect.rectangle() else {
    fail("expected rgba placement rect to stay rectangular")
  }
  guard placement.render_info().viewport_position() == Some(viewport) else {
    fail("expected rgba render info to retain viewport position")
  }

  terminal.deinit()
}

///|
test "kitty graphics/no-op delete selectors preserve visible state" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(80, 5, 10U, 20U) == TerminalResultCode::Success else {
    fail("expected resize before kitty graphics delete-selector test")
  }

  terminal.next_slice(b"\x1B_Ga=t,t=d,f=24,i=1,s=1,v=2;////////\x1B\\")
  terminal.next_slice(b"\x1B_Ga=p,i=1,p=1,c=1,r=1;\x1B\\")

  let graphics = terminal.kitty_graphics()
  guard graphics.image(1U) is Some(_) && placement_count(graphics) == 1 else {
    fail("expected initial kitty graphics state")
  }

  for
    sequence in [
      b"\x1B_Ga=d,d=c;\x1B\\", b"\x1B_Ga=d,d=f;\x1B\\", b"\x1B_Ga=d,d=p,x=0,y=0;\x1B\\",
      b"\x1B_Ga=d,d=q,x=0,y=0,z=0;\x1B\\", b"\x1B_Ga=d,d=R,x=0,y=0;\x1B\\", b"\x1B_Ga=d,d=X,x=0;\x1B\\",
      b"\x1B_Ga=d,d=Y,y=0;\x1B\\",
    ] {
    terminal.next_slice(sequence)
  }

  let placement = next_placement(graphics)
  guard graphics.image(1U) is Some(_) &&
    placement_count(graphics) == 1 &&
    placement.image_id() == 1U &&
    placement.rect().unwrap().rectangle() else {
    fail("expected no-op kitty delete selectors to preserve image state")
  }

  terminal.deinit()
}
