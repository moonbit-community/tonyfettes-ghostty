///|
pub(all) struct FaceMetrics {
  px_per_em : Double
  cell_width : Double
  ascent : Double
  descent : Double
  line_gap : Double
  underline_position : Double?
  underline_thickness : Double?
  strikethrough_position : Double?
  strikethrough_thickness : Double?
  cap_height : Double?
  ex_height : Double?
  ascii_height : Double?
  ic_width : Double?
} derive(Eq, Debug)

///|
pub fn FaceMetrics::line_height(self : FaceMetrics) -> Double {
  self.ascent - self.descent + self.line_gap
}

///|
pub fn FaceMetrics::cap_height(self : FaceMetrics) -> Double {
  match self.cap_height {
    Some(value) if value > 0.0 => value
    _ => 0.75 * self.ascent
  }
}

///|
pub fn FaceMetrics::ex_height(self : FaceMetrics) -> Double {
  match self.ex_height {
    Some(value) if value > 0.0 => value
    _ => 0.75 * self.cap_height()
  }
}

///|
pub fn FaceMetrics::ascii_height(self : FaceMetrics) -> Double {
  match self.ascii_height {
    Some(value) if value > 0.0 => value
    _ => 1.5 * self.cap_height()
  }
}

///|
pub fn FaceMetrics::ic_width(self : FaceMetrics) -> Double {
  match self.ic_width {
    Some(value) if value > 0.0 => value
    _ => min_double(self.ascii_height(), 2.0 * self.cell_width)
  }
}

///|
pub fn FaceMetrics::underline_thickness(self : FaceMetrics) -> Double {
  match self.underline_thickness {
    Some(value) if value > 0.0 => value
    _ => 0.15 * self.ex_height()
  }
}

///|
pub fn FaceMetrics::strikethrough_thickness(self : FaceMetrics) -> Double {
  match self.strikethrough_thickness {
    Some(value) if value > 0.0 => value
    _ => self.underline_thickness()
  }
}

///|
pub fn FaceMetrics::underline_position(self : FaceMetrics) -> Double {
  self.underline_position.unwrap_or(-self.underline_thickness())
}

///|
pub fn FaceMetrics::strikethrough_position(self : FaceMetrics) -> Double {
  self.strikethrough_position.unwrap_or(
    (self.ex_height() + self.strikethrough_thickness()) * 0.5,
  )
}

///|
pub(all) struct Metrics {
  mut cell_width : UInt
  mut cell_height : UInt
  mut cell_baseline : UInt
  mut underline_position : UInt
  mut underline_thickness : UInt
  mut strikethrough_position : UInt
  mut strikethrough_thickness : UInt
  mut overline_position : Int
  mut overline_thickness : UInt
  mut box_thickness : UInt
  mut cursor_thickness : UInt
  mut cursor_height : UInt
  mut icon_height : Double
  mut icon_height_single : Double
  mut face_width : Double
  mut face_height : Double
  mut face_y : Double
} derive(Eq, Debug)

///|
pub(all) enum MetricKey {
  CellWidth
  CellHeight
  CellBaseline
  UnderlinePosition
  UnderlineThickness
  StrikethroughPosition
  StrikethroughThickness
  OverlinePosition
  OverlineThickness
  BoxThickness
  CursorThickness
  CursorHeight
  IconHeight
  IconHeightSingle
  FaceWidth
  FaceHeight
  FaceY
} derive(Eq, Debug, Hash)

///|
pub suberror ModifierParseError {
  InvalidFormat
} derive(Eq, Debug)

///|
pub(all) enum Modifier {
  Percent(Double)
  Absolute(Int)
} derive(Eq, Debug)

///|
struct ModifierSet(@hashmap.HashMap[MetricKey, Modifier])

///|
pub fn ModifierSet::new() -> ModifierSet {
  ModifierSet(HashMap([]))
}

///|
pub fn ModifierSet::set(
  self : ModifierSet,
  key : MetricKey,
  modifier : Modifier,
) -> Unit {
  self.0.set(key, modifier)
}

///|
pub fn ModifierSet::get(self : ModifierSet, key : MetricKey) -> Modifier? {
  self.0.get(key)
}

