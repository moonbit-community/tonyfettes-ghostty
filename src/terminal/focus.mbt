///|
const FocusGainedBytes : Bytes = b"\x1B[I"

///|
const FocusLostBytes : Bytes = b"\x1B[O"

///|
pub(all) enum FocusEvent {
  Gained
  Lost
} derive(Eq, Debug)

///|
pub fn FocusEvent::encode(self : FocusEvent) -> Bytes {
  match self {
    Gained => FocusGainedBytes
    Lost => FocusLostBytes
  }
}
