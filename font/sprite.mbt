///|
const SpriteStart : UInt = 0x110000U

///|
const SpriteEnd : UInt = 0xFFFFFFFFU

///|
struct Sprite(UInt) derive(Eq, Debug)

///|
pub fn Sprite::start() -> UInt {
  SpriteStart
}

///|
pub fn Sprite::end() -> UInt {
  SpriteEnd
}

///|
pub fn Sprite::underline() -> Sprite {
  Sprite(SpriteStart)
}

///|
pub fn Sprite::underline_double() -> Sprite {
  Sprite(SpriteStart + 1U)
}

///|
pub fn Sprite::underline_dotted() -> Sprite {
  Sprite(SpriteStart + 2U)
}

///|
pub fn Sprite::underline_dashed() -> Sprite {
  Sprite(SpriteStart + 3U)
}

///|
pub fn Sprite::underline_curly() -> Sprite {
  Sprite(SpriteStart + 4U)
}

///|
pub fn Sprite::strikethrough() -> Sprite {
  Sprite(SpriteStart + 5U)
}

///|
pub fn Sprite::overline() -> Sprite {
  Sprite(SpriteStart + 6U)
}

///|
pub fn Sprite::cursor_rect() -> Sprite {
  Sprite(SpriteStart + 7U)
}

///|
pub fn Sprite::cursor_hollow_rect() -> Sprite {
  Sprite(SpriteStart + 8U)
}

///|
pub fn Sprite::cursor_bar() -> Sprite {
  Sprite(SpriteStart + 9U)
}

///|
pub fn Sprite::cursor_underline() -> Sprite {
  Sprite(SpriteStart + 10U)
}

///|
pub fn Sprite::codepoint(self : Sprite) -> UInt {
  self.0
}

///|
pub fn Sprite::from_codepoint(codepoint : UInt) -> Sprite? {
  if codepoint >= SpriteStart && codepoint <= Sprite::cursor_underline().0 {
    Some(Sprite(codepoint))
  } else {
    None
  }
}
