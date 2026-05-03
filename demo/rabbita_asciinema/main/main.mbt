///|
const CastFileInputId : String = "cast-file-input"

///|
priv struct Player {
  cast : Cast
  cursor : Int
  elapsed_ms : Int
  playing : Bool
  speed : Int
  generation : Int
  file_name : String?
  last_error : String?
  last_marker : String?
  exit_status : String?
}

///|
priv struct Model {
  terminal : GhosttyTerminal
  player : Player
  theme : Theme
}

///|
priv enum Theme {
  Dark
  Light
}

///|
priv enum Msg {
  Start
  CastFileSelected
  CastFileLoaded(Result[LoadedFile, Error])
  PlayPause
  Scrub(String)
  Step(Int)
  CycleSpeed
  ToggleTheme
}

///|
fn initial_cast() -> Cast {
  match parse_cast(sample_cast()) {
    ParseOk(cast) => cast
    ParseErr(_) =>
      {
        version: 3,
        title: Some("empty"),
        cols: 80,
        rows: 24,
        duration_ms: 0,
        events: [],
      }
  }
}

///|
fn initial_player(cast : Cast) -> Player {
  {
    cast,
    cursor: 0,
    elapsed_ms: 0,
    playing: false,
    speed: 1,
    generation: 0,
    file_name: Some("sample.cast"),
    last_error: None,
    last_marker: None,
    exit_status: None,
  }
}

///|
fn initial_model() -> Model {
  let theme = Dark
  let cast = initial_cast()
  {
    terminal: GhosttyTerminal::new(
      cols=cast.cols,
      rows=cast.rows,
      background=theme_background(theme),
      foreground=theme_foreground(theme),
    ),
    player: initial_player(cast),
    theme,
  }
}

///|
fn theme_background(theme : Theme) -> String {
  match theme {
    Dark => "#101418"
    Light => "#f8fbf8"
  }
}

///|
fn theme_foreground(theme : Theme) -> String {
  match theme {
    Dark => "#dce4ea"
    Light => "#1d2926"
  }
}

///|
fn theme_class(theme : Theme) -> String {
  match theme {
    Dark => "theme-dark"
    Light => "theme-light"
  }
}

///|
fn next_theme(theme : Theme) -> Theme {
  match theme {
    Dark => Light
    Light => Dark
  }
}

///|
fn scaled_delay_ms(delay_ms : Int, speed : Int) -> Int {
  let safe_speed = if speed <= 0 { 1 } else { speed }
  let scaled = delay_ms / safe_speed
  if delay_ms > 0 && scaled < 12 {
    12
  } else {
    scaled
  }
}

///|
fn schedule_next(dispatch : @cmd.Dispatch[Msg], player : Player) -> @cmd.Cmd {
  match player.cast.events.get(player.cursor) {
    Some(event) =>
      @cmd.delay(
        dispatch(Step(player.generation)),
        scaled_delay_ms(event.delay_ms, player.speed),
      )
    None => @cmd.none
  }
}

///|
fn parse_resize(data : String) -> (Int, Int)? {
  match data.split("x").collect() {
    [cols_text, rows_text] => {
      let cols = @string.parse_int(cols_text) catch { _ => return None }
      let rows = @string.parse_int(rows_text) catch { _ => return None }
      Some((cols, rows))
    }
    _ => None
  }
}

///|
fn apply_event(terminal : GhosttyTerminal, event : CastEvent) -> Unit {
  match event.kind {
    Output => terminal.write_text(event.data)
    Resize =>
      match parse_resize(event.data) {
        Some((cols, rows)) => terminal.resize(cols~, rows~)
        None => ()
      }
    Input | Marker | Exit => ()
    Unknown(code) => ignore(code)
  }
}

///|
fn load_selected_file(dispatch : @cmd.Dispatch[Msg]) -> @cmd.Cmd {
  @cmd.attempt(result => dispatch(CastFileLoaded(result)), async fn() {
    js_read_selected_file(CastFileInputId).wait() |> loaded_file_from_js
  })
}

///|
fn reset_terminal(model : Model, cast : Cast) -> Unit {
  model.terminal.reset(cols=cast.cols, rows=cast.rows)
}

///|
fn start_player(
  dispatch : @cmd.Dispatch[Msg],
  model : Model,
  restart~ : Bool,
) -> (@cmd.Cmd, Model) {
  let base = if restart ||
    model.player.cursor >= model.player.cast.events.length() {
    {
      ..model.player,
      cursor: 0,
      elapsed_ms: 0,
      last_marker: None,
      exit_status: None,
    }
  } else {
    model.player
  }
  if restart {
    reset_terminal(model, base.cast)
  }
  let player = {
    ..base,
    playing: true,
    generation: base.generation + 1,
    last_error: None,
  }
  (schedule_next(dispatch, player), { ..model, player, })
}

///|
fn pause_player(model : Model) -> Model {
  let player = {
    ..model.player,
    playing: false,
    generation: model.player.generation + 1,
  }
  { ..model, player, }
}

