///|
const DefaultKittyImageStorageLimit : UInt = 320_000_000U

///|
const KittyPlacementBelowBackgroundThreshold : Int = -1_073_741_824

///|
pub(all) enum KittyGraphicsFormat {
  Rgb
  Rgba
  Png
} derive(Eq, Debug)

///|
pub(all) enum KittyGraphicsCompression {
  None
  ZlibDeflate
} derive(Eq, Debug)

///|
pub(all) enum KittyPlacementLayer {
  All
  BelowBackground
  BelowText
  AboveText
} derive(Eq, Debug)

///|
struct KittyImage {
  id : UInt
  number : UInt
  width : UInt
  height : UInt
  format_ : KittyGraphicsFormat
  compression_ : KittyGraphicsCompression
  data : Bytes
} derive(Eq, Debug)

///|
struct KittyPlacementPixelSize {
  width : UInt
  height : UInt
} derive(Eq, Debug)

///|
struct KittyPlacementGridSize {
  cols : UInt
  rows : UInt
} derive(Eq, Debug)

///|
struct KittyPlacementSourceRect {
  x : UInt
  y : UInt
  width : UInt
  height : UInt
} derive(Eq, Debug)

///|
struct KittyPlacementViewportPosition {
  col : Int
  row : Int
} derive(Eq, Debug)

///|
struct KittyPlacementRenderInfo {
  pixel_size : KittyPlacementPixelSize
  grid_size : KittyPlacementGridSize
  viewport_position : KittyPlacementViewportPosition?
  source_rect : KittyPlacementSourceRect
} derive(Eq, Debug)

///|
struct KittyGraphics {
  bridge : StreamTerminalBridgeState
  screen : TerminalScreen
}

///|
struct KittyPlacement {
  bridge : StreamTerminalBridgeState
  screen : TerminalScreen
  image_snapshot : KittyImage
  placement : KittyGraphicsPlacement
}

///|
struct KittyPlacementIterator {
  entries : Array[KittyPlacement]
  mut index : Int
}

///|
pub fn StreamTerminal::kitty_graphics(self : StreamTerminal) -> KittyGraphics {
  { bridge: self.bridge(), screen: self.active_screen() }
}

///|
pub fn KittyGraphics::image_storage_limit(self : KittyGraphics) -> UInt {
  ignore(self)
  DefaultKittyImageStorageLimit
}

///|
pub fn KittyGraphics::supports_file_medium(self : KittyGraphics) -> Bool {
  ignore(self)
  false
}

///|
pub fn KittyGraphics::supports_temporary_file_medium(
  self : KittyGraphics,
) -> Bool {
  ignore(self)
  false
}

///|
pub fn KittyGraphics::supports_shared_memory_medium(
  self : KittyGraphics,
) -> Bool {
  ignore(self)
  false
}

///|
pub fn KittyGraphics::image(
  self : KittyGraphics,
  image_id : UInt,
) -> KittyImage? {
  kitty_graphics_owner_state(self).image_by_id(image_id).map(kitty_public_image)
}

///|
pub fn KittyGraphics::placement_iterator(
  self : KittyGraphics,
  layer? : KittyPlacementLayer = KittyPlacementLayer::All,
) -> KittyPlacementIterator {
  { entries: kitty_public_placements(self, layer), index: 0 }
}

///|
pub fn KittyPlacementIterator::next(
  self : KittyPlacementIterator,
) -> KittyPlacement? {
  if self.index < 0 || self.index >= self.entries.length() {
    None
  } else {
    let current = self.entries[self.index]
    self.index += 1
    Some(current)
  }
}

///|
pub fn KittyImage::id(self : KittyImage) -> UInt {
  self.id
}

///|
pub fn KittyImage::number(self : KittyImage) -> UInt {
  self.number
}

///|
pub fn KittyImage::width(self : KittyImage) -> UInt {
  self.width
}

