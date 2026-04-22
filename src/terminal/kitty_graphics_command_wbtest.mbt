///|
fn kitty_graphics_bytes_array(bytes : Bytes) -> Array[Byte] {
  let result : Array[Byte] = []
  for byte in bytes {
    result.push(byte)
  }
  result
}

///|
fn kitty_graphics_pair(key : Byte, value : Bytes) -> KittyGraphicsPair {
  { key, value: kitty_graphics_bytes_array(value) }
}

///|
test "kitty graphics command/response and access helpers" {
  guard KittyImageFormat::Rgb.bytes_per_pixel() == 3U &&
    KittyImageFormat::Rgba.bytes_per_pixel() == 4U &&
    KittyImageFormat::Png.bytes_per_pixel() == 0U else {
    fail("expected bytes-per-pixel mapping")
  }

  let transmission = KittyImageTransmission::new()
  transmission.image_id = 7U
  let display = KittyImageDisplay::new()
  display.image_id = 7U

  let query : KittyGraphicsCommand = {
    control: Query(transmission),
    quiet: KittyGraphicsQuiet::No,
    data: b"",
  }
  let transmit_display : KittyGraphicsCommand = {
    control: TransmitAndDisplay({ transmission, display }),
    quiet: KittyGraphicsQuiet::No,
    data: b"",
  }
  let transmit : KittyGraphicsCommand = {
    control: Transmit(transmission),
    quiet: KittyGraphicsQuiet::No,
    data: b"",
  }
  let delete_command : KittyGraphicsCommand = {
    control: Delete(All(false)),
    quiet: KittyGraphicsQuiet::No,
    data: b"",
  }

  guard query.transmission() is Some(found_transmission) &&
    found_transmission.image_id == 7U else {
    fail("expected transmission accessor for query")
  }
  guard transmit.transmission() is Some(transmit_value) &&
    transmit_value.image_id == 7U else {
    fail("expected transmission accessor for transmit")
  }
  guard transmit_display.transmission() is Some(transmit_display_value) &&
    transmit_display_value.image_id == 7U else {
    fail("expected transmission accessor for transmit-display")
  }
  guard transmit_display.display() is Some(found_display) &&
    found_display.image_id == 7U else {
    fail("expected display accessor for transmit-display")
  }
  let display_only : KittyGraphicsCommand = {
    control: Display(display),
    quiet: KittyGraphicsQuiet::No,
    data: b"",
  }
  guard display_only.display() is Some(display_value) &&
    display_value.image_id == 7U else {
    fail("expected display accessor for display control")
  }
  guard delete_command.transmission() == None &&
    delete_command.display() == None else {
    fail("expected unrelated accessors to stay empty")
  }

  let empty = KittyGraphicsResponse::new()
  guard empty.empty() && empty.ok() && empty.encode() == b"" else {
    fail("expected empty response helpers")
  }

  let response = KittyGraphicsResponse::new(
    id=7U,
    image_number=9U,
    placement_id=3U,
    message=b"ERR",
  )
  guard !response.empty() && !response.ok() else {
    fail("expected non-empty response status")
  }
  guard response.encode() == b"\x1B_Gi=7,I=9,p=3;ERR\x1B\\" else {
    fail("expected encoded response with all identifiers")
  }
  let number_only = KittyGraphicsResponse::new(image_number=9U, placement_id=3U)
  guard number_only.encode() == b"\x1B_GI=9,p=3;OK\x1B\\" else {
    fail("expected encoded response without id prefix")
  }
}

