///|
fn metrics_init() -> Metrics {
  {
    cell_width: 0U,
    cell_height: 0U,
    cell_baseline: 0U,
    underline_position: 0U,
    underline_thickness: 0U,
    strikethrough_position: 0U,
    strikethrough_thickness: 0U,
    overline_position: 0,
    overline_thickness: 0U,
    box_thickness: 0U,
    cursor_thickness: 1U,
    cursor_height: 0U,
    icon_height: 0.0,
    icon_height_single: 0.0,
    face_width: 0.0,
    face_height: 0.0,
    face_y: 0.0,
  }
}

///|
fn apply_one(metrics : Metrics, key : MetricKey, modifier : Modifier) -> Unit {
  let set = ModifierSet::new()
  set.set(key, modifier)
  metrics.apply(set)
}

///|
test "Metrics: apply modifiers" {
  let set = ModifierSet::new()
  set.set(CellWidth, Percent(1.2))

  let metrics = metrics_init()
  metrics.cell_width = 100U
  metrics.apply(set)
  assert_eq(metrics.cell_width, 120U)
}

///|
test "Metrics: adjust cell height smaller" {
  let set = ModifierSet::new()
  set.set(CellHeight, Percent(0.75))

  let metrics = metrics_init()
  metrics.face_y = 0.33
  metrics.cell_baseline = 50U
  metrics.underline_position = 55U
  metrics.strikethrough_position = 30U
  metrics.overline_position = 0
  metrics.cell_height = 100U
  metrics.face_height = 99.67
  metrics.cursor_height = 100U
  metrics.apply(set)
  assert_eq(metrics.face_y, -12.67)
  assert_eq(metrics.cell_height, 75U)
  assert_eq(metrics.cell_baseline, 37U)
  assert_eq(metrics.underline_position, 43U)
  assert_eq(metrics.strikethrough_position, 18U)
  assert_eq(metrics.overline_position, -12)
  assert_eq(metrics.cursor_height, 100U)
}

///|
test "Metrics: adjust cell height larger" {
  let set = ModifierSet::new()
  set.set(CellHeight, Percent(1.75))

  let metrics = metrics_init()
  metrics.face_y = 0.33
  metrics.cell_baseline = 50U
  metrics.underline_position = 55U
  metrics.strikethrough_position = 30U
  metrics.overline_position = 0
  metrics.cell_height = 100U
  metrics.face_height = 99.67
  metrics.cursor_height = 100U
  metrics.apply(set)
  assert_eq(metrics.face_y, 37.33)
  assert_eq(metrics.cell_height, 175U)
  assert_eq(metrics.cell_baseline, 87U)
  assert_eq(metrics.underline_position, 93U)
  assert_eq(metrics.strikethrough_position, 68U)
  assert_eq(metrics.overline_position, 38)
  assert_eq(metrics.cursor_height, 100U)
}

///|
test "Metrics: adjust cell height larger when face is low" {
  let set = ModifierSet::new()
  set.set(CellHeight, Percent(1.75))

  let metrics = metrics_init()
  metrics.face_y = 0.0
  metrics.cell_baseline = 50U
  metrics.underline_position = 55U
  metrics.strikethrough_position = 30U
  metrics.overline_position = 0
  metrics.cell_height = 100U
  metrics.face_height = 99.67
  metrics.cursor_height = 100U
  metrics.apply(set)
  assert_eq(metrics.face_y, 38.0)
  assert_eq(metrics.cell_height, 175U)
  assert_eq(metrics.cell_baseline, 88U)
  assert_eq(metrics.underline_position, 92U)
  assert_eq(metrics.strikethrough_position, 67U)
  assert_eq(metrics.overline_position, 37)
  assert_eq(metrics.cursor_height, 100U)
}

///|
test "Metrics: adjust icon height by percentage" {
  let set = ModifierSet::new()
  set.set(IconHeight, Percent(0.75))

  let metrics = metrics_init()
  metrics.icon_height = 100.0
  metrics.icon_height_single = 80.0
  metrics.face_height = 100.0
  metrics.face_y = 1.0
  metrics.apply(set)
  assert_eq(metrics.icon_height, 75.0)
  assert_eq(metrics.icon_height_single, 60.0)
  assert_eq(metrics.face_height, 100.0)
  assert_eq(metrics.face_y, 1.0)
}

///|
test "Metrics: adjust icon height by absolute pixels" {
  let set = ModifierSet::new()
  set.set(IconHeight, Absolute(-5))

  let metrics = metrics_init()
  metrics.icon_height = 100.0
  metrics.icon_height_single = 80.0
  metrics.face_height = 100.0
  metrics.face_y = 1.0
  metrics.apply(set)
  assert_eq(metrics.icon_height, 95.0)
  assert_eq(metrics.icon_height_single, 75.0)
  assert_eq(metrics.face_height, 100.0)
  assert_eq(metrics.face_y, 1.0)
}