///|
fn load_cast(
  dispatch : @cmd.Dispatch[Msg],
  model : Model,
  file : LoadedFile,
) -> (@cmd.Cmd, Model) {
  match parse_cast(file.source) {
    ParseOk(cast) => {
      model.terminal.reset(cols=cast.cols, rows=cast.rows)
      let player = {
        ..model.player,
        cast,
        cursor: 0,
        elapsed_ms: 0,
        playing: true,
        generation: model.player.generation + 1,
        file_name: Some(file.file_name),
        last_error: None,
        last_marker: None,
        exit_status: None,
      }
      (schedule_next(dispatch, player), { ..model, player, })
    }
    ParseErr(message) => {
      let player = {
        ..model.player,
        playing: false,
        generation: model.player.generation + 1,
        last_error: Some(message),
      }
      (@cmd.none, { ..model, player, })
    }
  }
}

///|
fn jump_to(
  _dispatch : @cmd.Dispatch[Msg],
  model : Model,
  index : Int,
) -> (@cmd.Cmd, Model) {
  let target = index.clamp(min=0, max=model.player.cast.events.length())
  model.terminal.reset(cols=model.player.cast.cols, rows=model.player.cast.rows)
  let mut elapsed_ms = 0
  let mut last_marker : String? = None
  let mut exit_status : String? = None
  for i in 0..<target {
    match model.player.cast.events.get(i) {
      Some(event) => {
        elapsed_ms += event.delay_ms
        if event.kind is Marker {
          last_marker = Some(event.data)
        } else if event.kind is Exit {
          exit_status = Some(event.data)
        }
        apply_event(model.terminal, event)
      }
      None => ()
    }
  }
  let player = {
    ..model.player,
    cursor: target,
    elapsed_ms,
    playing: false,
    generation: model.player.generation + 1,
    last_marker,
    exit_status,
  }
  (@cmd.none, { ..model, player, })
}

///|
fn handle_step(
  dispatch : @cmd.Dispatch[Msg],
  generation : Int,
  model : Model,
) -> (@cmd.Cmd, Model) {
  if generation != model.player.generation || !model.player.playing {
    return (@cmd.none, model)
  }
  match model.player.cast.events.get(model.player.cursor) {
    None => {
      let player = { ..model.player, playing: false }
      (@cmd.none, { ..model, player, })
    }
    Some(event) => {
      apply_event(model.terminal, event)
      let cursor = model.player.cursor + 1
      let mut last_marker = model.player.last_marker
      let mut exit_status = model.player.exit_status
      if event.kind is Marker {
        last_marker = Some(event.data)
      } else if event.kind is Exit {
        exit_status = Some(event.data)
      }
      let has_next = cursor < model.player.cast.events.length()
      let player = {
        ..model.player,
        cursor,
        elapsed_ms: model.player.elapsed_ms + event.delay_ms,
        playing: has_next,
        last_marker,
        exit_status,
      }
      (schedule_next(dispatch, player), { ..model, player, })
    }
  }
}

///|
fn update(
  dispatch : @cmd.Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@cmd.Cmd, Model) {
  match msg {
    Start => start_player(dispatch, model, restart=true)
    CastFileSelected => (load_selected_file(dispatch), model)
    CastFileLoaded(Ok(file)) => load_cast(dispatch, model, file)
    CastFileLoaded(Err(err)) => {
      let player = {
        ..model.player,
        playing: false,
        generation: model.player.generation + 1,
        last_error: Some("file load failed: \{err.to_string()}"),
      }
      (@cmd.none, { ..model, player, })
    }
    PlayPause =>
      if model.player.playing {
        (@cmd.none, pause_player(model))
      } else {
        start_player(
          dispatch,
          model,
          restart=model.player.cursor >= model.player.cast.events.length(),
        )
      }
    Scrub(value) => {
      let index = @string.parse_int(value) catch { _ => model.player.cursor }
      jump_to(dispatch, model, index)
    }
    Step(generation) => handle_step(dispatch, generation, model)
    CycleSpeed => {
      let speed = match model.player.speed {
        1 => 2
        2 => 4
        _ => 1
      }
      let player = { ..model.player, speed, }
      (@cmd.none, { ..model, player, })
    }
    ToggleTheme => {
      let theme = next_theme(model.theme)
      model.terminal.set_theme(
        background=theme_background(theme),
        foreground=theme_foreground(theme),
      )
      (@cmd.none, { ..model, theme, })
    }
  }
}

///|
fn subscriptions(_dispatch : @cmd.Dispatch[Msg], _model : Model) -> @sub.Sub {
  @sub.none
}

///|
fn play_pause_label(player : Player) -> String {
  if player.playing {
    "Pause"
  } else {
    "Play"
  }
}

///|
fn play_pause_button(
  dispatch : @cmd.Dispatch[Msg],
  player : Player,
) -> @html.Html {
  @html.button(
    class="player-button primary",
    title=play_pause_label(player),
    on_click=dispatch(PlayPause),
    play_pause_label(player),
  )
}

