///|
const KittyGraphicsMaxDimension : UInt = 10_000U

///|
const KittyGraphicsNextImageIdStart : UInt = 2147483647U

///|
priv enum KittyGraphicsValidationError {
  InvalidData
  DimensionsRequired
  DimensionsTooLarge
  UnsupportedFormat
  UnsupportedMedium
  UnsupportedCompression
}

///|
fn kitty_graphics_error_message(error : KittyGraphicsValidationError) -> Bytes {
  match error {
    InvalidData => b"EINVAL: invalid data"
    DimensionsRequired => b"EINVAL: dimensions required"
    DimensionsTooLarge => b"EINVAL: dimensions too large"
    UnsupportedFormat => b"EINVAL: unsupported format"
    UnsupportedMedium => b"EINVAL: unsupported medium"
    UnsupportedCompression => b"EINVAL: unsupported compression"
  }
}

///|
priv enum KittyGraphicsPlacementLocation {
  Grid(GridRef)
  Virtual
}

///|
priv struct KittyGraphicsImage {
  mut id : UInt
  number : UInt
  width : UInt
  height : UInt
  format : KittyImageFormat
  compression : KittyImageCompression
  data : Bytes
  mut implicit_id : Bool
  transmit_seq : UInt64
}

///|
priv struct KittyGraphicsLoadingImage {
  image : KittyGraphicsImage
  data : Array[Byte]
  display : KittyImageDisplay?
  mut quiet : KittyGraphicsQuiet
}

///|
fn KittyGraphicsLoadingImage::new(
  transmission : KittyImageTransmission,
  data : Bytes,
  quiet : KittyGraphicsQuiet,
  display : KittyImageDisplay?,
) -> KittyGraphicsLoadingImage {
  {
    image: {
      id: transmission.image_id,
      number: transmission.image_number,
      width: transmission.width,
      height: transmission.height,
      format: transmission.format,
      compression: transmission.compression,
      data: b"",
      implicit_id: false,
      transmit_seq: 0UL,
    },
    data: kitty_graphics_byte_array_from_bytes(data),
    display,
    quiet,
  }
}

///|
fn KittyGraphicsLoadingImage::append(
  self : KittyGraphicsLoadingImage,
  data : Bytes,
) -> Unit {
  for byte in data {
    self.data.push(byte)
  }
}

///|
priv struct KittyGraphicsPlacement {
  image_id : UInt
  placement_id : UInt
  external : Bool
  location : KittyGraphicsPlacementLocation
  x_offset : UInt
  y_offset : UInt
  source_x : UInt
  source_y : UInt
  source_width : UInt
  source_height : UInt
  columns : UInt
  rows : UInt
  z : Int
}

///|
priv struct KittyGraphicsSourceRect {
  x : UInt
  y : UInt
  width : UInt
  height : UInt
}

///|
priv struct KittyGraphicsPixelSize {
  width : UInt
  height : UInt
}

///|
priv struct KittyGraphicsGridSize {
  cols : UInt
  rows : UInt
}

///|
fn KittyGraphicsPlacement::is_virtual(self : KittyGraphicsPlacement) -> Bool {
  match self.location {
    Grid(_) => false
    Virtual => true
  }
}

///|
fn KittyGraphicsPlacement::source_rect(
  self : KittyGraphicsPlacement,
  image : KittyGraphicsImage,
) -> KittyGraphicsSourceRect {
  let x = kitty_graphics_min_uint(self.source_x, image.width)
  let y = kitty_graphics_min_uint(self.source_y, image.height)
  let width = kitty_graphics_min_uint(
    if self.source_width > 0U {
      self.source_width
    } else {
      image.width
    },
    image.width - x,
  )
  let height = kitty_graphics_min_uint(
    if self.source_height > 0U {
      self.source_height
    } else {
      image.height
    },
    image.height - y,
  )
  { x, y, width, height }
}

///|
fn KittyGraphicsPlacement::pixel_size(
  self : KittyGraphicsPlacement,
  image : KittyGraphicsImage,
  terminal_cols : CellCountInt,
  terminal_rows : CellCountInt,
  width_px : UInt,
  height_px : UInt,
) -> KittyGraphicsPixelSize {
  let source = self.source_rect(image)
  if self.columns == 0U && self.rows == 0U {
    return { width: source.width, height: source.height }
  }

  let cell_width = if terminal_cols.to_uint() == 0U {
    0U
  } else {
    width_px / terminal_cols.to_uint()
  }
  let cell_height = if terminal_rows.to_uint() == 0U {
    0U
  } else {
    height_px / terminal_rows.to_uint()
  }

  if self.columns > 0U && self.rows > 0U {
    return { width: cell_width * self.columns, height: cell_height * self.rows }
  }

  if source.width == 0U || source.height == 0U {
    return { width: 0U, height: 0U }
  }

  if self.columns > 0U {
    let width = cell_width * self.columns
    let aspect = source.height.to_double() / source.width.to_double()
    let height = (width.to_double() * aspect).round().to_uint()
    return { width, height }
  }

  let height = cell_height * self.rows
  let aspect = source.width.to_double() / source.height.to_double()
  let width = (height.to_double() * aspect).round().to_uint()
  { width, height }
}

