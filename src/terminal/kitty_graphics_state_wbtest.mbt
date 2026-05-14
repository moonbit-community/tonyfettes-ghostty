///|
fn sample_kitty_image(
  id? : UInt = 1U,
  number? : UInt = 0U,
  width? : UInt = 4U,
  height? : UInt = 2U,
  transmit_seq? : UInt64 = 0UL,
) -> KittyGraphicsImage {
  {
    id,
    number,
    width,
    height,
    format: Rgb,
    compression: KittyImageCompression::None,
    data: b"\x00\x01\x02\x03\x04\x05\x06\x07",
    implicit_id: false,
    transmit_seq,
  }
}

///|
fn KittyGraphicsState::dirty(self : KittyGraphicsState) -> Bool {
  self._dirty
}

///|
fn KittyGraphicsState::clear_dirty(self : KittyGraphicsState) -> Unit {
  self._dirty = false
}

///|
fn KittyGraphicsState::images(
  self : KittyGraphicsState,
) -> Array[KittyGraphicsImage] {
  self.images
}

///|
fn sample_display(
  image_id? : UInt = 1U,
  placement_id? : UInt = 0U,
  columns? : UInt = 0U,
  rows? : UInt = 0U,
) -> KittyImageDisplay {
  let display = KittyImageDisplay::new()
  display.image_id = image_id
  display.placement_id = placement_id
  display.columns = columns
  display.rows = rows
  display
}

///|
test "kitty graphics state/image replacement and newest lookup" {
  let state = KittyGraphicsState::new()
  guard !state.dirty() else { fail("expected clean graphics state") }

  state.add_image(sample_kitty_image(number=7U, transmit_seq=1UL))
  state.add_image(sample_kitty_image(id=2U, number=7U, transmit_seq=3UL))
  state.add_image(sample_kitty_image(id=3U, number=7U, transmit_seq=5UL))
  state.add_image(sample_kitty_image(id=1U, number=9U, transmit_seq=4UL))

  guard state.images().length() == 3 else {
    fail("expected image replacement by id")
  }
  guard state.image_by_id(1U) is Some(image) && image.number == 9U else {
    fail("expected lookup by id after replacement")
  }
  guard state.image_by_number(7U) is Some(newest) && newest.id == 3U else {
    fail("expected newest image lookup by number")
  }
  guard state.dirty() else { fail("expected image writes to mark dirty") }
  state.clear_dirty()
  guard !state.dirty() else { fail("expected dirty clear") }
}

///|
test "kitty graphics state/internal and external placements" {
  let state = KittyGraphicsState::new()
  let scrollback = PageList::new(3, 10, 10)
  state.add_image(sample_kitty_image())

  let first = state.add_placement(
    scrollback,
    1U,
    0U,
    KittyGraphicsPlacementLocation::Pin(5UL),
    sample_display(),
  )
  let second = state.add_placement(
    scrollback,
    1U,
    0U,
    KittyGraphicsPlacementLocation::Pin(6UL),
    sample_display(),
  )
  let replaced = state.add_placement(
    scrollback,
    1U,
    9U,
    KittyGraphicsPlacementLocation::Virtual,
    sample_display(placement_id=9U),
  )
  ignore(
    state.add_placement(
      scrollback,
      1U,
      9U,
      KittyGraphicsPlacementLocation::Pin(8UL),
      sample_display(placement_id=9U, columns=2U, rows=1U),
    ),
  )

  guard first.placement_id == 0U && !first.external else {
    fail("expected first internal placement id")
  }
  guard second.placement_id == 1U && !second.external else {
    fail("expected second internal placement id")
  }
  guard replaced.external && replaced.placement_id == 9U else {
    fail("expected external placement identity")
  }
  guard state.placements().length() == 3 else {
    fail("expected external placement replacement")
  }
}