///|
test "kitty graphics command/parses transmission display and delete controls" {
  guard parse_kitty_graphics_command_bytes(
      kitty_graphics_bytes_array(
        b"a=q,t=s,f=100,S=12,O=3,i=7,I=8,p=4,o=z;QUFBQQ==",
      ),
    )
    is Some(query) else {
    fail("expected kitty query parse")
  }
  guard query.quiet == KittyGraphicsQuiet::No else {
    fail("expected default quiet mode")
  }
  guard query.control is Query(value) &&
    value.format == Png &&
    value.medium == SharedMemory &&
    value.size == 12U &&
    value.offset == 3U &&
    value.image_id == 7U &&
    value.image_number == 8U &&
    value.placement_id == 4U &&
    value.compression == ZlibDeflate else {
    fail("expected parsed query control")
  }
  guard query.data == b"AAAA" else { fail("expected decoded query payload") }

  guard parse_kitty_graphics_command_bytes(
      kitty_graphics_bytes_array(
        b"a=p,i=9,p=2,x=4,y=5,w=6,h=7,X=8,Y=9,c=10,r=11,C=1,U=1,P=12,Q=13,H=-2,V=-3,z=-4",
      ),
    )
    is Some(display_command) else {
    fail("expected kitty display parse")
  }
  guard display_command.control is Display(display) &&
    display.image_id == 9U &&
    display.placement_id == 2U &&
    display.x == 4U &&
    display.y == 5U &&
    display.width == 6U &&
    display.height == 7U &&
    display.x_offset == 8U &&
    display.y_offset == 9U &&
    display.columns == 10U &&
    display.rows == 11U &&
    display.cursor_movement == KittyImageCursorMovement::None &&
    display.virtual_placement &&
    display.parent_id == 12U &&
    display.parent_placement_id == 13U &&
    display.horizontal_offset == -2 &&
    display.vertical_offset == -3 &&
    display.z == -4 else {
    fail("expected parsed display fields")
  }

  guard parse_kitty_graphics_command_bytes(
      kitty_graphics_bytes_array(b"a=d,d=N,I=5,p=2"),
    )
    is Some(delete_command) else {
    fail("expected kitty newest-delete parse")
  }
  guard delete_command.control is Delete(Newest(value)) &&
    value.delete &&
    value.image_number == 5U &&
    value.placement_id == 2U else {
    fail("expected parsed newest delete control")
  }
}

///|
test "kitty graphics command/delete parser covers selector families" {
  guard parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"a")]) ==
    Some(All(false)) else {
    fail("expected delete-all selector")
  }
  guard parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"A")]) ==
    Some(All(true)) else {
    fail("expected delete-all-images selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"i"),
      kitty_graphics_pair(b'i', b"1"),
      kitty_graphics_pair(b'p', b"2"),
    ])
    is Some(Id(value)) &&
    !value.delete &&
    value.image_id == 1U &&
    value.placement_id == 2U else {
    fail("expected delete-by-id selector")
  }
  guard parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"c")]) ==
    Some(IntersectCursor(false)) &&
    parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"C")]) ==
    Some(IntersectCursor(true)) &&
    parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"f")]) ==
    Some(AnimationFrames(false)) &&
    parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"F")]) ==
    Some(AnimationFrames(true)) else {
    fail("expected cursor and animation selectors")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"I"),
      kitty_graphics_pair(b'i', b"1"),
    ])
    is Some(Id(delete_id_value)) &&
    delete_id_value.delete &&
    delete_id_value.image_id == 1U else {
    fail("expected delete-id removal selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"n"),
      kitty_graphics_pair(b'I', b"5"),
    ])
    is Some(Newest(newest_value)) &&
    !newest_value.delete &&
    newest_value.image_number == 5U else {
    fail("expected newest selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"p"),
      kitty_graphics_pair(b'x', b"3"),
      kitty_graphics_pair(b'y', b"4"),
    ])
    is Some(IntersectCell(cell_value)) &&
    !cell_value.delete &&
    cell_value.x == 3U &&
    cell_value.y == 4U else {
    fail("expected intersect-cell selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"Q"),
      kitty_graphics_pair(b'x', b"3"),
      kitty_graphics_pair(b'y', b"4"),
      kitty_graphics_pair(b'z', b"-1"),
    ])
    is Some(IntersectCellZ(cellz_value)) &&
    cellz_value.delete &&
    cellz_value.x == 3U &&
    cellz_value.y == 4U &&
    cellz_value.z == -1 else {
    fail("expected intersect-cell-z selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"P"),
      kitty_graphics_pair(b'x', b"3"),
      kitty_graphics_pair(b'y', b"4"),
    ])
    is Some(delete_cell_value) &&
    delete_cell_value == IntersectCell({ delete: true, x: 3U, y: 4U }) else {
    fail("expected deleting intersect-cell selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"q"),
      kitty_graphics_pair(b'x', b"3"),
      kitty_graphics_pair(b'y', b"4"),
      kitty_graphics_pair(b'z', b"-1"),
    ])
    is Some(query_cell_z_value) &&
    query_cell_z_value == IntersectCellZ({ delete: false, x: 3U, y: 4U, z: -1 }) else {
    fail("expected non-deleting intersect-cell-z selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"R"),
      kitty_graphics_pair(b'x', b"1"),
      kitty_graphics_pair(b'y', b"3"),
    ])
    is Some(Range(range_value)) &&
    range_value.delete &&
    range_value.first == 1U &&
    range_value.last == 3U else {
    fail("expected range selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"X"),
      kitty_graphics_pair(b'x', b"8"),
    ])
    is Some(Column(column_value)) &&
    column_value.delete &&
    column_value.x == 8U else {
    fail("expected column selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"Y"),
      kitty_graphics_pair(b'y', b"9"),
    ])
    is Some(Row(row_value)) &&
    row_value.delete &&
    row_value.y == 9U else {
    fail("expected row selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"Z"),
      kitty_graphics_pair(b'z', b"-2"),
    ])
    is Some(Z(z_value)) &&
    z_value.delete &&
    z_value.z == -2 else {
    fail("expected z selector")
  }
  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"x"),
      kitty_graphics_pair(b'x', b"8"),
    ])
    is Some(column_query_value) &&
    column_query_value == Column({ delete: false, x: 8U }) &&
    parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"y"),
      kitty_graphics_pair(b'y', b"9"),
    ])
    is Some(row_query_value) &&
    row_query_value == Row({ delete: false, y: 9U }) &&
    parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"z"),
      kitty_graphics_pair(b'z', b"-2"),
    ])
    is Some(z_query_value) &&
    z_query_value == Z({ delete: false, z: -2 }) else {
    fail("expected non-deleting column row and z selectors")
  }
}

