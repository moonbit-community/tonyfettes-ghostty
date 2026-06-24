///|
/// Integration coverage for `StreamTerminal::sync_key_encoder`: the modes set
/// directly plus the kitty/modify-other-keys flags parsed out of an escape
/// stream must all land on the encoder, and option-as-alt must reset.
test "key encoder/sync_key_encoder follows upstream terminal-derived defaults" {
  let terminal = StreamTerminal::new()
  let encoder = @key_encoder.KeyEncoder::new()
  encoder.set_macos_option_as_alt(True)
  terminal.mode_set(CursorKeys, true)
  terminal.mode_set(KeypadKeys, true)
  terminal.mode_set(IgnoreKeypadWithNumlock, true)
  terminal.mode_set(AltEscPrefix, true)
  terminal.mode_set(BackarrowKeyMode, true)
  terminal.next_slice(b"\x1B[>4;2m\x1B[=5;2u")
  terminal.sync_key_encoder(encoder)
  guard encoder.cursor_key_application() &&
    encoder.keypad_key_application() &&
    encoder.ignore_keypad_with_numlock() &&
    encoder.alt_esc_prefix() &&
    encoder.modify_other_keys_state_2() &&
    encoder.kitty_flags() == KittyKeyboardFlags(5) &&
    encoder.macos_option_as_alt() == False &&
    encoder.backarrow_key_mode() else {
    fail("expected sync_key_encoder to reset and copy the upstream option set")
  }
  terminal.deinit()
}