///|
test "kitty graphics state/delete helpers" {
  let state = KittyGraphicsState::new()
  let scrollback = PageList::new(3, 10, 10)
  state.add_image(sample_kitty_image(id=1U, number=1U, transmit_seq=1UL))
  state.add_image(sample_kitty_image(id=2U, number=2U, transmit_seq=2UL))

  ignore(
    state.add_placement(
      scrollback,
      1U,
      4U,
      KittyGraphicsPlacementLocation::Pin(1UL),
      sample_display(image_id=1U, placement_id=4U),
    ),
  )
  ignore(
    state.add_placement(
      scrollback,
      2U,
      5U,
      KittyGraphicsPlacementLocation::Pin(2UL),
      sample_display(image_id=2U, placement_id=5U),
    ),
  )

  state.delete_image_if_unused(2U)
  guard state.image_by_id(2U) is Some(_) else {
    fail("expected used image to remain present")
  }

  state.delete_by_id(scrollback, 1U, 4U, true)
  guard state.placements().length() == 1 && state.image_by_id(1U) is None else {
    fail("expected delete-by-id with delete-unused")
  }

  state.delete_newest(scrollback, 2U, 0U, false)
  guard state.placements().length() == 0 && state.image_by_id(2U) is Some(_) else {
    fail("expected newest delete to keep image when requested")
  }

  state.delete_all(scrollback, true)
  guard state.images().length() == 0 && state.placements().length() == 0 else {
    fail("expected delete-all to clear state")
  }
}

///|
test "kitty graphics state/loading validation and geometry helpers" {
  terminal_system_clear_decode_png()

  let transmission = KittyImageTransmission::new()
  transmission.format = Rgb
  transmission.width = 4U
  transmission.height = 2U

  guard kitty_graphics_validate_transmission_header(transmission) is None else {
    fail("expected direct rgb transmission header to be supported")
  }

  let loading = KittyGraphicsLoadingImage::new(
    transmission,
    b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17",
    KittyGraphicsQuiet::No,
    None,
  )
  guard finalize_kitty_graphics_loading(loading, 7UL) is Ok(image) &&
    image.transmit_seq == 7UL &&
    image.data.length() == 24 else {
    fail("expected finalized image with exact payload length")
  }

  let invalid_loading = KittyGraphicsLoadingImage::new(
    transmission,
    b"\x00",
    KittyGraphicsQuiet::No,
    None,
  )
  guard finalize_kitty_graphics_loading(invalid_loading, 8UL)
    is Err(InvalidData) else {
    fail("expected invalid payload length to fail")
  }

  let png = KittyImageTransmission::new()
  png.format = Png
  guard kitty_graphics_validate_transmission_header(png) is None else {
    fail("expected png header validation to defer to system decoder")
  }
  guard finalize_kitty_graphics_loading(
      KittyGraphicsLoadingImage::new(png, b"QUJD", KittyGraphicsQuiet::No, None),
      9UL,
    )
    is Err(UnsupportedFormat) else {
    fail("expected png finalization to require an installed decoder")
  }

  terminal_system_set_decode_png(fn(data) {
    guard data == b"QUJD" else { return None }
    Some(SystemImage::new(1U, 1U, b"\x00\x11\x22\x33"))
  })
  guard finalize_kitty_graphics_loading(
      KittyGraphicsLoadingImage::new(png, b"QUJD", KittyGraphicsQuiet::No, None),
      10UL,
    )
    is Ok(png_image) &&
    png_image.transmit_seq == 10UL &&
    png_image.width == 1U &&
    png_image.height == 1U &&
    png_image.format == Rgba &&
    png_image.data == b"\x00\x11\x22\x33" else {
    fail("expected png finalization to use the installed decoder")
  }

  terminal_system_set_decode_png(fn(_data) {
    Some(SystemImage::new(1U, 1U, b"\x00"))
  })
  guard finalize_kitty_graphics_loading(
      KittyGraphicsLoadingImage::new(png, b"QUJD", KittyGraphicsQuiet::No, None),
      11UL,
    )
    is Err(InvalidData) else {
    fail("expected decoded png payload length validation")
  }
  terminal_system_clear_decode_png()

  let compressed = KittyImageTransmission::new()
  compressed.compression = ZlibDeflate
  guard kitty_graphics_validate_transmission_header(compressed)
    is Some(UnsupportedCompression) else {
    fail("expected compressed direct medium to stay unsupported")
  }

  let placement = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 0U,
    external: false,
    location: KittyGraphicsPlacementLocation::Pin(9UL),
    x_offset: 5U,
    y_offset: 3U,
    source_x: 1U,
    source_y: 0U,
    source_width: 2U,
    source_height: 0U,
    columns: 0U,
    rows: 0U,
    z: -1,
  }
  let image = sample_kitty_image(width=4U, height=2U)
  let source = placement.source_rect(image)
  guard source.x == 1U &&
    source.y == 0U &&
    source.width == 2U &&
    source.height == 2U else {
    fail("expected source-rect clamping")
  }

  let explicit_source_height = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 2U,
    external: false,
    location: KittyGraphicsPlacementLocation::Virtual,
    x_offset: 0U,
    y_offset: 0U,
    source_x: 0U,
    source_y: 0U,
    source_width: 0U,
    source_height: 1U,
    columns: 0U,
    rows: 0U,
    z: 0,
  }
  let explicit_source = explicit_source_height.source_rect(image)
  guard explicit_source.height == 1U else {
    fail("expected explicit source height branch")
  }

  let scaled = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 1U,
    external: false,
    location: KittyGraphicsPlacementLocation::Virtual,
    x_offset: 5U,
    y_offset: 3U,
    source_x: 0U,
    source_y: 0U,
    source_width: 0U,
    source_height: 0U,
    columns: 0U,
    rows: 0U,
    z: 0,
  }
  let pixel = scaled.pixel_size(image, 80, 24, 800U, 480U)
  guard pixel.width == 4U && pixel.height == 2U else {
    fail("expected native pixel size without explicit grid sizing")
  }
  let grid = scaled.grid_size(image, 80, 24, 800U, 480U)
  guard grid.cols == 1U && grid.rows == 1U else {
    fail("expected ceil-rounded grid sizing")
  }

  let zero_source = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 3U,
    external: false,
    location: KittyGraphicsPlacementLocation::Virtual,
    x_offset: 0U,
    y_offset: 0U,
    source_x: 4U,
    source_y: 0U,
    source_width: 0U,
    source_height: 0U,
    columns: 1U,
    rows: 0U,
    z: 0,
  }
  let zero_pixel = zero_source.pixel_size(image, 80, 24, 800U, 480U)
  guard zero_pixel.width == 0U && zero_pixel.height == 0U else {
    fail("expected zero-sized source rect handling")
  }

  let width_only = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 4U,
    external: false,
    location: KittyGraphicsPlacementLocation::Virtual,
    x_offset: 0U,
    y_offset: 0U,
    source_x: 0U,
    source_y: 0U,
    source_width: 0U,
    source_height: 0U,
    columns: 2U,
    rows: 0U,
    z: 0,
  }
  let width_pixel = width_only.pixel_size(image, 80, 24, 800U, 480U)
  guard width_pixel.width == 20U && width_pixel.height == 10U else {
    fail("expected width-only aspect sizing")
  }
  let zero_grid = width_only.grid_size(image, 0, 0, 0U, 0U)
  guard zero_grid.cols == 0U && zero_grid.rows == 0U else {
    fail("expected zero terminal grid sizing")
  }

  let explicit = sample_display(columns=3U, rows=2U)
  let explicit_scrollback = PageList::new(3, 10, 10)
  let placed = KittyGraphicsState::new().add_placement(
    explicit_scrollback,
    1U,
    0U,
    KittyGraphicsPlacementLocation::Virtual,
    explicit,
  )
  let explicit_grid = placed.grid_size(image, 80, 24, 800U, 480U)
  guard explicit_grid.cols == 3U && explicit_grid.rows == 2U else {
    fail("expected explicit grid sizing")
  }

  guard kitty_graphics_error_message(UnsupportedMedium) ==
    b"EINVAL: unsupported medium" else {
    fail("expected error message mapping")
  }
}

