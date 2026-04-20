///|
test "stream terminal bridge/default state and unsupported action" {
  let state = StreamTerminalBridgeState::new()
  guard !state.palette_dirty() else {
    fail("expected palette dirty to start false")
  }
  guard state.display_state().status_display() == StatusDisplay::Main else {
    fail("expected default status display")
  }
  guard state.display_state().mouse_shape() == MouseShape::Text else {
    fail("expected default mouse shape")
  }
  guard state.protected_state().mode() == ProtectedMode::Off &&
    !state.protected_state().cursor_protected() else {
    fail("expected default protected state")
  }

  guard !state.apply(StreamBell) else {
    fail("expected unsupported action to return false")
  }
}

///|
test "stream terminal bridge/applies protected and display actions" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamProtectedModeIso) else {
    fail("expected protected mode iso to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Iso &&
    state.protected_state().cursor_protected() else {
    fail("expected protected mode iso semantics")
  }

  guard state.apply(StreamProtectedModeOff) else {
    fail("expected protected mode off to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Iso &&
    !state.protected_state().cursor_protected() else {
    fail("expected off to preserve last non-off mode")
  }

  guard state.apply(StreamProtectedModeDec) else {
    fail("expected protected mode dec to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Dec &&
    state.protected_state().cursor_protected() else {
    fail("expected protected mode dec semantics")
  }

  guard state.apply(StreamActiveStatusDisplay(StatusDisplay::StatusLine)) else {
    fail("expected active status display to be handled")
  }
  guard state.apply(StreamMouseShape(MouseShape::Pointer)) else {
    fail("expected mouse shape to be handled")
  }
  guard state.display_state().status_display() == StatusDisplay::StatusLine &&
    state.display_state().mouse_shape() == MouseShape::Pointer else {
    fail("expected display actions to update state")
  }
}

///|
test "stream terminal bridge/applies color set operations and ignores non-terminal targets" {
  let state = StreamTerminalBridgeState::new()
  let command = ColorCommand::new(
    Osc4,
    [
      Set(ColoredTarget::new(Palette(1), RGB::new(9, 8, 7))),
      Set(ColoredTarget::new(Dynamic(Foreground), RGB::new(1, 2, 3))),
      Set(ColoredTarget::new(Dynamic(Background), RGB::new(4, 5, 6))),
      Set(ColoredTarget::new(Dynamic(Cursor), RGB::new(7, 8, 9))),
      Set(ColoredTarget::new(Dynamic(PointerForeground), RGB::new(9, 9, 9))),
      Set(ColoredTarget::new(Special(Bold), RGB::new(6, 6, 6))),
    ],
    Terminator::St,
  )

  guard state.apply(StreamColorOperation(command)) else {
    fail("expected color operation to be handled")
  }
  guard state.palette_dirty() else {
    fail("expected palette writes to mark palette dirty")
  }
  guard state.colors().palette_color(1) == RGB::new(9, 8, 7) else {
    fail("expected palette color write")
  }
  guard state.colors().foreground() == Some(RGB::new(1, 2, 3)) else {
    fail("expected foreground dynamic color write")
  }
  guard state.colors().background() == Some(RGB::new(4, 5, 6)) else {
    fail("expected background dynamic color write")
  }
  guard state.colors().cursor() == Some(RGB::new(7, 8, 9)) else {
    fail("expected cursor dynamic color write")
  }
}

///|
test "stream terminal bridge/applies color resets and reset palette" {
  let state = StreamTerminalBridgeState::new()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc4,
        [
          Set(ColoredTarget::new(Palette(1), RGB::new(10, 11, 12))),
          Set(ColoredTarget::new(Palette(2), RGB::new(20, 21, 22))),
          Set(ColoredTarget::new(Dynamic(Foreground), RGB::new(1, 2, 3))),
          Set(ColoredTarget::new(Dynamic(Background), RGB::new(4, 5, 6))),
          Set(ColoredTarget::new(Dynamic(Cursor), RGB::new(7, 8, 9))),
        ],
        Terminator::St,
      ),
    ),
  ) else {
    fail("expected setup color operation")
  }

  state.clear_palette_dirty()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc104,
        [
          Reset(Palette(1)),
          Reset(Dynamic(Foreground)),
          Reset(Dynamic(Background)),
          Reset(Dynamic(Cursor)),
          Reset(Dynamic(PointerBackground)),
        ],
        Terminator::Bel,
      ),
    ),
  ) else {
    fail("expected reset color operation")
  }

  guard state.palette_dirty() else {
    fail("expected palette reset to mark palette dirty")
  }
  guard state.colors().palette_color(1) == Name::Red.default_rgb() else {
    fail("expected palette reset to restore default entry")
  }
  guard state.colors().foreground() == None &&
    state.colors().background() == None &&
    state.colors().cursor() == None else {
    fail("expected dynamic color resets to restore unset state")
  }

  state.clear_palette_dirty()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(Osc104, [ResetPalette], Terminator::St),
    ),
  ) else {
    fail("expected reset palette operation")
  }
  guard state.palette_dirty() else {
    fail("expected reset palette to mark palette dirty when changes exist")
  }
  guard state.colors().palette_color(2) == Name::Green.default_rgb() else {
    fail("expected reset palette to restore all palette entries")
  }
}

///|
test "stream terminal bridge/empty and query color operations are handled without mutation" {
  let state = StreamTerminalBridgeState::new()
  guard state.apply(
    StreamColorOperation(ColorCommand::new(Osc4, [], Terminator::St)),
  ) else {
    fail("expected empty color operation to be handled")
  }

  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc4,
        [Query(Palette(1)), Reset(Special(Bold))],
        Terminator::St,
      ),
    ),
  ) else {
    fail("expected query-only color operation to be handled")
  }
  guard !state.palette_dirty() else {
    fail("expected query-only color operation to leave state unchanged")
  }
}
