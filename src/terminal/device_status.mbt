///|
pub enum ColorScheme {
  Light
  Dark
} derive(Eq, Debug)

///|
pub enum DeviceStatusRequest {
  OperatingStatus
  CursorPosition
  ColorScheme
} derive(Eq, Debug)

///|
struct DeviceStatusTag {
  raw : UInt16
} derive(Eq, Debug)

///|
const DeviceStatusValueMask : UInt16 = 0x7FFF

///|
const DeviceStatusQuestionMask : UInt16 = 0x8000

///|
pub fn DeviceStatusTag::raw(self : DeviceStatusTag) -> UInt16 {
  self.raw
}

///|
pub fn DeviceStatusTag::value(self : DeviceStatusTag) -> UInt16 {
  self.raw & DeviceStatusValueMask
}

///|
pub fn DeviceStatusTag::question(self : DeviceStatusTag) -> Bool {
  (self.raw & DeviceStatusQuestionMask) != 0
}

///|
pub fn device_status_tag(value : UInt16, question : Bool) -> DeviceStatusTag {
  {
    raw: (value & DeviceStatusValueMask) |
    (if question { DeviceStatusQuestionMask } else { 0 }),
  }
}

///|
pub fn device_status_tag_from_raw(raw : UInt16) -> DeviceStatusTag {
  { raw, }
}

///|
pub fn DeviceStatusRequest::tag(self : DeviceStatusRequest) -> DeviceStatusTag {
  match self {
    OperatingStatus => device_status_tag(5, false)
    CursorPosition => device_status_tag(6, false)
    ColorScheme => device_status_tag(996, true)
  }
}

///|
pub fn device_status_request_from_int(
  value : UInt16,
  question : Bool,
) -> DeviceStatusRequest? {
  match (value, question) {
    (5, false) => Some(DeviceStatusRequest::OperatingStatus)
    (6, false) => Some(DeviceStatusRequest::CursorPosition)
    (996, true) => Some(DeviceStatusRequest::ColorScheme)
    _ => None
  }
}
