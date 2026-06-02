///|
priv suberror FileLoadTestError {
  FileLoadTestError
} derive(Debug)

///|
fn noop_dispatch() -> @cmd.Dispatch[Msg] {
  _msg => @cmd.none
}

///|
fn small_cast() -> Cast {
  {
    version: 3,
    title: Some("small"),
    cols: 6,
    rows: 2,
    duration_ms: 150,
    events: [
      { delay_ms: 10, kind: Output, data: "A" },
      { delay_ms: 20, kind: Marker, data: "m1" },
      { delay_ms: 30, kind: Resize, data: "8x3" },
      { delay_ms: 40, kind: Exit, data: "7" },
      { delay_ms: 50, kind: Resize, data: "bad" },
    ],
  }
}

///|
fn model_for_cast(cast : Cast) -> Model {
  {
    terminal: GhosttyTerminal::new(
      cols=cast.cols,
      rows=cast.rows,
      background=theme_background(Dark),
      foreground=theme_foreground(Dark),
    ),
    player: initial_player(cast),
    theme: Dark,
  }
}

///|
test "player helpers handle themes timing and resize parsing" {
  assert_eq(theme_background(Dark), "#101418")
  assert_eq(theme_foreground(Light), "#1d2926")
  assert_eq(theme_class(Dark), "theme-dark")
  assert_eq(theme_class(Light), "theme-light")
  guard next_theme(Dark) is Light else { fail("expected light theme") }
  guard next_theme(Light) is Dark else { fail("expected dark theme") }
  assert_eq(scaled_delay_ms(0, 2), 0)
  assert_eq(scaled_delay_ms(5, 4), 12)
  assert_eq(scaled_delay_ms(40, 0), 40)
  guard parse_resize("80x24") == Some((80, 24)) else {
    fail("expected resize tuple")
  }
  guard parse_resize("80") == None else { fail("expected invalid resize") }
  guard parse_resize("80xbad") == None else {
    fail("expected invalid resize number")
  }
  let terminal = GhosttyTerminal::new(cols=2, rows=1)
  apply_event(terminal, { delay_ms: 0, kind: Unknown("z"), data: "" })
  terminal.deinit()
  assert_eq(format_time(1234), "1.2s")
}

///|
test "player can load casts jump through timeline and apply metadata events" {
  let dispatch = noop_dispatch()
  let model = initial_model()
  let file = { file_name: "loaded.cast", source: sample_cast() }
  let (_cmd, loaded) = load_cast(dispatch, model, file)
  guard loaded.player.playing else { fail("expected autostart after load") }
  guard loaded.player.file_name == Some("loaded.cast") else {
    fail("expected loaded file name")
  }

  let cast = small_cast()
  let model = model_for_cast(cast)
  let (_cmd, jumped) = jump_to(dispatch, model, 4)
  assert_eq(jumped.player.cursor, 4)
  assert_eq(jumped.player.elapsed_ms, 100)
  guard jumped.player.last_marker == Some("m1") else { fail("expected marker") }
  guard jumped.player.exit_status == Some("7") else {
    fail("expected exit status")
  }
  assert_eq(jumped.terminal.cols(), 8)
  assert_eq(jumped.terminal.rows(), 3)

  let (_cmd, negative) = jump_to(dispatch, model, -10)
  assert_eq(negative.player.cursor, 0)
  let (_cmd, overflow) = jump_to(dispatch, model, 99)
  assert_eq(overflow.player.cursor, cast.events.length())

  let (_cmd, bad) = load_cast(dispatch, model, {
    file_name: "bad.cast",
    source: "not json",
  })
  guard !bad.player.playing else { fail("expected failed load to stop") }
  guard bad.player.last_error is Some(_) else { fail("expected parse error") }

  loaded.terminal.deinit()
  model.terminal.deinit()
}