///|
fn KittyGraphicsPlacement::grid_size(
  self : KittyGraphicsPlacement,
  image : KittyGraphicsImage,
  terminal_cols : CellCountInt,
  terminal_rows : CellCountInt,
  width_px : UInt,
  height_px : UInt,
) -> KittyGraphicsGridSize {
  if self.columns > 0U && self.rows > 0U {
    return { cols: self.columns, rows: self.rows }
  }

  let pixel_size = self.pixel_size(
    image, terminal_cols, terminal_rows, width_px, height_px,
  )
  let cell_width = if terminal_cols.to_uint() == 0U {
    0U
  } else {
    width_px / terminal_cols.to_uint()
  }
  let cell_height = if terminal_rows.to_uint() == 0U {
    0U
  } else {
    height_px / terminal_rows.to_uint()
  }

  let cols = if cell_width == 0U {
    0U
  } else {
    div_ceil_uint(pixel_size.width + self.x_offset, cell_width)
  }
  let rows = if cell_height == 0U {
    0U
  } else {
    div_ceil_uint(pixel_size.height + self.y_offset, cell_height)
  }
  { cols, rows }
}

///|
priv struct KittyGraphicsState {
  mut _dirty : Bool
  mut next_image_id : UInt
  mut next_internal_placement_id : UInt
  mut next_transmit_seq : UInt64
  mut images : Array[KittyGraphicsImage]
  mut placements : Array[KittyGraphicsPlacement]
  mut loading : KittyGraphicsLoadingImage?
}

///|
fn KittyGraphicsState::new() -> KittyGraphicsState {
  {
    _dirty: false,
    next_image_id: KittyGraphicsNextImageIdStart,
    next_internal_placement_id: 0U,
    next_transmit_seq: 0UL,
    images: [],
    placements: [],
    loading: None,
  }
}

///|
fn KittyGraphicsState::full_reset(self : KittyGraphicsState) -> Unit {
  self._dirty = false
  self.next_image_id = KittyGraphicsNextImageIdStart
  self.next_internal_placement_id = 0U
  self.next_transmit_seq = 0UL
  self.images = []
  self.placements = []
  self.loading = None
}

///|
fn KittyGraphicsState::placements(
  self : KittyGraphicsState,
) -> Array[KittyGraphicsPlacement] {
  self.placements
}

///|
fn KittyGraphicsState::image_by_id(
  self : KittyGraphicsState,
  image_id : UInt,
) -> KittyGraphicsImage? {
  let mut index = 0
  while index < self.images.length() {
    if self.images[index].id == image_id {
      return Some(self.images[index])
    }
    index += 1
  }
  None
}

///|
fn KittyGraphicsState::image_by_number(
  self : KittyGraphicsState,
  image_number : UInt,
) -> KittyGraphicsImage? {
  let mut newest : KittyGraphicsImage? = None
  for image in self.images {
    if image.number == image_number {
      match newest {
        Some(current) =>
          if image.transmit_seq > current.transmit_seq {
            newest = Some(image)
          }
        None => newest = Some(image)
      }
    }
  }
  newest
}

///|
fn KittyGraphicsState::allocate_image_id(self : KittyGraphicsState) -> UInt {
  let id = self.next_image_id
  self.next_image_id += 1U
  id
}

///|
fn KittyGraphicsState::reserve_transmit_seq(
  self : KittyGraphicsState,
) -> UInt64 {
  let seq = self.next_transmit_seq
  self.next_transmit_seq += 1UL
  seq
}

///|
fn KittyGraphicsState::add_image(
  self : KittyGraphicsState,
  image : KittyGraphicsImage,
) -> Unit {
  let next : Array[KittyGraphicsImage] = []
  for existing in self.images {
    if existing.id != image.id {
      next.push(existing)
    }
  }
  next.push(image)
  self.images = next
  self._dirty = true
}

///|
fn KittyGraphicsState::add_placement(
  self : KittyGraphicsState,
  image_id : UInt,
  requested_id : UInt,
  location : KittyGraphicsPlacementLocation,
  display : KittyImageDisplay,
) -> KittyGraphicsPlacement {
  let external = requested_id != 0U
  let placement_id = if external {
    requested_id
  } else {
    let id = self.next_internal_placement_id
    self.next_internal_placement_id += 1U
    id
  }

  let placement : KittyGraphicsPlacement = {
    image_id,
    placement_id,
    external,
    location,
    x_offset: display.x_offset,
    y_offset: display.y_offset,
    source_x: display.x,
    source_y: display.y,
    source_width: display.width,
    source_height: display.height,
    columns: display.columns,
    rows: display.rows,
    z: display.z,
  }

  let next : Array[KittyGraphicsPlacement] = []
  for existing in self.placements {
    if external &&
      existing.image_id == image_id &&
      existing.external &&
      existing.placement_id == placement_id {
      ()
    } else {
      next.push(existing)
    }
  }
  next.push(placement)
  self.placements = next
  self._dirty = true
  placement
}

