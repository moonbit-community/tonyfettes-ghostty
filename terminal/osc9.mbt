///|
pub(all) enum ConEmuTabTitleChange {
  ConEmuTabTitleReset
  ConEmuTabTitleValue(String)
} derive(Eq, Debug)

///|
pub(all) enum ConEmuProgressState {
  ConEmuProgressRemove
  ConEmuProgressSet
  ConEmuProgressError
  ConEmuProgressIndeterminate
  ConEmuProgressPause
} derive(Eq, Debug)

///|
struct DesktopNotification {
  title : String
  body : String
} derive(Eq, Debug)

///|
fn DesktopNotification::new(
  title : String,
  body : String,
) -> DesktopNotification {
  { title, body }
}

///|
pub fn DesktopNotification::title(self : DesktopNotification) -> String {
  self.title
}

///|
pub fn DesktopNotification::body(self : DesktopNotification) -> String {
  self.body
}

///|
struct ConEmuSleep {
  duration_ms : UInt16
} derive(Eq, Debug)

///|
fn ConEmuSleep::new(duration_ms : UInt16) -> ConEmuSleep {
  { duration_ms, }
}

///|
pub fn ConEmuSleep::duration_ms(self : ConEmuSleep) -> UInt16 {
  self.duration_ms
}

///|
struct ConEmuProgressReport {
  state : ConEmuProgressState
  progress : Byte?
} derive(Eq, Debug)

///|
fn ConEmuProgressReport::new(
  state : ConEmuProgressState,
  progress : Byte?,
) -> ConEmuProgressReport {
  { state, progress }
}

///|
pub fn ConEmuProgressReport::state(
  self : ConEmuProgressReport,
) -> ConEmuProgressState {
  self.state
}

///|
pub fn ConEmuProgressReport::progress(self : ConEmuProgressReport) -> Byte? {
  self.progress
}

///|
struct ConEmuXtermEmulation {
  keyboard : Bool?
  output : Bool?
} derive(Eq, Debug)

///|
fn ConEmuXtermEmulation::new(
  keyboard : Bool?,
  output : Bool?,
) -> ConEmuXtermEmulation {
  { keyboard, output }
}

///|
pub fn ConEmuXtermEmulation::keyboard(self : ConEmuXtermEmulation) -> Bool? {
  self.keyboard
}

///|
pub fn ConEmuXtermEmulation::output(self : ConEmuXtermEmulation) -> Bool? {
  self.output
}

///|
const ConEmuSleepDefaultMs : UInt16 = 100

///|
const ConEmuSleepMaxMs : UInt16 = 10000

///|
const ConEmuProgressMax : UInt = 100U

///|
fn parse_osc9_command(buffer : Array[Byte]) -> Command {
  if buffer.length() == 0 {
    return desktop_notification_command(buffer)
  }

  match buffer[0] {
    b'1' =>
      if buffer.length() < 2 {
        desktop_notification_command(buffer)
      } else {
        match buffer[1] {
          b';' => ConEmuSleep(conemu_sleep_from_bytes(buffer, 2))
          b'0' => conemu_xterm_emulation_or_notification(buffer)
          b'1' => conemu_comment_or_notification(buffer)
          b'2' => SemanticPrompt(SemanticPrompt::new(FreshLineNewPrompt, []))
          _ => desktop_notification_command(buffer)
        }
      }
    b'2' =>
      conemu_string_or_notification(buffer, 2, value => {
        ConEmuShowMessageBox(value)
      })
    b'3' => conemu_tab_title_or_notification(buffer)
    b'4' => conemu_progress_or_notification(buffer)
    b'5' => ConEmuWaitInput
    b'6' =>
      conemu_string_or_notification(buffer, 2, value => ConEmuGuiMacro(value))
    b'7' =>
      conemu_string_or_notification(buffer, 2, value => ConEmuRunProcess(value))
    b'8' =>
      conemu_string_or_notification(buffer, 2, value => {
        ConEmuOutputEnvironmentVariable(value)
      })
    b'9' => conemu_string_or_notification(buffer, 2, value => ReportPwd(value))
    _ => desktop_notification_command(buffer)
  }
}