///|
test "kitty graphics state/reset and edge helper branches" {
  let state = KittyGraphicsState::new()
  let scrollback = PageList::new(3, 10, 10)
  let first_id = state.allocate_image_id()
  let second_id = state.allocate_image_id()
  let first_seq = state.reserve_transmit_seq()
  let second_seq = state.reserve_transmit_seq()
  guard first_id == KittyGraphicsNextImageIdStart &&
    second_id == KittyGraphicsNextImageIdStart + 1U &&
    first_seq == 0UL &&
    second_seq == 1UL else {
    fail("expected id and transmit sequence allocation")
  }

  state.add_image(sample_kitty_image(id=5U))
  ignore(
    state.add_placement(
      scrollback,
      5U,
      0U,
      KittyGraphicsPlacementLocation::Pin(7UL),
      sample_display(image_id=5U),
    ),
  )
  state.loading = Some(
    KittyGraphicsLoadingImage::new(
      KittyImageTransmission::new(),
      b"",
      KittyGraphicsQuiet::Ok,
      None,
    ),
  )
  state.full_reset(scrollback)
  guard !state.dirty() &&
    state.images().length() == 0 &&
    state.placements().length() == 0 &&
    state.loading is None else {
    fail("expected full reset to clear graphics state")
  }

  state.delete_newest(scrollback, 99U, 0U, false)
  state.delete_all(scrollback, false)
  guard state.images().length() == 0 && state.placements().length() == 0 else {
    fail("expected no-op deletes on empty state")
  }

  let required = KittyGraphicsLoadingImage::new(
    KittyImageTransmission::new(),
    b"",
    KittyGraphicsQuiet::No,
    None,
  )
  guard finalize_kitty_graphics_loading(required, 0UL)
    is Err(DimensionsRequired) else {
    fail("expected missing dimensions validation")
  }

  let too_large = KittyImageTransmission::new()
  too_large.width = KittyGraphicsMaxDimension + 1U
  too_large.height = 1U
  let too_large_loading = KittyGraphicsLoadingImage::new(
    too_large,
    b"",
    KittyGraphicsQuiet::No,
    None,
  )
  guard finalize_kitty_graphics_loading(too_large_loading, 0UL)
    is Err(DimensionsTooLarge) else {
    fail("expected oversized dimensions validation")
  }

  let file_medium = KittyImageTransmission::new()
  file_medium.medium = File
  guard kitty_graphics_validate_transmission_header(file_medium)
    is Some(UnsupportedMedium) else {
    fail("expected unsupported medium validation")
  }

  guard kitty_graphics_error_message(InvalidData) == b"EINVAL: invalid data" &&
    kitty_graphics_error_message(DimensionsRequired) ==
    b"EINVAL: dimensions required" &&
    kitty_graphics_error_message(DimensionsTooLarge) ==
    b"EINVAL: dimensions too large" &&
    kitty_graphics_error_message(UnsupportedFormat) ==
    b"EINVAL: unsupported format" &&
    kitty_graphics_error_message(UnsupportedCompression) ==
    b"EINVAL: unsupported compression" else {
    fail("expected error message coverage")
  }

  let virtual_placement = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 0U,
    external: false,
    location: KittyGraphicsPlacementLocation::Virtual,
    x_offset: 0U,
    y_offset: 0U,
    source_x: 4U,
    source_y: 2U,
    source_width: 0U,
    source_height: 0U,
    columns: 2U,
    rows: 3U,
    z: 0,
  }
  let image = sample_kitty_image(width=4U, height=2U)
  guard virtual_placement.is_virtual() else {
    fail("expected virtual placement detection")
  }
  let zero_pixel = virtual_placement.pixel_size(image, 0, 0, 0U, 0U)
  guard zero_pixel.width == 0U && zero_pixel.height == 0U else {
    fail("expected zero terminal geometry handling")
  }
  let explicit_pixel = virtual_placement.pixel_size(image, 80, 24, 800U, 480U)
  guard explicit_pixel.width == 20U && explicit_pixel.height == 60U else {
    fail("expected explicit row and column sizing")
  }

  let height_only = KittyGraphicsPlacement::{
    image_id: 1U,
    placement_id: 1U,
    external: false,
    location: KittyGraphicsPlacementLocation::Pin(1UL),
    x_offset: 1U,
    y_offset: 2U,
    source_x: 0U,
    source_y: 0U,
    source_width: 0U,
    source_height: 0U,
    columns: 0U,
    rows: 2U,
    z: 0,
  }
  guard !height_only.is_virtual() else {
    fail("expected grid placement detection")
  }
  let height_pixel = height_only.pixel_size(image, 80, 24, 800U, 480U)
  guard height_pixel.height == 40U && height_pixel.width == 80U else {
    fail("expected height-only aspect sizing")
  }
  let height_grid = height_only.grid_size(image, 80, 24, 800U, 480U)
  guard height_grid.cols == 9U && height_grid.rows == 3U else {
    fail("expected ceil grid sizing with offsets")
  }

  guard div_ceil_uint(5U, 0U) == 0U && kitty_graphics_min_uint(7U, 3U) == 3U else {
    fail("expected scalar helper edge behavior")
  }
  guard kitty_graphics_byte_array_from_bytes(b"\x01\x02") == [1, 2] &&
    clone_kitty_graphics_byte_array([3, 4]) == [3, 4] else {
    fail("expected byte array helper cloning")
  }
}
