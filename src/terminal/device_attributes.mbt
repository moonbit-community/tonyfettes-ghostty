///|
pub enum DeviceAttributeRequest {
  Primary
  Secondary
  Tertiary
} derive(Eq, Debug)

///|
pub enum ConformanceLevel {
  Vt100
  Vt132
  Vt102
  Vt131
  Vt125
  Vt220
  Vt240
  Vt320
  Vt340
  Vt420
  Vt510
  Vt520
  Vt525
} derive(Eq, Debug)

///|
pub fn ConformanceLevel::code(self : ConformanceLevel) -> UInt16 {
  match self {
    Vt100 => 1
    Vt132 => 4
    Vt102 => 6
    Vt131 => 7
    Vt125 => 12
    Vt220 => 62
    Vt240 => 62
    Vt320 => 63
    Vt340 => 63
    Vt420 => 64
    Vt510 => 65
    Vt520 => 65
    Vt525 => 65
  }
}

///|
pub enum PrimaryDeviceAttributeFeature {
  Columns132
  Printer
  Regis
  Sixel
  SelectiveErase
  UserDefinedKeys
  NationalReplacement
  TechnicalCharacters
  Locator
  TerminalState
  Windowing
  HorizontalScrolling
  AnsiColor
  RectangularEditing
  AnsiTextLocator
  Clipboard
} derive(Eq, Debug)

///|
pub fn PrimaryDeviceAttributeFeature::code(
  self : PrimaryDeviceAttributeFeature,
) -> UInt16 {
  match self {
    Columns132 => 1
    Printer => 2
    Regis => 3
    Sixel => 4
    SelectiveErase => 6
    UserDefinedKeys => 8
    NationalReplacement => 9
    TechnicalCharacters => 15
    Locator => 16
    TerminalState => 17
    Windowing => 18
    HorizontalScrolling => 21
    AnsiColor => 22
    RectangularEditing => 28
    AnsiTextLocator => 29
    Clipboard => 52
  }
}

///|
pub enum DeviceType {
  Vt100
  Vt220
  Vt240
  Vt330
  Vt340
  Vt320
  Vt382
  Vt420
  Vt510
  Vt520
  Vt525
} derive(Eq, Debug)

///|
pub fn DeviceType::code(self : DeviceType) -> UInt16 {
  match self {
    Vt100 => 0
    Vt220 => 1
    Vt240 => 2
    Vt330 => 18
    Vt340 => 19
    Vt320 => 24
    Vt382 => 32
    Vt420 => 41
    Vt510 => 61
    Vt520 => 64
    Vt525 => 65
  }
}

///|
pub struct PrimaryDeviceAttributes {
  conformance_level : ConformanceLevel
  features : ReadOnlyArray[PrimaryDeviceAttributeFeature]
} derive(Eq, Debug)

///|
pub fn PrimaryDeviceAttributes::default() -> PrimaryDeviceAttributes {
  {
    conformance_level: ConformanceLevel::Vt220,
    features: [PrimaryDeviceAttributeFeature::AnsiColor],
  }
}

///|
pub fn PrimaryDeviceAttributes::encode(
  self : PrimaryDeviceAttributes,
) -> String {
  let parts : Array[String] = ["\u{001B}[?\{self.conformance_level.code()}"]
  for feature in self.features {
    parts.push(";\{feature.code()}")
  }
  parts.push("c")
  parts.join("")
}

///|
pub struct SecondaryDeviceAttributes {
  device_type : DeviceType
  firmware_version : UInt16
  rom_cartridge : UInt16
} derive(Eq, Debug)

///|
pub fn SecondaryDeviceAttributes::default() -> SecondaryDeviceAttributes {
  { device_type: DeviceType::Vt220, firmware_version: 0, rom_cartridge: 0 }
}

///|
pub fn SecondaryDeviceAttributes::encode(
  self : SecondaryDeviceAttributes,
) -> String {
  "\u{001B}[>\{self.device_type.code()};\{self.firmware_version};\{self.rom_cartridge}c"
}

///|
pub struct TertiaryDeviceAttributes {
  unit_id : UInt
} derive(Eq, Debug)

///|
pub fn TertiaryDeviceAttributes::default() -> TertiaryDeviceAttributes {
  { unit_id: 0 }
}

///|
pub fn TertiaryDeviceAttributes::encode(
  self : TertiaryDeviceAttributes,
) -> String {
  "\u{001B}P!|\{hex8(self.unit_id)}\u{001B}\\"
}

///|
pub struct DeviceAttributes {
  primary : PrimaryDeviceAttributes
  secondary : SecondaryDeviceAttributes
  tertiary : TertiaryDeviceAttributes
} derive(Eq, Debug)

///|
pub fn DeviceAttributes::default() -> DeviceAttributes {
  {
    primary: PrimaryDeviceAttributes::default(),
    secondary: SecondaryDeviceAttributes::default(),
    tertiary: TertiaryDeviceAttributes::default(),
  }
}

///|
pub fn DeviceAttributes::encode(
  self : DeviceAttributes,
  request : DeviceAttributeRequest,
) -> String {
  match request {
    Primary => self.primary.encode()
    Secondary => self.secondary.encode()
    Tertiary => self.tertiary.encode()
  }
}

///|
fn hex8(value : UInt) -> String {
  let builder = StringBuilder::new()
  let mut shift = 28
  while shift >= 0 {
    let nibble = ((value >> shift) & 0xF).reinterpret_as_int()
    builder.write_char(hex_digit_upper(nibble))
    shift -= 4
  }
  builder.to_string()
}

///|
fn hex_digit_upper(value : Int) -> Char {
  if value < 10 {
    (value + '0'.to_int()).unsafe_to_char()
  } else {
    (value - 10 + 'A'.to_int()).unsafe_to_char()
  }
}