///|
pub fn Modifier::parse(input : String) -> Modifier raise ModifierParseError {
  if input is "" {
    raise InvalidFormat
  }
  match input {
    [.. number, .. "%"] => {
      if number is "" {
        raise InvalidFormat
      }
      let percent = @string.parse_double(number) catch {
        _ => raise InvalidFormat
      }
      let scaled = percent / 100.0
      Percent(if scaled <= -1.0 { 0.0 } else { 1.0 + scaled })
    }
    _ => {
      let absolute = @string.parse_int(input) catch { _ => raise InvalidFormat }
      Absolute(absolute)
    }
  }
}

///|
pub fn Metrics::calc(face : FaceMetrics) -> Metrics {
  let face_width = face.cell_width
  let face_height = face.line_height()
  let cell_width = @math.round(face_width)
  let cell_height = @math.round(face_height)
  let half_line_gap = face.line_gap / 2.0
  let face_baseline = half_line_gap - face.descent
  let cell_baseline = @math.round(
    face_baseline - (cell_height - face_height) / 2.0,
  )
  let face_y = cell_baseline - face_baseline
  let top_to_baseline = cell_height - cell_baseline
  let cap_height = face.cap_height()
  let underline_thickness = max_double(
    1.0,
    @math.ceil(face.underline_thickness()),
  )
  let strikethrough_thickness = max_double(
    1.0,
    @math.ceil(face.strikethrough_thickness()),
  )
  let underline_position = @math.round(
    top_to_baseline - face.underline_position(),
  )
  let strikethrough_position = @math.round(
    top_to_baseline - face.strikethrough_position(),
  )
  let icon_height = face_height
  let icon_height_single = (2.0 * cap_height + face_height) / 3.0
  let result = {
    cell_width: cell_width.to_uint(),
    cell_height: cell_height.to_uint(),
    cell_baseline: cell_baseline.to_uint(),
    underline_position: underline_position.to_uint(),
    underline_thickness: underline_thickness.to_uint(),
    strikethrough_position: strikethrough_position.to_uint(),
    strikethrough_thickness: strikethrough_thickness.to_uint(),
    overline_position: 0,
    overline_thickness: underline_thickness.to_uint(),
    box_thickness: underline_thickness.to_uint(),
    cursor_thickness: 1U,
    cursor_height: cell_height.to_uint(),
    icon_height,
    icon_height_single,
    face_width,
    face_height,
    face_y,
  }
  result.clamp()
  result
}

///|
pub fn Metrics::apply(self : Metrics, mods : ModifierSet) -> Unit {
  for entry in mods.0.iter() {
    let key = entry.0
    let modifier = entry.1
    match key {
      CellWidth => {
        let original = self.cell_width
        let next = max_uint(modifier.apply_uint(original), 1U)
        if next != original {
          self.cell_width = next
        }
      }
      CellHeight => {
        let original = self.cell_height
        let next = max_uint(modifier.apply_uint(original), 1U)
        if next != original {
          self.cell_height = next
          self.adjust_cell_height_positions(original, next)
        }
      }
      CellBaseline =>
        self.cell_baseline = modifier.apply_uint(self.cell_baseline)
      UnderlinePosition =>
        self.underline_position = modifier.apply_uint(self.underline_position)
      UnderlineThickness =>
        self.underline_thickness = modifier.apply_uint(self.underline_thickness)
      StrikethroughPosition =>
        self.strikethrough_position = modifier.apply_uint(
          self.strikethrough_position,
        )
      StrikethroughThickness =>
        self.strikethrough_thickness = modifier.apply_uint(
          self.strikethrough_thickness,
        )
      OverlinePosition =>
        self.overline_position = modifier.apply_int(self.overline_position)
      OverlineThickness =>
        self.overline_thickness = modifier.apply_uint(self.overline_thickness)
      BoxThickness =>
        self.box_thickness = modifier.apply_uint(self.box_thickness)
      CursorThickness =>
        self.cursor_thickness = modifier.apply_uint(self.cursor_thickness)
      CursorHeight =>
        self.cursor_height = modifier.apply_uint(self.cursor_height)
      IconHeight => {
        self.icon_height = modifier.apply_double(self.icon_height)
        self.icon_height_single = modifier.apply_double(self.icon_height_single)
      }
      IconHeightSingle =>
        self.icon_height_single = modifier.apply_double(self.icon_height_single)
      FaceWidth => self.face_width = modifier.apply_double(self.face_width)
      FaceHeight => self.face_height = modifier.apply_double(self.face_height)
      FaceY => self.face_y = modifier.apply_double(self.face_y)
    }
  }
  self.clamp()
}