///|
test "Metrics: apply remaining modifiers" {
  let baseline = metrics_init()
  baseline.cell_baseline = 10U
  apply_one(baseline, CellBaseline, Absolute(5))
  assert_eq(baseline.cell_baseline, 15U)

  let underline_position = metrics_init()
  underline_position.underline_position = 10U
  apply_one(underline_position, UnderlinePosition, Absolute(5))
  assert_eq(underline_position.underline_position, 15U)

  let underline_thickness = metrics_init()
  underline_thickness.underline_thickness = 10U
  apply_one(underline_thickness, UnderlineThickness, Percent(1.5))
  assert_eq(underline_thickness.underline_thickness, 15U)

  let strikethrough_position = metrics_init()
  strikethrough_position.strikethrough_position = 10U
  apply_one(strikethrough_position, StrikethroughPosition, Absolute(5))
  assert_eq(strikethrough_position.strikethrough_position, 15U)

  let strikethrough_thickness = metrics_init()
  strikethrough_thickness.strikethrough_thickness = 10U
  apply_one(strikethrough_thickness, StrikethroughThickness, Percent(1.5))
  assert_eq(strikethrough_thickness.strikethrough_thickness, 15U)

  let overline_position = metrics_init()
  overline_position.overline_position = 10
  apply_one(overline_position, OverlinePosition, Absolute(-3))
  assert_eq(overline_position.overline_position, 7)

  let overline_thickness = metrics_init()
  overline_thickness.overline_thickness = 10U
  apply_one(overline_thickness, OverlineThickness, Absolute(5))
  assert_eq(overline_thickness.overline_thickness, 15U)

  let box_thickness = metrics_init()
  box_thickness.box_thickness = 10U
  apply_one(box_thickness, BoxThickness, Absolute(5))
  assert_eq(box_thickness.box_thickness, 15U)

  let cursor_thickness = metrics_init()
  cursor_thickness.cursor_thickness = 10U
  apply_one(cursor_thickness, CursorThickness, Absolute(5))
  assert_eq(cursor_thickness.cursor_thickness, 15U)

  let cursor_height = metrics_init()
  cursor_height.cursor_height = 10U
  apply_one(cursor_height, CursorHeight, Absolute(5))
  assert_eq(cursor_height.cursor_height, 15U)

  let icon_height_single = metrics_init()
  icon_height_single.icon_height_single = 10.0
  apply_one(icon_height_single, IconHeightSingle, Absolute(5))
  assert_eq(icon_height_single.icon_height_single, 15.0)

  let face_width = metrics_init()
  face_width.face_width = 10.0
  apply_one(face_width, FaceWidth, Absolute(5))
  assert_eq(face_width.face_width, 15.0)

  let face_height = metrics_init()
  face_height.face_height = 10.0
  apply_one(face_height, FaceHeight, Absolute(5))
  assert_eq(face_height.face_height, 15.0)

  let face_y = metrics_init()
  face_y.face_y = 10.0
  apply_one(face_y, FaceY, Percent(1.5))
  assert_eq(face_y.face_y, 15.0)
}

///|
test "Metrics: fields expose all values" {
  let metrics = metrics_init()
  metrics.cell_width = 2U
  metrics.cell_height = 3U
  metrics.cell_baseline = 4U
  metrics.underline_position = 5U
  metrics.underline_thickness = 6U
  metrics.strikethrough_position = 7U
  metrics.strikethrough_thickness = 8U
  metrics.overline_position = -9
  metrics.overline_thickness = 10U
  metrics.box_thickness = 11U
  metrics.cursor_thickness = 12U
  metrics.cursor_height = 13U
  metrics.icon_height = 14.0
  metrics.icon_height_single = 15.0
  metrics.face_width = 16.0
  metrics.face_height = 17.0
  metrics.face_y = 18.0
  assert_eq(metrics.cell_width, 2U)
  assert_eq(metrics.cell_height, 3U)
  assert_eq(metrics.cell_baseline, 4U)
  assert_eq(metrics.underline_position, 5U)
  assert_eq(metrics.underline_thickness, 6U)
  assert_eq(metrics.strikethrough_position, 7U)
  assert_eq(metrics.strikethrough_thickness, 8U)
  assert_eq(metrics.overline_position, -9)
  assert_eq(metrics.overline_thickness, 10U)
  assert_eq(metrics.box_thickness, 11U)
  assert_eq(metrics.cursor_thickness, 12U)
  assert_eq(metrics.cursor_height, 13U)
  assert_eq(metrics.icon_height, 14.0)
  assert_eq(metrics.icon_height_single, 15.0)
  assert_eq(metrics.face_width, 16.0)
  assert_eq(metrics.face_height, 17.0)
  assert_eq(metrics.face_y, 18.0)
}

///|
test "Modifier: direct application and clamps" {
  assert_eq(Percent(0.8).apply_uint(100U), 80U)
  assert_eq(Percent(1.8).apply_uint(100U), 180U)
  assert_eq(Percent(0.5).apply_int(10), 5)
  assert_eq(Absolute(-100).apply_uint(100U), 0U)
  assert_eq(Absolute(-120).apply_uint(100U), 0U)
  assert_eq(Absolute(100).apply_uint(100U), 200U)
  assert_eq(Absolute(10).apply_uint(4294967290U), 4294967295U)
  assert_eq(Absolute(-5).apply_int(3), -2)
  assert_eq(Absolute(-1).apply_int(-2147483648), -2147483648)
  assert_eq(Absolute(1).apply_int(2147483647), 2147483647)
  assert_eq(Percent(-1.0).apply_double(3.0), 0.0)
}
