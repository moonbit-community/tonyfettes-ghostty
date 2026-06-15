///|
test "cimap/get and get_view are ascii case-insensitive" {
  let entries : ReadOnlyArray[(String, Int)] = [
    ("AliceBlue", 1),
    ("forest green", 2),
    ("black", 3),
  ]
  let map = @cimap.CiStrMap::from_entries(entries)

  // Exact, lower, upper, mixed — all hit the same entry.
  guard map.get("AliceBlue") == Some(1) else { fail("exact string") }
  guard map.get("aliceblue") == Some(1) else { fail("lower string") }
  guard map.get("ALICEBLUE") == Some(1) else { fail("upper string") }
  guard map.get_view(b"AlIcEbLuE") == Some(1) else { fail("mixed view") }
  guard map.get_view(b"forest green") == Some(2) else { fail("spaced view") }
  guard map.get_view(b"BLACK") == Some(3) else { fail("upper view") }
}

///|
test "cimap/misses return None" {
  let entries : ReadOnlyArray[(String, Int)] = [("white", 1), ("red", 2)]
  let map = @cimap.CiStrMap::from_entries(entries)
  guard map.get("green") == None else { fail("absent key") }
  guard map.get_view(b"whit") == None else { fail("prefix is not a match") }
  guard map.get_view(b"whitee") == None else {
    fail("superstring is not a match")
  }
  guard map.get_view(b"") == None else { fail("empty view") }
}

///|
test "cimap/empty map" {
  let entries : ReadOnlyArray[(String, Int)] = []
  let map = @cimap.CiStrMap::from_entries(entries)
  guard map.get("anything") == None else { fail("empty map lookup") }
}
