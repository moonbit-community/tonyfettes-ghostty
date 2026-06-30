///|
test "glyph fields" {
  let glyph = Glyph::{
    width: 10U,
    height: 11U,
    offset_x: -1,
    offset_y: 2,
    atlas_x: 30U,
    atlas_y: 40U,
  }
  assert_eq(glyph.width, 10U)
  assert_eq(glyph.height, 11U)
  assert_eq(glyph.offset_x, -1)
  assert_eq(glyph.offset_y, 2)
  assert_eq(glyph.atlas_x, 30U)
  assert_eq(glyph.atlas_y, 40U)
}

///|
test "face metrics estimates and calc" {
  let face : FaceMetrics = {
    px_per_em: 16.0,
    cell_width: 8.4,
    ascent: 12.0,
    descent: -4.0,
    line_gap: 2.0,
    underline_position: None,
    underline_thickness: None,
    strikethrough_position: None,
    strikethrough_thickness: None,
    cap_height: None,
    ex_height: None,
    ascii_height: None,
    ic_width: None,
  }
  assert_eq(face.line_height(), 18.0)
  assert_eq(face.cap_height(), 9.0)
  assert_eq(face.ex_height(), 6.75)
  assert_eq(face.ascii_height(), 13.5)
  assert_eq(face.ic_width(), 13.5)
  assert_eq(face.underline_thickness(), 1.0125)
  assert_eq(face.strikethrough_thickness(), 1.0125)
  assert_eq(face.underline_position(), -1.0125)
  assert_eq(face.strikethrough_position(), 3.88125)

  let metrics = Metrics::calc(face)
  assert_eq(metrics.cell_width, 8U)
  assert_eq(metrics.cell_height, 18U)
  assert_eq(metrics.cell_baseline, 5U)
  assert_eq(metrics.underline_thickness, 2U)
  assert_eq(metrics.strikethrough_thickness, 2U)
  assert_eq(metrics.cursor_thickness, 1U)
  assert_eq(metrics.cursor_height, 18U)
  assert_eq(metrics.face_width, 8.4)
  assert_eq(metrics.face_height, 18.0)
}

///|
test "face metrics explicit values override estimates" {
  let face : FaceMetrics = {
    px_per_em: 16.0,
    cell_width: 8.0,
    ascent: 12.0,
    descent: -4.0,
    line_gap: 2.0,
    underline_position: Some(-2.0),
    underline_thickness: Some(3.0),
    strikethrough_position: Some(5.0),
    strikethrough_thickness: Some(4.0),
    cap_height: Some(10.0),
    ex_height: Some(6.0),
    ascii_height: Some(14.0),
    ic_width: Some(15.0),
  }
  assert_eq(face.cap_height(), 10.0)
  assert_eq(face.ex_height(), 6.0)
  assert_eq(face.ascii_height(), 14.0)
  assert_eq(face.ic_width(), 15.0)
  assert_eq(face.underline_thickness(), 3.0)
  assert_eq(face.strikethrough_thickness(), 4.0)
  assert_eq(face.underline_position(), -2.0)
  assert_eq(face.strikethrough_position(), 5.0)
}

///|
test "face metrics ic width estimate is capped by double cell width" {
  let face : FaceMetrics = {
    px_per_em: 20.0,
    cell_width: 4.0,
    ascent: 20.0,
    descent: -5.0,
    line_gap: 0.0,
    underline_position: None,
    underline_thickness: None,
    strikethrough_position: None,
    strikethrough_thickness: None,
    cap_height: None,
    ex_height: None,
    ascii_height: None,
    ic_width: None,
  }
  assert_eq(face.ic_width(), 8.0)
}

///|
test "metric modifier parse" {
  guard Modifier::parse("100") == Absolute(100) else {
    fail("expected absolute modifier")
  }
  guard Modifier::parse("-100") == Absolute(-100) else {
    fail("expected negative absolute modifier")
  }
  guard Modifier::parse("20%") == Percent(1.2) else {
    fail("expected positive percent modifier")
  }
  guard Modifier::parse("-20%") == Percent(0.8) else {
    fail("expected negative percent modifier")
  }
  guard Modifier::parse("-120%") == Percent(0.0) else {
    fail("expected percent lower bound clamp")
  }
  try Modifier::parse("") catch {
    InvalidFormat => ()
  } noraise {
    _ => fail("expected empty metric modifier to be invalid")
  }
  try Modifier::parse("%") catch {
    InvalidFormat => ()
  } noraise {
    _ => fail("expected missing percent value to be invalid")
  }
  try Modifier::parse("abc%") catch {
    InvalidFormat => ()
  } noraise {
    _ => fail("expected invalid percent value to be invalid")
  }
  try Modifier::parse("abc") catch {
    InvalidFormat => ()
  } noraise {
    _ => fail("expected invalid absolute value to be invalid")
  }
}