///|
fn desktop_notification_command(buffer : Array[Byte]) -> Command {
  ShowDesktopNotification(
    DesktopNotification::new(
      "",
      captured_string(copy_bytes_range(buffer, 0, buffer.length())),
    ),
  )
}

///|
fn conemu_sleep_from_bytes(buffer : Array[Byte], start : Int) -> ConEmuSleep {
  match parse_u32_ascii(buffer, start, buffer.length()) {
    Some(value) =>
      if value >= ConEmuSleepMaxMs.to_uint() {
        ConEmuSleep::new(ConEmuSleepMaxMs)
      } else {
        ConEmuSleep::new(value.to_uint16())
      }
    None => ConEmuSleep::new(ConEmuSleepDefaultMs)
  }
}

///|
fn conemu_xterm_emulation_or_notification(buffer : Array[Byte]) -> Command {
  if buffer.length() == 2 {
    return ConEmuXtermEmulation(
      ConEmuXtermEmulation::new(Some(true), Some(true)),
    )
  }
  if buffer.length() < 4 || buffer[2] != b';' {
    return desktop_notification_command(buffer)
  }

  match buffer[3] {
    b'0' =>
      ConEmuXtermEmulation(ConEmuXtermEmulation::new(Some(false), Some(false)))
    b'1' =>
      ConEmuXtermEmulation(ConEmuXtermEmulation::new(Some(true), Some(true)))
    b'2' => ConEmuXtermEmulation(ConEmuXtermEmulation::new(None, Some(false)))
    b'3' => ConEmuXtermEmulation(ConEmuXtermEmulation::new(None, Some(true)))
    _ => desktop_notification_command(buffer)
  }
}

///|
fn conemu_comment_or_notification(buffer : Array[Byte]) -> Command {
  if buffer.length() < 3 || buffer[2] != b';' {
    return desktop_notification_command(buffer)
  }
  ConEmuComment(captured_string(copy_bytes_range(buffer, 3, buffer.length())))
}

///|
fn conemu_string_or_notification(
  buffer : Array[Byte],
  separator_index : Int,
  builder : (String) -> Command,
) -> Command {
  if buffer.length() < separator_index {
    return desktop_notification_command(buffer)
  }
  if buffer[separator_index - 1] != b';' {
    return desktop_notification_command(buffer)
  }
  builder(
    captured_string(copy_bytes_range(buffer, separator_index, buffer.length())),
  )
}

///|
fn conemu_tab_title_or_notification(buffer : Array[Byte]) -> Command {
  if buffer.length() < 2 || buffer[1] != b';' {
    return desktop_notification_command(buffer)
  }
  if buffer.length() == 2 {
    return ConEmuChangeTabTitle(ConEmuTabTitleReset)
  }
  ConEmuChangeTabTitle(
    ConEmuTabTitleValue(
      captured_string(copy_bytes_range(buffer, 2, buffer.length())),
    ),
  )
}

///|
fn conemu_progress_or_notification(buffer : Array[Byte]) -> Command {
  if buffer.length() < 3 || buffer[1] != b';' {
    return desktop_notification_command(buffer)
  }

  let report = match buffer[2] {
    b'0' => ConEmuProgressReport::new(ConEmuProgressRemove, None)
    b'1' => ConEmuProgressReport::new(ConEmuProgressSet, Some(0))
    b'2' => ConEmuProgressReport::new(ConEmuProgressError, None)
    b'3' => ConEmuProgressReport::new(ConEmuProgressIndeterminate, None)
    b'4' => ConEmuProgressReport::new(ConEmuProgressPause, None)
    _ => return desktop_notification_command(buffer)
  }

  if report.state() == ConEmuProgressRemove ||
    report.state() == ConEmuProgressIndeterminate {
    return ConEmuProgressReport(report)
  }
  if buffer.length() < 5 || buffer[3] != b';' {
    return ConEmuProgressReport(report)
  }

  match parse_u32_ascii(buffer, 4, buffer.length()) {
    Some(value) =>
      if value >= ConEmuProgressMax {
        ConEmuProgressReport(
          ConEmuProgressReport::new(
            report.state(),
            Some(ConEmuProgressMax.to_byte()),
          ),
        )
      } else {
        ConEmuProgressReport(
          ConEmuProgressReport::new(report.state(), Some(value.to_byte())),
        )
      }
    None => ConEmuProgressReport(report)
  }
}
