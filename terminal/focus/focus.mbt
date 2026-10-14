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

///|
pub extend FocusEvent with Eq::{not_equal, equal}

///|
pub extend FocusEvent with @debug.Debug::{to_repr}