///|
test "kitty graphics command/helper parsers cover invalid inputs" {
  let pairs : Array[KittyGraphicsPair] = []
  set_kitty_graphics_pair(pairs, b'i', kitty_graphics_bytes_array(b"1"))
  set_kitty_graphics_pair(pairs, b'i', kitty_graphics_bytes_array(b"2"))
  guard kitty_graphics_pair_value(pairs, b'i') ==
    Some(kitty_graphics_bytes_array(b"2")) else {
    fail("expected pair replacement by key")
  }

  guard kitty_graphics_pair_u8([kitty_graphics_pair(b'a', b"t")], b'a') ==
    Some(b't') &&
    kitty_graphics_pair_u8([kitty_graphics_pair(b'i', b"255")], b'i') ==
    Some(255) &&
    kitty_graphics_pair_u8([kitty_graphics_pair(b'i', b"256")], b'i') == None &&
    kitty_graphics_pair_u8([kitty_graphics_pair(b'i', b"12x")], b'i') == None else {
    fail("expected pair-u8 parsing")
  }

  guard parse_kitty_graphics_u32(kitty_graphics_bytes_array(b"4294967295")) ==
    Some(4294967295U) &&
    parse_kitty_graphics_u32(kitty_graphics_bytes_array(b"")) == None &&
    parse_kitty_graphics_u32(kitty_graphics_bytes_array(b"4294967296")) == None &&
    parse_kitty_graphics_u32(kitty_graphics_bytes_array(b"1x")) == None else {
    fail("expected u32 parsing branches")
  }

  guard parse_kitty_graphics_i32(kitty_graphics_bytes_array(b"2147483647")) ==
    Some(2147483647) &&
    parse_kitty_graphics_i32(kitty_graphics_bytes_array(b"-2147483648")) ==
    Some(-2147483648) &&
    parse_kitty_graphics_i32(kitty_graphics_bytes_array(b"")) == None &&
    parse_kitty_graphics_i32(kitty_graphics_bytes_array(b"-")) == None &&
    parse_kitty_graphics_i32(kitty_graphics_bytes_array(b"-2147483649")) == None &&
    parse_kitty_graphics_i32(kitty_graphics_bytes_array(b"1x")) == None else {
    fail("expected i32 parsing branches")
  }

  guard finish_kitty_graphics_pair(
    pairs,
    b'z',
    kitty_graphics_bytes_array(b"-1"),
  ) else {
    fail("expected signed pair to stay valid")
  }
  guard !finish_kitty_graphics_pair(
      pairs,
      b'z',
      kitty_graphics_bytes_array(b""),
    ) &&
    !finish_kitty_graphics_pair(
      pairs,
      b'z',
      kitty_graphics_bytes_array(b"-2147483649"),
    ) else {
    fail("expected invalid pair rejection")
  }

  guard kitty_graphics_option_byte(None, b'x') == b'x' &&
    kitty_graphics_option_u32(None, 3U) == 3U &&
    kitty_graphics_option_int(None, -1) == -1 else {
    fail("expected option helper fallbacks")
  }

  guard build_kitty_graphics_quiet([]) == Some(KittyGraphicsQuiet::No) &&
    build_kitty_graphics_quiet([kitty_graphics_pair(b'q', b"0")]) ==
    Some(KittyGraphicsQuiet::No) &&
    build_kitty_graphics_quiet([kitty_graphics_pair(b'q', b"1")]) ==
    Some(KittyGraphicsQuiet::Ok) &&
    build_kitty_graphics_quiet([kitty_graphics_pair(b'q', b"2")]) ==
    Some(KittyGraphicsQuiet::Failures) &&
    build_kitty_graphics_quiet([kitty_graphics_pair(b'q', b"9")]) == None else {
    fail("expected quiet parser branches")
  }

  guard parse_kitty_graphics_transmission([kitty_graphics_pair(b'f', b"1")]) ==
    None &&
    parse_kitty_graphics_transmission([
      kitty_graphics_pair(b'f', b"32"),
      kitty_graphics_pair(b't', b"f"),
    ])
    is Some(file_transmission) &&
    file_transmission.format == Rgba &&
    file_transmission.medium == File &&
    parse_kitty_graphics_transmission([kitty_graphics_pair(b't', b"t")])
    is Some(temp_file_transmission) &&
    temp_file_transmission.medium == TemporaryFile &&
    parse_kitty_graphics_transmission([kitty_graphics_pair(b't', b"x")]) == None &&
    parse_kitty_graphics_transmission([kitty_graphics_pair(b'o', b"x")]) == None else {
    fail("expected transmission parse rejection")
  }

  guard parse_kitty_graphics_display([kitty_graphics_pair(b'C', b"2")]) == None &&
    parse_kitty_graphics_display([
      kitty_graphics_pair(b'I', b"8"),
      kitty_graphics_pair(b'C', b"0"),
      kitty_graphics_pair(b'U', b"0"),
    ])
    is Some(default_display) &&
    default_display.image_number == 8U &&
    default_display.cursor_movement == After &&
    !default_display.virtual_placement &&
    parse_kitty_graphics_display([kitty_graphics_pair(b'U', b"2")]) == None else {
    fail("expected display parse rejection")
  }

  guard parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"r"),
      kitty_graphics_pair(b'x', b"4"),
      kitty_graphics_pair(b'y', b"3"),
    ]) ==
    None &&
    parse_kitty_graphics_delete([
      kitty_graphics_pair(b'd', b"r"),
      kitty_graphics_pair(b'x', b"4"),
    ]) ==
    None &&
    parse_kitty_graphics_delete([kitty_graphics_pair(b'd', b"?")]) == None else {
    fail("expected delete parse rejection")
  }
}