///|
fn KittyGraphicsState::delete_all(
  self : KittyGraphicsState,
  delete_images : Bool,
) -> Unit {
  if self.placements.length() == 0 &&
    (!delete_images || self.images.length() == 0) {
    return
  }
  self.placements = []
  if delete_images {
    self.images = []
  }
  self._dirty = true
}

///|
fn KittyGraphicsState::delete_by_id(
  self : KittyGraphicsState,
  image_id : UInt,
  placement_id : UInt,
  delete_unused : Bool,
) -> Unit {
  let mut removed = false
  let next : Array[KittyGraphicsPlacement] = []
  for placement in self.placements {
    let matches = if placement_id == 0U {
      placement.image_id == image_id
    } else {
      placement.image_id == image_id &&
      placement.external &&
      placement.placement_id == placement_id
    }
    if matches {
      removed = true
    } else {
      next.push(placement)
    }
  }
  self.placements = next
  if delete_unused {
    self.delete_image_if_unused(image_id)
  }
  if removed || delete_unused {
    self._dirty = true
  }
}

///|
fn KittyGraphicsState::delete_newest(
  self : KittyGraphicsState,
  image_number : UInt,
  placement_id : UInt,
  delete_unused : Bool,
) -> Unit {
  match self.image_by_number(image_number) {
    Some(image) => self.delete_by_id(image.id, placement_id, delete_unused)
    None => ()
  }
}

///|
fn KittyGraphicsState::delete_image_if_unused(
  self : KittyGraphicsState,
  image_id : UInt,
) -> Unit {
  for placement in self.placements {
    if placement.image_id == image_id {
      return
    }
  }

  let next : Array[KittyGraphicsImage] = []
  let mut removed = false
  for image in self.images {
    if image.id == image_id {
      removed = true
    } else {
      next.push(image)
    }
  }
  self.images = next
  if removed {
    self._dirty = true
  }
}

///|
fn kitty_graphics_validate_transmission_header(
  transmission : KittyImageTransmission,
) -> KittyGraphicsValidationError? {
  if transmission.medium != Direct {
    return Some(UnsupportedMedium)
  }
  if transmission.compression != KittyImageCompression::None {
    return Some(UnsupportedCompression)
  }
  None
}

///|
fn finalize_kitty_graphics_loading(
  loading : KittyGraphicsLoadingImage,
  transmit_seq : UInt64,
) -> Result[KittyGraphicsImage, KittyGraphicsValidationError] {
  let image = loading.image
  let mut width = image.width
  let mut height = image.height
  let mut format = image.format
  let mut data = clone_kitty_graphics_byte_array(loading.data)

  if format == Png {
    if !terminal_system_decode_png_installed() {
      return Err(UnsupportedFormat)
    }
    match terminal_system_decode_png(Bytes::from_array(data)) {
      Some(decoded) => {
        width = decoded.width()
        height = decoded.height()
        format = Rgba
        data = kitty_graphics_byte_array_from_bytes(decoded.data())
      }
      None => return Err(InvalidData)
    }
  }

  if width == 0U || height == 0U {
    return Err(DimensionsRequired)
  }
  if width > KittyGraphicsMaxDimension || height > KittyGraphicsMaxDimension {
    return Err(DimensionsTooLarge)
  }

  let expected_len = width * height * format.bytes_per_pixel()
  if data.length().reinterpret_as_uint() != expected_len {
    return Err(InvalidData)
  }

  Ok({
    id: image.id,
    number: image.number,
    width,
    height,
    format,
    compression: KittyImageCompression::None,
    data: Bytes::from_array(data),
    implicit_id: image.implicit_id,
    transmit_seq,
  })
}

///|
fn kitty_graphics_byte_array_from_bytes(bytes : Bytes) -> Array[Byte] {
  let result : Array[Byte] = []
  for byte in bytes {
    result.push(byte)
  }
  result
}

///|
fn clone_kitty_graphics_byte_array(source : Array[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  for byte in source {
    result.push(byte)
  }
  result
}

///|
fn div_ceil_uint(value : UInt, divisor : UInt) -> UInt {
  if divisor == 0U {
    return 0U
  }
  (value + divisor - 1U) / divisor
}

///|
fn kitty_graphics_min_uint(left : UInt, right : UInt) -> UInt {
  if left <= right {
    left
  } else {
    right
  }
}