///|
pub fn KittyImage::height(self : KittyImage) -> UInt {
  self.height
}

///|
pub fn KittyImage::format(self : KittyImage) -> KittyGraphicsFormat {
  self.format_
}

///|
pub fn KittyImage::compression(self : KittyImage) -> KittyGraphicsCompression {
  self.compression_
}

///|
pub fn KittyImage::data(self : KittyImage) -> Bytes {
  self.data
}

///|
pub fn KittyPlacement::image(self : KittyPlacement) -> KittyImage {
  self.image_snapshot
}

///|
pub fn KittyPlacement::image_id(self : KittyPlacement) -> UInt {
  self.placement.image_id
}

///|
pub fn KittyPlacement::placement_id(self : KittyPlacement) -> UInt {
  self.placement.placement_id
}

///|
pub fn KittyPlacement::is_virtual(self : KittyPlacement) -> Bool {
  self.placement.is_virtual()
}

///|
pub fn KittyPlacement::x_offset(self : KittyPlacement) -> UInt {
  self.placement.x_offset
}

///|
pub fn KittyPlacement::y_offset(self : KittyPlacement) -> UInt {
  self.placement.y_offset
}

///|
pub fn KittyPlacement::source_x(self : KittyPlacement) -> UInt {
  self.placement.source_x
}

///|
pub fn KittyPlacement::source_y(self : KittyPlacement) -> UInt {
  self.placement.source_y
}

///|
pub fn KittyPlacement::source_width(self : KittyPlacement) -> UInt {
  self.placement.source_width
}

///|
pub fn KittyPlacement::source_height(self : KittyPlacement) -> UInt {
  self.placement.source_height
}

///|
pub fn KittyPlacement::columns(self : KittyPlacement) -> UInt {
  self.placement.columns
}

///|
pub fn KittyPlacement::rows(self : KittyPlacement) -> UInt {
  self.placement.rows
}

///|
pub fn KittyPlacement::z(self : KittyPlacement) -> Int {
  self.placement.z
}

///|
pub fn KittyPlacement::rect(self : KittyPlacement) -> Selection[Coordinate]? {
  let pin_id = match self.placement.location {
    Pin(id) => id
    Virtual => return None
  }
  let grid = kitty_placement_grid(self)
  let scrollback = kitty_placement_scrollback(self)
  let size = self.grid_size()
  if size.cols() == 0U || size.rows() == 0U {
    return None
  }

  let top_left = match scrollback.point_from_pin(grid, pin_id, Tag::Screen) {
    Some(value) => value
    None => return None
  }
  let pin_x = match scrollback.pin_x(pin_id) {
    Some(value) => value
    None => return None
  }
  let total_rows = scrollback.total_rows(grid.rows).reinterpret_as_int()
  if total_rows <= 0 {
    return None
  }

  let end_y = kitty_min_int(
    top_left.y().reinterpret_as_int() + size.rows().reinterpret_as_int() - 1,
    total_rows - 1,
  )
  let end_x = kitty_min_int(
    pin_x.to_int() + size.cols().reinterpret_as_int() - 1,
    grid.cols.to_int() - 1,
  )
  let bottom_right = Coordinate::new(
    end_x.to_uint16(),
    end_y.reinterpret_as_uint(),
  )
  Some(Selection::new(top_left, bottom_right, true))
}

///|
pub fn KittyPlacement::pixel_size(
  self : KittyPlacement,
) -> KittyPlacementPixelSize {
  let grid = kitty_placement_grid(self)
  let pixel_size = self.placement.pixel_size(
    kitty_private_image(self.image_snapshot),
    grid.cols,
    grid.rows,
    self.bridge.width_px,
    self.bridge.height_px,
  )
  { width: pixel_size.width, height: pixel_size.height }
}