///|
test "player update handles playback control and status branches" {
  let dispatch = noop_dispatch()
  let model = model_for_cast(small_cast())
  ignore(
    schedule_next(dispatch, {
      ..model.player,
      cursor: model.player.cast.events.length(),
    }),
  )
  let (_cmd, started) = update(dispatch, Start, model)
  guard started.player.playing else { fail("expected started playback") }
  guard started.player.generation == model.player.generation + 1 else {
    fail("expected generation increment")
  }

  let (_cmd, stepped) = update(
    dispatch,
    Step(started.player.generation),
    started,
  )
  assert_eq(stepped.player.cursor, 1)
  guard stepped.terminal.plain_viewport().has_prefix("A") else {
    fail("expected first output event")
  }
  let generation = started.player.generation
  let (_cmd, marked) = update(dispatch, Step(generation), stepped)
  guard marked.player.last_marker == Some("m1") else {
    fail("expected marker step")
  }
  let (_cmd, resized) = update(dispatch, Step(generation), marked)
  assert_eq(resized.terminal.cols(), 8)
  assert_eq(resized.terminal.rows(), 3)
  let (_cmd, exited) = update(dispatch, Step(generation), resized)
  guard exited.player.exit_status == Some("7") else {
    fail("expected exit step")
  }

  let (_cmd, ignored_generation) = update(
    dispatch,
    Step(started.player.generation + 1),
    exited,
  )
  assert_eq(ignored_generation.player.cursor, exited.player.cursor)

  let (_cmd, paused) = update(dispatch, PlayPause, exited)
  guard !paused.player.playing else { fail("expected pause") }
  let (_cmd, resumed) = update(dispatch, PlayPause, paused)
  guard resumed.player.playing else { fail("expected resume") }
  let (_cmd, scrubbed) = update(dispatch, Scrub("3"), resumed)
  assert_eq(scrubbed.player.cursor, 3)
  guard !scrubbed.player.playing else { fail("expected scrub to pause") }
  let (_cmd, unchanged_scrub) = update(dispatch, Scrub("bad"), scrubbed)
  assert_eq(unchanged_scrub.player.cursor, scrubbed.player.cursor)

  let (_cmd, speed2) = update(dispatch, CycleSpeed, scrubbed)
  assert_eq(speed2.player.speed, 2)
  let (_cmd, speed4) = update(dispatch, CycleSpeed, speed2)
  assert_eq(speed4.player.speed, 4)
  let (_cmd, speed1) = update(dispatch, CycleSpeed, speed4)
  assert_eq(speed1.player.speed, 1)

  let (_cmd, light) = update(dispatch, ToggleTheme, speed1)
  guard light.theme is Light else { fail("expected light theme") }
  let (_cmd, selected) = update(dispatch, CastFileSelected, light)
  assert_eq(selected.player.cursor, light.player.cursor)
  let (_cmd, loaded_file) = update(
    dispatch,
    CastFileLoaded(Ok({ file_name: "via-update.cast", source: sample_cast() })),
    selected,
  )
  guard loaded_file.player.file_name == Some("via-update.cast") else {
    fail("expected update file load")
  }
  let (_cmd, file_error) = update(
    dispatch,
    CastFileLoaded(Err(FileLoadTestError)),
    loaded_file,
  )
  guard file_error.player.last_error is Some(_) else {
    fail("expected file load error")
  }

  let done = {
    ..file_error.player,
    cursor: file_error.player.cast.events.length(),
  }
  let (_cmd, restarted) = update(dispatch, PlayPause, {
    ..file_error,
    player: done,
  })
  assert_eq(restarted.player.cursor, 0)

  let (_cmd, no_event) = handle_step(dispatch, restarted.player.generation, {
    ..restarted,
    player: {
      ..restarted.player,
      cursor: restarted.player.cast.events.length(),
    },
  })
  guard !no_event.player.playing else { fail("expected completion") }

  ignore(subscriptions(dispatch, no_event))

  no_event.terminal.deinit()
}

///|
#warnings("-alert_unstable")
test "player view renders controls metadata and errors" {
  let dispatch = noop_dispatch()
  let model = model_for_cast(small_cast())
  model.terminal.write_text("\u{7}\u{1B}]0;Window title\u{7}\u{5}")
  let player = {
    ..model.player,
    last_marker: Some("build"),
    exit_status: Some("0"),
    last_error: Some("boom"),
  }
  let model = { ..model, player, }
  assert_eq(play_pause_label(model.player), "Play")
  assert_eq(progress_text(model.player), "0.0s / 0.1s")
  assert_eq(progress_percent(model.player), 0)
  guard cast_meta(model.player, model.terminal).contains("marker: build") else {
    fail("expected marker metadata")
  }
  let quiet_meta = cast_meta(
    { ..model.player, last_marker: None, exit_status: None },
    model.terminal,
  )
  guard !quiet_meta.contains("marker:") && !quiet_meta.contains("exit:") else {
    fail("expected quiet metadata")
  }
  assert_eq(display_title(model), "Window title")
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(view(dispatch, model)),
  )
  guard html.contains("player-button primary") &&
    html.contains("Open file") &&
    html.contains("theme-dark") &&
    html.contains("error-line") else {
    fail("expected player controls and error")
  }
  let empty = { ..model.player, cast: { ..model.player.cast, events: [] } }
  assert_eq(progress_percent(empty), 0)
  ignore(play_pause_button(dispatch, empty))
  ignore(upload_button(dispatch))
  ignore(theme_button(dispatch, Light))
  ignore(speed_button(dispatch, 4))
  ignore(error_view({ ..empty, last_error: None }))
  model.terminal.deinit()
}

///|
test "loaded file can be decoded from js value" {
  let obj = @js.Object::new()
  obj["fileName"] = "demo.cast"
  obj["source"] = "source"
  let loaded = loaded_file_from_js(obj.to_value())
  assert_eq(loaded.file_name, "demo.cast")
  assert_eq(loaded.source, "source")
}
