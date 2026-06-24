///|
/// The host-callback boundary: the set of side effects the terminal engine
/// fires back into its embedder (write to the pty, ring the bell, query the
/// host color scheme, …). Each effect is an independently swappable closure so
/// a host can install or clear handlers one at a time at runtime.
///
/// The struct is opaque; the fields are reached only through the invoker
/// methods below (`write_pty`, `color_scheme`, …) and replaced through the
/// `set_*` / `clear_*` pairs.
struct StreamTerminalBridgeEffects {
  mut write_pty_fn : (Bytes) -> Unit
  mut bell_fn : () -> Unit
  mut color_scheme_fn : () -> @device.ColorScheme?
  mut device_attributes_fn : () -> @device.DeviceAttributes?
  mut enquiry_fn : () -> Bytes
  mut size_fn : () -> @size_report.Size?
  mut title_changed_fn : () -> Unit
  mut xtversion_fn : () -> String
}

///|
pub fn StreamTerminalBridgeEffects::new(
  write_pty? : (Bytes) -> Unit = fn(_data) { () },
  bell? : () -> Unit = fn() { () },
  color_scheme? : () -> @device.ColorScheme? = fn() { None },
  device_attributes? : () -> @device.DeviceAttributes? = fn() { None },
  enquiry? : () -> Bytes = fn() { b"" },
  size? : () -> @size_report.Size? = fn() { None },
  title_changed? : () -> Unit = fn() { () },
  xtversion? : () -> String = fn() { "" },
) -> StreamTerminalBridgeEffects {
  {
    write_pty_fn: write_pty,
    bell_fn: bell,
    color_scheme_fn: color_scheme,
    device_attributes_fn: device_attributes,
    enquiry_fn: enquiry,
    size_fn: size,
    title_changed_fn: title_changed,
    xtversion_fn: xtversion,
  }
}

// -- invokers ---------------------------------------------------------------

///|
pub fn StreamTerminalBridgeEffects::write_pty(
  self : StreamTerminalBridgeEffects,
  data : Bytes,
) -> Unit {
  (self.write_pty_fn)(data)
}

///|
pub fn StreamTerminalBridgeEffects::bell(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  (self.bell_fn)()
}

///|
pub fn StreamTerminalBridgeEffects::color_scheme(
  self : StreamTerminalBridgeEffects,
) -> @device.ColorScheme? {
  (self.color_scheme_fn)()
}

///|
pub fn StreamTerminalBridgeEffects::device_attributes(
  self : StreamTerminalBridgeEffects,
) -> @device.DeviceAttributes? {
  (self.device_attributes_fn)()
}

///|
pub fn StreamTerminalBridgeEffects::enquiry(
  self : StreamTerminalBridgeEffects,
) -> Bytes {
  (self.enquiry_fn)()
}

///|
pub fn StreamTerminalBridgeEffects::size(
  self : StreamTerminalBridgeEffects,
) -> @size_report.Size? {
  (self.size_fn)()
}

///|
pub fn StreamTerminalBridgeEffects::title_changed(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  (self.title_changed_fn)()
}

///|
pub fn StreamTerminalBridgeEffects::xtversion(
  self : StreamTerminalBridgeEffects,
) -> String {
  (self.xtversion_fn)()
}

// -- per-effect install / clear --------------------------------------------

///|
pub fn StreamTerminalBridgeEffects::set_write_pty(
  self : StreamTerminalBridgeEffects,
  callback : (Bytes) -> Unit,
) -> Unit {
  self.write_pty_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_write_pty(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.write_pty_fn = fn(_data) { () }
}

///|
pub fn StreamTerminalBridgeEffects::set_bell(
  self : StreamTerminalBridgeEffects,
  callback : () -> Unit,
) -> Unit {
  self.bell_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_bell(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.bell_fn = fn() { () }
}

///|
pub fn StreamTerminalBridgeEffects::set_color_scheme(
  self : StreamTerminalBridgeEffects,
  callback : () -> @device.ColorScheme?,
) -> Unit {
  self.color_scheme_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_color_scheme(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.color_scheme_fn = fn() { None }
}

///|
pub fn StreamTerminalBridgeEffects::set_device_attributes(
  self : StreamTerminalBridgeEffects,
  callback : () -> @device.DeviceAttributes?,
) -> Unit {
  self.device_attributes_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_device_attributes(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.device_attributes_fn = fn() { None }
}

///|
pub fn StreamTerminalBridgeEffects::set_enquiry(
  self : StreamTerminalBridgeEffects,
  callback : () -> Bytes,
) -> Unit {
  self.enquiry_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_enquiry(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.enquiry_fn = fn() { b"" }
}

///|
pub fn StreamTerminalBridgeEffects::set_size(
  self : StreamTerminalBridgeEffects,
  callback : () -> @size_report.Size?,
) -> Unit {
  self.size_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_size(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.size_fn = fn() { None }
}

///|
pub fn StreamTerminalBridgeEffects::set_title_changed(
  self : StreamTerminalBridgeEffects,
  callback : () -> Unit,
) -> Unit {
  self.title_changed_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_title_changed(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.title_changed_fn = fn() { () }
}

///|
pub fn StreamTerminalBridgeEffects::set_xtversion(
  self : StreamTerminalBridgeEffects,
  callback : () -> String,
) -> Unit {
  self.xtversion_fn = callback
}

///|
pub fn StreamTerminalBridgeEffects::clear_xtversion(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.xtversion_fn = fn() { "" }
}