///|
fn upload_button(dispatch : @cmd.Dispatch[Msg]) -> @html.Html {
  @html.label(
    class="player-button upload-button",
    title="Open cast file",
    for_=CastFileInputId,
    [
      @html.span(class="button-label", "Open file"),
      @html.input(
        input_type=File,
        id=CastFileInputId,
        class="file-input",
        on_change=dispatch.map(_ => CastFileSelected),
        "",
      ),
    ],
  )
}

///|
fn theme_button(dispatch : @cmd.Dispatch[Msg], theme : Theme) -> @html.Html {
  let label = match theme {
    Dark => "Dark"
    Light => "Light"
  }
  @html.button(
    class="player-button",
    title="Toggle theme",
    on_click=dispatch(ToggleTheme),
    label,
  )
}

///|
fn speed_button(dispatch : @cmd.Dispatch[Msg], speed : Int) -> @html.Html {
  @html.button(
    class="player-button",
    title="Playback speed",
    on_click=dispatch(CycleSpeed),
    "\{speed}x",
  )
}

///|
fn format_time(ms : Int) -> String {
  let seconds = ms / 1000
  let tenths = ms % 1000 / 100
  "\{seconds}.\{tenths}s"
}

///|
fn progress_text(player : Player) -> String {
  "\{format_time(player.elapsed_ms)} / \{format_time(player.cast.duration_ms)}"
}

///|
fn progress_percent(player : Player) -> Int {
  let total = player.cast.events.length()
  if total <= 0 {
    0
  } else {
    player.cursor * 100 / total
  }
}

///|
fn cast_meta(player : Player, terminal : GhosttyTerminal) -> String {
  let pieces : Array[String] = [
    "asciicast v\{player.cast.version}",
    "\{player.cast.cols}x\{player.cast.rows}",
    "\{terminal.cols()}x\{terminal.rows()} active",
  ]
  match player.last_marker {
    Some(marker) => pieces.push("marker: \{marker}")
    None => ()
  }
  match player.exit_status {
    Some(status) => pieces.push("exit: \{status}")
    None => ()
  }
  if terminal.bell_count() > 0 {
    pieces.push("bells: \{terminal.bell_count()}")
  }
  if terminal.title_change_count() > 0 {
    pieces.push("title changes: \{terminal.title_change_count()}")
  }
  pieces.push("cursor: \{terminal.cursor_x()},\{terminal.cursor_y()}")
  if !terminal.pty_text().is_empty() {
    pieces.push("pty replies: \{terminal.pty_text().length()}")
  }
  pieces.join(" · ")
}

///|
fn display_title(model : Model) -> String {
  model.terminal
  .title()
  .unwrap_or(
    model.player.cast.title.unwrap_or(
      model.player.file_name.unwrap_or("Ghostty asciinema replay"),
    ),
  )
}

///|
fn error_view(player : Player) -> @html.Html {
  match player.last_error {
    Some(message) => @html.div(class="error-line", message)
    None => @html.nothing
  }
}

///|
fn view(dispatch : @cmd.Dispatch[Msg], model : Model) -> @html.Html {
  let duration = model.player.cast.events.length()
  @html.main_(class="app-shell \{theme_class(model.theme)}", [
    @html.section(class="player-shell", [
      @html.div(class="player-topline", [
        @html.h1(display_title(model)),
        @html.p(cast_meta(model.player, model.terminal)),
      ]),
      @html.div(class="screen", [
        @html.div(class="terminal-toolbar", [
          @html.div(class="traffic", [
            @html.span(class="dot dot-red", ""),
            @html.span(class="dot dot-yellow", ""),
            @html.span(class="dot dot-green", ""),
          ]),
          @html.div(class="terminal-title", display_title(model)),
        ]),
        model.terminal.view(class="terminal-host"),
        @html.div(class="player-controls", [
          @html.input(
            input_type=Range,
            class="scrubber",
            style=["--progress: \{progress_percent(model.player)}%"],
            min=0,
            max=duration,
            value="\{model.player.cursor}",
            on_input=dispatch.map(value => Scrub(value)),
            "",
          ),
          @html.div(class="control-row", [
            play_pause_button(dispatch, model.player),
            @html.span(class="timecode", progress_text(model.player)),
            @html.div(class="control-spacer", ""),
            upload_button(dispatch),
            theme_button(dispatch, model.theme),
            speed_button(dispatch, model.player.speed),
          ]),
        ]),
      ]),
      error_view(model.player),
    ]),
  ])
}

///|
#warnings("-alert_unstable")
fn main {
  let (dispatch, cell) = @rabbita.cell_with_dispatch(
    model=initial_model(),
    update~,
    view~,
    subscriptions~,
  )
  let app = @rabbita.new(cell)
  app.with_init(dispatch(Start))
  app.mount("app")
}