///|
test "metric modifier set lookup" {
  let set = ModifierSet::new()
  guard set.get(CellWidth) == None else {
    fail("expected empty modifier set lookup")
  }
  set.set(CellWidth, Percent(1.2))
  guard set.get(CellWidth) == Some(Percent(1.2)) else {
    fail("expected modifier set lookup")
  }
}

///|
test "font variation id init and str" {
  let id = FontVariationId::init(b"wght".view())
  guard id == { a: b'w', b: b'g', c: b'h', d: b't' } else {
    fail("expected variation id fields")
  }
  assert_eq(id.str(), b"wght")
}

///|
test "panic font variation id requires four bytes" {
  ignore(FontVariationId::init(b"wgh".view()))
}

///|
test "descriptor hash and variation copy" {
  let variation = FontVariation::{
    id: { a: b'w', b: b'g', c: b'h', d: b't' },
    value: 700.5,
  }
  let variations = [variation]
  let descriptor = Descriptor::new(
    family=Some("A"),
    style=Some("Regular"),
    codepoint=65U,
    size=12.0,
    bold=true,
    variations~,
  )
  variations.push({ id: { a: b's', b: b'l', c: b'n', d: b't' }, value: -5.0 })

  guard descriptor.family == Some("A") else {
    fail("expected descriptor family")
  }
  guard descriptor.style == Some("Regular") else {
    fail("expected descriptor style")
  }
  assert_eq(descriptor.codepoint, 65U)
  assert_eq(descriptor.size, 12.0)
  assert_eq(descriptor.bold, true)
  assert_eq(descriptor.italic, false)
  assert_eq(descriptor.monospace, false)
  assert_eq(descriptor.variations.length(), 1)
  guard descriptor.hashcode() != 0U else {
    fail("descriptor hash should include populated fields")
  }
  let other = Descriptor::new(family=Some("B"))
  guard descriptor.hashcode() != other.hashcode() else {
    fail("descriptor family names should affect hash")
  }

  let fractional = Descriptor::new(
    family=Some("A"),
    style=Some("Regular"),
    codepoint=65U,
    size=12.0,
    bold=true,
    variations=[{ id: { a: b'w', b: b'g', c: b'h', d: b't' }, value: 700.6 }],
  )
  guard descriptor.hashcode() == fractional.hashcode() else {
    fail("descriptor variation hash follows upstream integer truncation")
  }
}

///|
test "codepoint map lookup priority and hash" {
  let map = CodepointMap::new()
  guard map.get(1U) == None else { fail("expected empty map miss") }
  map.add({ range: (1U, 1U), descriptor: Descriptor::new(family=Some("A")) })
  guard map.get(1U) is Some(first) && first.family == Some("A") else {
    fail("expected exact range lookup")
  }

  map.add({ range: (1U, 2U), descriptor: Descriptor::new(family=Some("B")) })
  guard map.get(1U) is Some(priority) && priority.family == Some("B") else {
    fail("expected later entry to take priority")
  }
  guard map.get(0U) == None else { fail("expected low miss") }
  guard map.get(3U) == None else { fail("expected high miss") }

  map.add({ range: (3U, 4U), descriptor: Descriptor::new(family=Some("C")) })
  map.add({ range: (5U, 6U), descriptor: Descriptor::new(family=Some("D")) })
  guard map.get(3U) is Some(c) && c.family == Some("C") else {
    fail("expected independent later range")
  }
  guard map.get(1U) is Some(b) && b.family == Some("B") else {
    fail("expected prior priority range to remain")
  }

  let same = CodepointMap::new()
  same.add({ range: (1U, 1U), descriptor: Descriptor::new(family=Some("A")) })
  same.add({ range: (1U, 2U), descriptor: Descriptor::new(family=Some("B")) })
  same.add({ range: (3U, 4U), descriptor: Descriptor::new(family=Some("C")) })
  same.add({ range: (5U, 6U), descriptor: Descriptor::new(family=Some("D")) })
  assert_eq(map.hashcode(), same.hashcode())
  let different = CodepointMap::new()
  different.add({
    range: (1U, 1U),
    descriptor: Descriptor::new(family=Some("A")),
  })
  guard map.hashcode() != different.hashcode() else {
    fail("codepoint map hash should include all entries")
  }
}