///|
fn Metrics::adjust_cell_height_positions(
  self : Metrics,
  original : UInt,
  next : UInt,
) -> Unit {
  let original_f64 = original.to_double()
  let next_f64 = next.to_double()
  let diff = next_f64 - original_f64
  let half_diff = diff / 2.0
  let position_with_respect_to_center = self.face_y -
    (original_f64 - self.face_height) / 2.0
  let (diff_top, diff_bottom) = if position_with_respect_to_center > 0.0 {
    (@math.ceil(half_diff), @math.floor(half_diff))
  } else {
    (@math.floor(half_diff), @math.ceil(half_diff))
  }
  self.cell_baseline = add_double_to_uint(self.cell_baseline, diff_bottom)
  self.face_y = self.face_y + diff_bottom
  self.underline_position = add_double_to_uint(
    self.underline_position,
    diff_top,
  )
  self.strikethrough_position = add_double_to_uint(
    self.strikethrough_position,
    diff_top,
  )
  self.overline_position = add_double_to_int(self.overline_position, diff_top)
}

///|
fn Metrics::clamp(self : Metrics) -> Unit {
  self.cell_width = max_uint(self.cell_width, 1U)
  self.cell_height = max_uint(self.cell_height, 1U)
  self.underline_thickness = max_uint(self.underline_thickness, 1U)
  self.strikethrough_thickness = max_uint(self.strikethrough_thickness, 1U)
  self.overline_thickness = max_uint(self.overline_thickness, 1U)
  self.box_thickness = max_uint(self.box_thickness, 1U)
  self.cursor_thickness = max_uint(self.cursor_thickness, 1U)
  self.cursor_height = max_uint(self.cursor_height, 1U)
  self.icon_height = max_double(self.icon_height, 1.0)
  self.icon_height_single = max_double(self.icon_height_single, 1.0)
  self.face_width = max_double(self.face_width, 1.0)
  self.face_height = max_double(self.face_height, 1.0)
}

///|
fn Modifier::apply_uint(self : Modifier, value : UInt) -> UInt {
  match self {
    Percent(percent) =>
      @math.round(value.to_double() * nonnegative(percent)).to_uint()
    Absolute(delta) => clamp_int64_to_uint(value.to_int64() + delta.to_int64())
  }
}

///|
fn Modifier::apply_int(self : Modifier, value : Int) -> Int {
  match self {
    Percent(percent) =>
      @math.round(value.to_double() * nonnegative(percent)).to_int()
    Absolute(delta) => clamp_int64_to_int(value.to_int64() + delta.to_int64())
  }
}

///|
fn Modifier::apply_double(self : Modifier, value : Double) -> Double {
  match self {
    Percent(percent) => value * nonnegative(percent)
    Absolute(delta) => value + delta.to_double()
  }
}

///|
fn add_double_to_uint(value : UInt, delta : Double) -> UInt {
  clamp_int64_to_uint(value.to_int64() + delta.to_int64())
}

///|
fn add_double_to_int(value : Int, delta : Double) -> Int {
  clamp_int64_to_int(value.to_int64() + delta.to_int64())
}

///|
fn clamp_int64_to_uint(value : Int64) -> UInt {
  if value <= 0L {
    0U
  } else if value >= 4294967295L {
    4294967295U
  } else {
    value.reinterpret_as_uint64().to_uint()
  }
}

///|
fn clamp_int64_to_int(value : Int64) -> Int {
  if value <= -2147483648L {
    -2147483648
  } else if value >= 2147483647L {
    2147483647
  } else {
    value.to_int()
  }
}

///|
fn nonnegative(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn min_double(left : Double, right : Double) -> Double {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn max_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn max_uint(left : UInt, right : UInt) -> UInt {
  if left > right {
    left
  } else {
    right
  }
}