///|
pub fn KittyPlacement::grid_size(
  self : KittyPlacement,
) -> KittyPlacementGridSize {
  let grid = kitty_placement_grid(self)
  let grid_size = self.placement.grid_size(
    kitty_private_image(self.image_snapshot),
    grid.cols,
    grid.rows,
    self.bridge.width_px,
    self.bridge.height_px,
  )
  { cols: grid_size.cols, rows: grid_size.rows }
}

///|
pub fn KittyPlacement::viewport_position(
  self : KittyPlacement,
) -> KittyPlacementViewportPosition? {
  let pin_id = match self.placement.location {
    Pin(id) => id
    Virtual => return None
  }
  let grid = kitty_placement_grid(self)
  let scrollback = kitty_placement_scrollback(self)
  let screen = scrollback.point_from_pin(grid, pin_id, Tag::Screen)
  let pin_x = match scrollback.pin_x(pin_id) {
    Some(value) => value
    None => return None
  }
  match screen {
    None => None
    Some(screen_coord) => {
      let size = self.grid_size()
      let row = screen_coord.y().reinterpret_as_int() -
        scrollback.viewport_row_offset()
      let bottom = row + size.rows().reinterpret_as_int()
      if bottom <= 0 || row >= grid.rows.to_int() {
        None
      } else {
        Some({ col: pin_x.to_int(), row })
      }
    }
  }
}

