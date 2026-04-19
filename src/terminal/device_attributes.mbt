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
struct PrimaryDeviceAttributes {
  conformance_level : ConformanceLevel
  features : ReadOnlyArray[PrimaryDeviceAttributeFeature]
} derive(Eq, Debug)

///|
pub fn PrimaryDeviceAttributes::new(
  conformance_level : ConformanceLevel,
  features : ReadOnlyArray[PrimaryDeviceAttributeFeature],
) -> PrimaryDeviceAttributes {
  { conformance_level, features }
}

///|
pub fn PrimaryDeviceAttributes::conformance_level(
  self : PrimaryDeviceAttributes,
) -> ConformanceLevel {
  self.conformance_level
}

///|
pub fn PrimaryDeviceAttributes::features(
  self : PrimaryDeviceAttributes,
) -> ReadOnlyArray[PrimaryDeviceAttributeFeature] {
  self.features
}

///|
pub fn PrimaryDeviceAttributes::default() -> PrimaryDeviceAttributes {
  {
    conformance_level: ConformanceLevel::Vt220,
    features: [PrimaryDeviceAttributeFeature::AnsiColor],
  }
}

///|
pub fn PrimaryDeviceAttributes::encode(self : PrimaryDeviceAttributes) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[?")
  write_uint_ascii(buffer, self.conformance_level.code().to_uint64())
  for feature in self.features {
    buffer.write_byte(b';')
    write_uint_ascii(buffer, feature.code().to_uint64())
  }
  buffer.write_byte(b'c')
  buffer.contents()
}

///|
struct SecondaryDeviceAttributes {
  device_type : DeviceType
  firmware_version : UInt16
  rom_cartridge : UInt16
} derive(Eq, Debug)

///|
pub fn SecondaryDeviceAttributes::new(
  device_type : DeviceType,
  firmware_version : UInt16,
  rom_cartridge : UInt16,
) -> SecondaryDeviceAttributes {
  { device_type, firmware_version, rom_cartridge }
}

///|
pub fn SecondaryDeviceAttributes::device_type(
  self : SecondaryDeviceAttributes,
) -> DeviceType {
  self.device_type
}

///|
pub fn SecondaryDeviceAttributes::firmware_version(
  self : SecondaryDeviceAttributes,
) -> UInt16 {
  self.firmware_version
}

///|
pub fn SecondaryDeviceAttributes::rom_cartridge(
  self : SecondaryDeviceAttributes,
) -> UInt16 {
  self.rom_cartridge
}

///|
pub fn SecondaryDeviceAttributes::default() -> SecondaryDeviceAttributes {
  { device_type: DeviceType::Vt220, firmware_version: 0, rom_cartridge: 0 }
}

///|
pub fn SecondaryDeviceAttributes::encode(
  self : SecondaryDeviceAttributes,
) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[>")
  write_uint_ascii(buffer, self.device_type.code().to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, self.firmware_version.to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, self.rom_cartridge.to_uint64())
  buffer.write_byte(b'c')
  buffer.contents()
}

///|
struct TertiaryDeviceAttributes {
  unit_id : UInt
} derive(Eq, Debug)

///|
pub fn TertiaryDeviceAttributes::new(
  unit_id : UInt,
) -> TertiaryDeviceAttributes {
  { unit_id, }
}

///|
pub fn TertiaryDeviceAttributes::unit_id(
  self : TertiaryDeviceAttributes,
) -> UInt {
  self.unit_id
}

///|
pub fn TertiaryDeviceAttributes::default() -> TertiaryDeviceAttributes {
  { unit_id: 0 }
}

///|
pub fn TertiaryDeviceAttributes::encode(
  self : TertiaryDeviceAttributes,
) -> Bytes {
  let buffer = @buffer.new(size_hint=15)
  buffer.write_bytes(b"\x1BP!|")
  write_hex8(buffer, self.unit_id)
  buffer.write_bytes(b"\x1B\\")
  buffer.contents()
}

///|
struct DeviceAttributes {
  primary : PrimaryDeviceAttributes
  secondary : SecondaryDeviceAttributes
  tertiary : TertiaryDeviceAttributes
} derive(Eq, Debug)

///|
pub fn DeviceAttributes::new(
  primary : PrimaryDeviceAttributes,
  secondary : SecondaryDeviceAttributes,
  tertiary : TertiaryDeviceAttributes,
) -> DeviceAttributes {
  { primary, secondary, tertiary }
}

///|
pub fn DeviceAttributes::primary(
  self : DeviceAttributes,
) -> PrimaryDeviceAttributes {
  self.primary
}

///|
pub fn DeviceAttributes::secondary(
  self : DeviceAttributes,
) -> SecondaryDeviceAttributes {
  self.secondary
}

///|
pub fn DeviceAttributes::tertiary(
  self : DeviceAttributes,
) -> TertiaryDeviceAttributes {
  self.tertiary
}

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
) -> Bytes {
  match request {
    Primary => self.primary.encode()
    Secondary => self.secondary.encode()
    Tertiary => self.tertiary.encode()
  }
}