///|
test "kitty graphics command/base64 and top-level parser edge cases" {
  let decoded = kitty_graphics_bytes_array(b"")
  guard decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"")) ==
    Some(b"") &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QQ")) ==
    Some(b"A") &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QUE")) ==
    Some(b"AA") &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QUFB")) ==
    Some(b"AAA") &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QQ==")) ==
    Some(b"A") &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"Q=")) == None &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QQ=")) == None &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QQ=Q")) == None &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"QQ==$")) == None &&
    decode_kitty_graphics_base64(kitty_graphics_bytes_array(b"Q")) == None else {
    fail("expected base64 decode branches")
  }
  ignore(decoded)

  let quartet_decoded : Array[Byte] = []
  guard decode_kitty_graphics_base64_quartet(quartet_decoded, [16, 16, -1, -1]) ==
    Some(1) &&
    quartet_decoded == [65] else {
    fail("expected quartet decode with double padding")
  }
  guard decode_kitty_graphics_base64_quartet([], [-1, 0, 0, 0]) == None &&
    decode_kitty_graphics_base64_quartet([], [16, 16, -1, 0]) == None &&
    decode_kitty_graphics_base64_quartet([], [16, 16, -2, 0]) == None &&
    decode_kitty_graphics_base64_quartet([], [16, 16, 16, -1]) == Some(2) &&
    decode_kitty_graphics_base64_quartet([], [16, 16, 16, -2]) == None else {
    fail("expected quartet decode rejection")
  }
  guard kitty_graphics_base64_value(b'+') == Some(62) &&
    kitty_graphics_base64_value(b'/') == Some(63) &&
    kitty_graphics_base64_value(b'a') == Some(26) &&
    kitty_graphics_base64_value(b'0') == Some(52) &&
    kitty_graphics_base64_value(b'?') == None else {
    fail("expected base64 alphabet mapping")
  }

  guard parse_kitty_graphics_command_bytes([]) == None &&
    parse_kitty_graphics_command_bytes(kitty_graphics_bytes_array(b"a=,i=1")) ==
    None &&
    parse_kitty_graphics_command_bytes(kitty_graphics_bytes_array(b"a=;")) ==
    None &&
    parse_kitty_graphics_command_bytes(kitty_graphics_bytes_array(b"a=")) ==
    None &&
    parse_kitty_graphics_command_bytes(kitty_graphics_bytes_array(b"a=t,q=9")) ==
    None &&
    parse_kitty_graphics_command_bytes(
      kitty_graphics_bytes_array(b"a=123456789012;"),
    )
    is Some(long_value_command) &&
    long_value_command.control is Transmit(_) &&
    parse_kitty_graphics_command_bytes(kitty_graphics_bytes_array(b"a=t;*")) ==
    None &&
    parse_kitty_graphics_command_bytes(
      kitty_graphics_bytes_array(b"abcdefghijkl=t,f=24,s=1,v=1;QUFB"),
    )
    is Some(ignored_key_command) &&
    ignored_key_command.control is Transmit(transmission) &&
    transmission.format == Rgb &&
    transmission.width == 1U &&
    transmission.height == 1U else {
    fail("expected top-level parser branches")
  }

  guard parse_kitty_graphics_command_bytes(
      kitty_graphics_bytes_array(b"a=t,i=1,i=2,s=1,v=1;QUFB"),
    )
    is Some(duplicate_key_command) &&
    duplicate_key_command.control is Transmit(duplicate_transmission) &&
    duplicate_transmission.image_id == 2U else {
    fail("expected repeated key override")
  }

  guard parse_kitty_graphics_command_bytes(kitty_graphics_bytes_array(b"a=f"))
    is Some(unsupported_action_command) &&
    unsupported_action_command.control == Unsupported(b'f') &&
    build_kitty_graphics_control([
      kitty_graphics_pair(b'a', b"q"),
      kitty_graphics_pair(b'f', b"1"),
    ]) ==
    None &&
    build_kitty_graphics_control([
      kitty_graphics_pair(b'a', b"t"),
      kitty_graphics_pair(b't', b"x"),
    ]) ==
    None &&
    build_kitty_graphics_control([
      kitty_graphics_pair(b'a', b"T"),
      kitty_graphics_pair(b'f', b"24"),
      kitty_graphics_pair(b'C', b"2"),
    ]) ==
    None &&
    build_kitty_graphics_control([
      kitty_graphics_pair(b'a', b"T"),
      kitty_graphics_pair(b'f', b"1"),
    ]) ==
    None &&
    build_kitty_graphics_control([
      kitty_graphics_pair(b'a', b"p"),
      kitty_graphics_pair(b'C', b"2"),
    ]) ==
    None &&
    build_kitty_graphics_control([kitty_graphics_pair(b'a', b"?")]) == None else {
    fail("expected unsupported action preservation")
  }
}
