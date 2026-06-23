///|
test "cell hyperlink constructors preserve explicit and implicit ids" {
  let explicit = CellHyperlink::explicit("https://a.example", "id-1")
  guard explicit.uri() == "https://a.example" &&
    explicit.explicit_id() == Some("id-1") &&
    explicit.implicit_id() == None else {
    fail("expected explicit hyperlink payload")
  }
  let implicit = CellHyperlink::implicit("https://b.example", 4)
  guard implicit.uri() == "https://b.example" &&
    implicit.explicit_id() == None &&
    implicit.implicit_id() == Some(4) else {
    fail("expected implicit hyperlink payload")
  }
}