///|
pub fn KittyPlacement::source_rect(
  self : KittyPlacement,
) -> KittyPlacementSourceRect {
  let rect = self.placement.source_rect(
    kitty_private_image(self.image_snapshot),
  )
  { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
}

///|
pub fn KittyPlacement::render_info(
  self : KittyPlacement,
) -> KittyPlacementRenderInfo {
  {
    pixel_size: self.pixel_size(),
    grid_size: self.grid_size(),
    viewport_position: self.viewport_position(),
    source_rect: self.source_rect(),
  }
}

///|
pub fn KittyPlacementPixelSize::width(self : KittyPlacementPixelSize) -> UInt {
  self.width
}

///|
pub fn KittyPlacementPixelSize::height(self : KittyPlacementPixelSize) -> UInt {
  self.height
}

///|
pub fn KittyPlacementGridSize::cols(self : KittyPlacementGridSize) -> UInt {
  self.cols
}

///|
pub fn KittyPlacementGridSize::rows(self : KittyPlacementGridSize) -> UInt {
  self.rows
}

///|
pub fn KittyPlacementSourceRect::x(self : KittyPlacementSourceRect) -> UInt {
  self.x
}

///|
pub fn KittyPlacementSourceRect::y(self : KittyPlacementSourceRect) -> UInt {
  self.y
}

///|
pub fn KittyPlacementSourceRect::width(self : KittyPlacementSourceRect) -> UInt {
  self.width
}

///|
pub fn KittyPlacementSourceRect::height(
  self : KittyPlacementSourceRect,
) -> UInt {
  self.height
}

///|
pub fn KittyPlacementViewportPosition::col(
  self : KittyPlacementViewportPosition,
) -> Int {
  self.col
}

///|
pub fn KittyPlacementViewportPosition::row(
  self : KittyPlacementViewportPosition,
) -> Int {
  self.row
}

///|
pub fn KittyPlacementRenderInfo::pixel_size(
  self : KittyPlacementRenderInfo,
) -> KittyPlacementPixelSize {
  self.pixel_size
}

///|
pub fn KittyPlacementRenderInfo::grid_size(
  self : KittyPlacementRenderInfo,
) -> KittyPlacementGridSize {
  self.grid_size
}

///|
pub fn KittyPlacementRenderInfo::viewport_position(
  self : KittyPlacementRenderInfo,
) -> KittyPlacementViewportPosition? {
  self.viewport_position
}

///|
pub fn KittyPlacementRenderInfo::source_rect(
  self : KittyPlacementRenderInfo,
) -> KittyPlacementSourceRect {
  self.source_rect
}

///|
fn kitty_public_placements(
  owner : KittyGraphics,
  layer : KittyPlacementLayer,
) -> Array[KittyPlacement] {
  let result : Array[KittyPlacement] = []
  for placement in kitty_graphics_owner_state(owner).placements() {
    if !layer.matches(placement.z) {
      continue
    }
    match kitty_graphics_owner_state(owner).image_by_id(placement.image_id) {
      Some(image) =>
        result.push({
          bridge: owner.bridge,
          screen: owner.screen,
          image_snapshot: kitty_public_image(image),
          placement,
        })
      None => ()
    }
  }
  result
}

///|
fn KittyPlacementLayer::matches(self : KittyPlacementLayer, z : Int) -> Bool {
  match self {
    All => true
    BelowBackground => z < KittyPlacementBelowBackgroundThreshold
    BelowText => z >= KittyPlacementBelowBackgroundThreshold && z < 0
    AboveText => z >= 0
  }
}

///|
fn kitty_public_image(image : KittyGraphicsImage) -> KittyImage {
  {
    id: image.id,
    number: image.number,
    width: image.width,
    height: image.height,
    format_: kitty_public_format(image.format),
    compression_: kitty_public_compression(image.compression),
    data: image.data,
  }
}

///|
fn kitty_private_image(image : KittyImage) -> KittyGraphicsImage {
  {
    id: image.id(),
    number: image.number(),
    width: image.width(),
    height: image.height(),
    format: match image.format() {
      KittyGraphicsFormat::Rgb => KittyImageFormat::Rgb
      KittyGraphicsFormat::Rgba => KittyImageFormat::Rgba
      KittyGraphicsFormat::Png => KittyImageFormat::Png
    },
    compression: match image.compression() {
      KittyGraphicsCompression::None => KittyImageCompression::None
      KittyGraphicsCompression::ZlibDeflate =>
        KittyImageCompression::ZlibDeflate
    },
    data: image.data(),
    implicit_id: false,
    transmit_seq: 0UL,
  }
}

///|
fn kitty_public_format(format : KittyImageFormat) -> KittyGraphicsFormat {
  match format {
    KittyImageFormat::Rgb => KittyGraphicsFormat::Rgb
    KittyImageFormat::Rgba => KittyGraphicsFormat::Rgba
    KittyImageFormat::Png => KittyGraphicsFormat::Png
  }
}

///|
fn kitty_public_compression(
  compression : KittyImageCompression,
) -> KittyGraphicsCompression {
  match compression {
    KittyImageCompression::None => KittyGraphicsCompression::None
    KittyImageCompression::ZlibDeflate => KittyGraphicsCompression::ZlibDeflate
  }
}

///|
fn kitty_graphics_owner_state(owner : KittyGraphics) -> KittyGraphicsState {
  if owner.screen == owner.bridge.active_screen {
    owner.bridge.kitty_graphics
  } else {
    match owner.screen {
      TerminalScreen::Primary => owner.bridge.primary_storage.kitty_graphics
      TerminalScreen::Alternate => owner.bridge.alternate_storage.kitty_graphics
    }
  }
}

///|
fn kitty_placement_grid(placement : KittyPlacement) -> ScreenGridState {
  if placement.screen == placement.bridge.active_screen {
    placement.bridge.grid
  } else {
    match placement.screen {
      TerminalScreen::Primary => placement.bridge.primary_storage.grid
      TerminalScreen::Alternate => placement.bridge.alternate_storage.grid
    }
  }
}

///|
fn kitty_placement_scrollback(placement : KittyPlacement) -> PageList {
  if placement.screen == placement.bridge.active_screen {
    placement.bridge.scrollback
  } else {
    match placement.screen {
      TerminalScreen::Primary => placement.bridge.primary_storage.scrollback
      TerminalScreen::Alternate => placement.bridge.alternate_storage.scrollback
    }
  }
}

///|
fn kitty_min_int(left : Int, right : Int) -> Int {
  if left <= right {
    left
  } else {
    right
  }
}
