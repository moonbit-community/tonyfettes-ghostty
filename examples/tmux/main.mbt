///|
const CellWidthPx : UInt = 10U

///|
const CellHeightPx : UInt = 20U

///|
const EscTimeoutMs : Int = 50

///|
const ReadBufferSize : Int = 4096

///|
const ShellExitTimeoutMs : Int = 300

///|
let sgr_reset : String = @utf8.decode_lossy(b"\x1B[0m")

///|
let sgr_active_border : String = @utf8.decode_lossy(b"\x1B[1;36m")

///|
let sgr_inactive_border : String = @utf8.decode_lossy(b"\x1B[2;37m")

///|
let sgr_exited_border : String = @utf8.decode_lossy(b"\x1B[31m")

///|
let sgr_status : String = @utf8.decode_lossy(b"\x1B[7m")

///|
let sgr_prefix_status : String = @utf8.decode_lossy(b"\x1B[1;33;7m")

///|
priv struct PaneSize {
  mut rows : Int
  mut cols : Int
}

///|
priv struct Pane {
  id : Int
  pty : @pty.Pty
  terminal : @terminal.StreamTerminal
  replies : @buffer.Buffer
  size : PaneSize
  mut closed : Bool
  mut exit_code : Int?
}

///|
priv enum MuxEvent {
  Terminal(@tty.Event)
  TerminalClosed
  PaneOutput(Int, Bytes)
  PaneClosed(Int, Int)
  Message(String)
}

///|
priv struct MuxState {
  panes : Array[Pane]
  mut active : Int
  mut next_id : Int
  mut prefix : Bool
  mut done : Bool
  mut status : String
  mut rows : Int
  mut cols : Int
}

///|
priv struct CursorPosition {
  row : Int
  col : Int
}

///|
fn pane_shell_script() -> String {
  "exec sh"
}

///|
fn new_terminal(
  size : PaneSize,
  replies : @buffer.Buffer,
) -> @terminal.StreamTerminal {
  let terminal = @terminal.StreamTerminal::new(
    write_pty=fn(data) { replies.write_bytes(data) },
    enquiry=fn() { @utf8.encode("moonbit-ghostty-mini-tmux") },
    size=fn() {
      let rows = size.rows.clamp(min=1, max=240)
      let cols = size.cols.clamp(min=1, max=240)
      Some(
        @terminal.Size::new(
          rows.to_uint16(),
          cols.to_uint16(),
          CellWidthPx,
          CellHeightPx,
        ),
      )
    },
    xtversion=fn() { "moonbit-ghostty-mini-tmux" },
  )
  let rows = size.rows.clamp(min=1, max=240)
  let cols = size.cols.clamp(min=1, max=240)
  ignore(
    terminal.resize(
      cols.to_uint16(),
      rows.to_uint16(),
      CellWidthPx,
      CellHeightPx,
    ),
  )
  terminal
}

///|
async fn Pane::new(
  group : @async.TaskGroup[Unit],
  id : Int,
  rows : Int,
  cols : Int,
) -> Pane {
  let rows = rows.clamp(min=1, max=240)
  let cols = cols.clamp(min=1, max=240)
  let replies = Buffer()
  let size = { rows, cols }
  let terminal = new_terminal(size, replies)
  let pty = @pty.Pty::spawn(
    group,
    ["sh", "-lc", pane_shell_script()],
    cols~,
    rows~,
  )
  { id, pty, terminal, replies, size, closed: false, exit_code: None }
}

///|
fn Pane::resize(self : Pane, rows : Int, cols : Int) -> Unit {
  let rows = rows.clamp(min=1, max=240)
  let cols = cols.clamp(min=1, max=240)
  self.size.rows = rows
  self.size.cols = cols
  ignore(
    self.terminal.resize(
      cols.to_uint16(),
      rows.to_uint16(),
      CellWidthPx,
      CellHeightPx,
    ),
  )
  self.pty.resize(cols~, rows~) catch {
    _ => ()
  }
}

///|
async fn Pane::flush_replies(self : Pane) -> Unit {
  let data = self.replies.contents()
  self.replies.reset()
  if data.length() > 0 {
    self.pty.write(data) catch {
      _ => ()
    }
  }
}

///|
fn Pane::shutdown(self : Pane) -> Unit {
  if !self.closed {
    self.pty.cancel()
  }
  self.pty.close()
  self.terminal.deinit()
}

///|
fn MuxState::new(rows : Int, cols : Int) -> MuxState {
  {
    panes: [],
    active: 0,
    next_id: 0,
    prefix: false,
    done: false,
    status: "Ctrl-b c creates a pane",
    rows: @cmp.maximum(rows, 2),
    cols: @cmp.maximum(cols, 20),
  }
}

///|
fn MuxState::active_pane(self : MuxState) -> Pane? {
  if self.panes.length() == 0 ||
    self.active < 0 ||
    self.active >= self.panes.length() {
    None
  } else {
    Some(self.panes[self.active])
  }
}

///|
fn visible_pane_count(state : MuxState) -> Int {
  let count = state.panes.length()
  if count <= 1 {
    count
  } else if @cmp.maximum(state.rows - 1, 1) >= count * 3 {
    count
  } else {
    1
  }
}

///|
fn visible_pane_index(state : MuxState, visible_index : Int) -> Int {
  if visible_pane_count(state) == state.panes.length() {
    visible_index
  } else {
    state.active
  }
}

///|
fn slot_rows(total_body_rows : Int, count : Int, index : Int) -> Int {
  if count <= 0 {
    total_body_rows
  } else {
    let base = total_body_rows / count
    let extra = total_body_rows % count
    let extra_row = if index < extra { 1 } else { 0 }
    base + extra_row
  }
}

///|
fn resize_visible_panes(state : MuxState) -> Unit {
  let count = visible_pane_count(state)
  let total = @cmp.maximum(state.rows - 1, 1)
  for visible in 0..<count {
    let pane_index = visible_pane_index(state, visible)
    if pane_index >= 0 && pane_index < state.panes.length() {
      let rows = slot_rows(total, count, visible)
      state.panes[pane_index].resize(
        @cmp.maximum(rows - 2, 1),
        @cmp.maximum(state.cols - 2, 1),
      )
    }
  }
}

///|
async fn add_pane(
  state : MuxState,
  group : @async.TaskGroup[Unit],
  events : @aqueue.Queue[MuxEvent],
) -> Unit {
  let id = state.next_id
  state.next_id += 1
  let pane = Pane::new(group, id, 10, @cmp.maximum(state.cols, 1))
  state.panes.push(pane)
  state.active = state.panes.length() - 1
  state.prefix = false
  state.status = "created pane \{id}"
  resize_visible_panes(state)
  let index = state.active
  group.spawn_bg(no_wait=true) <| () => {
    read_pane_output(index, pane, events)
  }
}

///|
fn switch_next(state : MuxState) -> Unit {
  if state.panes.length() > 0 {
    state.active = (state.active + 1) % state.panes.length()
    state.status = "active pane \{state.panes[state.active].id}"
  }
}

///|
fn switch_prev(state : MuxState) -> Unit {
  if state.panes.length() > 0 {
    state.active = (state.active + state.panes.length() - 1) %
      state.panes.length()
    state.status = "active pane \{state.panes[state.active].id}"
  }
}

///|
fn plain_snapshot(terminal : @terminal.StreamTerminal) -> String {
  let formatter = @terminal.Formatter::new_terminal(
    terminal,
    @terminal.FormatterOptions::new(
      Plain,
      trim=false,
      extra=@terminal.FormatterTerminalExtra::none(),
    ),
  )
  @utf8.decode_lossy(formatter.format())
}

///|
fn fit_line(text : String, cols : Int) -> String {
  if cols <= 0 {
    ""
  } else {
    let builder = StringBuilder()
    let mut used = 0
    for ch in text {
      if used >= cols {
        break
      }
      if ch != '\r' {
        builder.write_char(ch)
        used += 1
      }
    }
    if used < cols {
      builder.write_string(String::make(cols - used, ' '))
    }
    builder.to_string()
  }
}

///|
fn append_screen_line(
  out : StringBuilder,
  text : String,
  cols : Int,
  row : Int,
  rows : Int,
) -> Unit {
  out.write_string(fit_line(text, cols))
  if row + 1 < rows {
    out.write_string("\r\n")
  }
}

///|
fn append_styled_screen_line(
  out : StringBuilder,
  text : String,
  cols : Int,
  row : Int,
  rows : Int,
  style : String,
) -> Unit {
  if style != "" {
    out.write_string(style)
  }
  out.write_string(fit_line(text, cols))
  if style != "" {
    out.write_string(sgr_reset)
  }
  if row + 1 < rows {
    out.write_string("\r\n")
  }
}

///|
fn pane_title(pane : Pane, active : Bool) -> String {
  let marker = if active { "*" } else { " " }
  let state = match pane.exit_code {
    Some(code) => " exited=\{code}"
    None => " pid=\{pane.pty.pid()}"
  }
  "[\{marker}] pane \{pane.id}\{state}"
}

///|
fn border_line(title : String, cols : Int, active : Bool) -> String {
  if cols <= 0 {
    ""
  } else if cols == 1 {
    "+"
  } else {
    let fill = if active { '=' } else { '-' }
    let inner_cols = cols - 2
    let label = if title == "" { "" } else { " \{title} " }
    let builder = StringBuilder()
    let mut used = 0
    builder.write_char('+')
    for ch in label {
      if used >= inner_cols {
        break
      }
      builder.write_char(ch)
      used += 1
    }
    if used < inner_cols {
      builder.write_string(String::make(inner_cols - used, fill))
    }
    builder.write_char('+')
    builder.to_string()
  }
}

///|
fn pane_border_style(pane : Pane, active : Bool) -> String {
  match pane.exit_code {
    Some(_) => sgr_exited_border
    None => if active { sgr_active_border } else { sgr_inactive_border }
  }
}

///|
fn append_boxed_content_line(
  out : StringBuilder,
  text : String,
  cols : Int,
  row : Int,
  rows : Int,
  style : String,
) -> Unit {
  if cols <= 0 {
    append_screen_line(out, "", cols, row, rows)
  } else if cols == 1 {
    append_styled_screen_line(out, "|", cols, row, rows, style)
  } else {
    if style != "" {
      out.write_string(style)
    }
    out.write_char('|')
    if style != "" {
      out.write_string(sgr_reset)
    }
    out.write_string(fit_line(text, cols - 2))
    if style != "" {
      out.write_string(style)
    }
    out.write_char('|')
    if style != "" {
      out.write_string(sgr_reset)
    }
    if row + 1 < rows {
      out.write_string("\r\n")
    }
  }
}

///|
fn status_line(state : MuxState) -> String {
  let mode = if state.prefix { "prefix" } else { "ready" }
  "mini tmux | panes=\{state.panes.length()} active=\{state.active} | \{mode} | Ctrl-b c new n/o next p prev q quit | \{state.status}"
}

///|
fn status_style(state : MuxState) -> String {
  if state.prefix {
    sgr_prefix_status
  } else {
    sgr_status
  }
}

///|
fn append_pane(
  out : StringBuilder,
  state : MuxState,
  pane_index : Int,
  slot : Int,
  visible_count : Int,
  row0 : Int,
) -> Int {
  let mut row = row0
  let pane = state.panes[pane_index]
  let total = @cmp.maximum(state.rows - 1, 1)
  let rows = slot_rows(total, visible_count, slot)
  let content_rows = @cmp.maximum(rows - 2, 0)
  let style = pane_border_style(pane, pane_index == state.active)
  append_styled_screen_line(
    out,
    border_line(
      pane_title(pane, pane_index == state.active),
      state.cols,
      pane_index == state.active,
    ),
    state.cols,
    row,
    state.rows,
    style,
  )
  row += 1
  let lines = plain_snapshot(pane.terminal)
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  for line in 0..<content_rows {
    let text = match lines.get(line) {
      Some(text) => text
      None => ""
    }
    append_boxed_content_line(out, text, state.cols, row, state.rows, style)
    row += 1
  }
  if rows > 1 {
    append_styled_screen_line(
      out,
      border_line("", state.cols, pane_index == state.active),
      state.cols,
      row,
      state.rows,
      style,
    )
    row += 1
  }
  row
}

///|
fn render_text(state : MuxState) -> String {
  let out = StringBuilder()
  let mut row = 0
  let visible_count = visible_pane_count(state)
  if visible_count == 0 {
    append_screen_line(out, "no panes", state.cols, row, state.rows)
    row += 1
  } else {
    for visible in 0..<visible_count {
      row = append_pane(
        out,
        state,
        visible_pane_index(state, visible),
        visible,
        visible_count,
        row,
      )
    }
  }
  while row < state.rows - 1 {
    append_screen_line(out, "", state.cols, row, state.rows)
    row += 1
  }
  append_styled_screen_line(
    out,
    status_line(state),
    state.cols,
    row,
    state.rows,
    status_style(state),
  )
  out.to_string()
}

///|
fn active_cursor_position(state : MuxState) -> CursorPosition? {
  let visible_count = visible_pane_count(state)
  if visible_count == 0 ||
    state.active < 0 ||
    state.active >= state.panes.length() {
    return None
  }
  let total = @cmp.maximum(state.rows - 1, 1)
  let mut row0 = 0
  for visible in 0..<visible_count {
    let rows = slot_rows(total, visible_count, visible)
    let pane_index = visible_pane_index(state, visible)
    if pane_index == state.active {
      let pane = state.panes[pane_index]
      let content_rows = rows - 2
      let content_cols = state.cols - 2
      if content_rows <= 0 ||
        content_cols <= 0 ||
        !pane.terminal.cursor_visible() {
        return None
      }
      let cursor_row = pane.terminal
        .cursor_y()
        .to_int()
        .clamp(min=0, max=content_rows - 1)
      let cursor_col = pane.terminal
        .cursor_x()
        .to_int()
        .clamp(min=0, max=content_cols - 1)
      return Some({ row: row0 + cursor_row + 2, col: cursor_col + 2 })
    }
    row0 += rows
  }
  None
}

///|
async fn render(tty : @tty.Tty, state : MuxState) -> Unit {
  tty.hide_cursor()
  tty.set_cursor_position(1, 1)
  tty.erase_display()
  tty.write(render_text(state))
  match active_cursor_position(state) {
    Some(pos) => {
      tty.set_cursor_position(pos.row, pos.col)
      tty.show_cursor()
    }
    None => tty.hide_cursor()
  }
}

///|
fn terminal_size(tty : @tty.Tty) -> (Int, Int) {
  try tty.window_size() catch {
    _ => (24, 80)
  } noraise {
    size => (@cmp.maximum(size.rows, 2), @cmp.maximum(size.cols, 20))
  }
}

///|
fn is_prefix_key(key : @tty/input.KeyEvent) -> Bool {
  match key.code {
    Char('b') if key.modifiers.ctrl() => true
    Char('B') if key.modifiers.ctrl() => true
    _ => false
  }
}

///|
fn ctrl_bytes(ch : Char) -> Bytes? {
  let lower = ch.to_ascii_lowercase()
  if lower >= 'a' && lower <= 'z' {
    Some(Bytes::from_array([(lower.to_int() - 'a'.to_int() + 1).to_byte()]))
  } else {
    match lower {
      '[' => Some(b"\x1B")
      '\\' => Some(b"\x1C")
      ']' => Some(b"\x1D")
      '^' => Some(b"\x1E")
      '_' => Some(b"\x1F")
      _ => None
    }
  }
}

///|
fn text_bytes(key : @tty/input.KeyEvent) -> Bytes? {
  match key.code {
    Text =>
      match key.text {
        Some(text) => Some(@utf8.encode(text))
        None => None
      }
    Char(ch) if !key.modifiers.ctrl() && !key.modifiers.alt() =>
      match key.text {
        Some(text) => Some(@utf8.encode(text))
        None => Some(@utf8.encode([ch]))
      }
    Char(ch) if key.modifiers.ctrl() => ctrl_bytes(ch)
    _ => None
  }
}

///|
fn key_bytes(key : @tty/input.KeyEvent) -> Bytes? {
  match text_bytes(key) {
    Some(bytes) => Some(bytes)
    None =>
      match key.code {
        Enter => Some(b"\r")
        Tab => Some(b"\t")
        Backspace => Some(b"\x7F")
        Delete => Some(b"\x1B[3~")
        Escape => Some(b"\x1B")
        Up => Some(b"\x1B[A")
        Down => Some(b"\x1B[B")
        Right => Some(b"\x1B[C")
        Left => Some(b"\x1B[D")
        Home => Some(b"\x1B[H")
        End => Some(b"\x1B[F")
        PageUp => Some(b"\x1B[5~")
        PageDown => Some(b"\x1B[6~")
        Insert => Some(b"\x1B[2~")
        _ => None
      }
  }
}

///|
async fn send_to_active_pane(state : MuxState, bytes : Bytes) -> Unit {
  match state.active_pane() {
    Some(pane) =>
      if !pane.closed {
        pane.pty.write(bytes) catch {
          _ => state.status = "write failed"
        }
      }
    None => state.status = "no active pane"
  }
}

///|
async fn handle_prefix_key(
  state : MuxState,
  group : @async.TaskGroup[Unit],
  events : @aqueue.Queue[MuxEvent],
  key : @tty/input.KeyEvent,
) -> Unit {
  match key.code {
    Char('c') | Char('C') => add_pane(state, group, events)
    Char('n') | Char('N') | Char('o') | Char('O') => switch_next(state)
    Char('p') | Char('P') => switch_prev(state)
    Char('b') | Char('B') => send_to_active_pane(state, b"\x02")
    Char('q') | Char('Q') | Char('x') | Char('X') => state.done = true
    _ => state.status = "unknown prefix key"
  }
  state.prefix = false
}

///|
async fn handle_key(
  state : MuxState,
  group : @async.TaskGroup[Unit],
  events : @aqueue.Queue[MuxEvent],
  key : @tty/input.KeyEvent,
) -> Unit {
  if state.prefix {
    handle_prefix_key(state, group, events, key)
  } else if is_prefix_key(key) {
    state.prefix = true
    state.status = "prefix"
  } else {
    match key_bytes(key) {
      Some(bytes) => send_to_active_pane(state, bytes)
      None => state.status = "ignored key"
    }
  }
}

///|
async fn read_terminal_events(
  tty : @tty.Tty,
  events : @aqueue.Queue[MuxEvent],
) -> Unit {
  while true {
    let event = tty.read_event(esc_timeout_ms=EscTimeoutMs) catch {
      @async/io.ReaderClosed => {
        events.put(TerminalClosed)
        return
      }
      error => {
        events.put(Message("tty read failed: \{@debug.to_string(error)}"))
        return
      }
    }
    events.put(Terminal(event))
  }
}

///|
async fn read_pane_output(
  index : Int,
  pane : Pane,
  events : @aqueue.Queue[MuxEvent],
) -> Unit {
  let reader = pane.pty.reader()
  let buf : FixedArray[Byte] = FixedArray::make(ReadBufferSize, b'\x00')
  while true {
    let n = reader.read(buf) catch {
      error => {
        events.put(
          Message("pane \{pane.id} read failed: \{@debug.to_string(error)}"),
        )
        return
      }
    }
    if n <= 0 {
      let code = @async.with_timeout_opt(ShellExitTimeoutMs, () => {
        pane.pty.wait()
      }).unwrap_or(-1)
      events.put(PaneClosed(index, code))
      return
    }
    events.put(PaneOutput(index, Bytes::from_array(buf[:n])))
  }
}

///|
async fn handle_pane_output(
  state : MuxState,
  index : Int,
  bytes : Bytes,
) -> Unit {
  if index >= 0 && index < state.panes.length() {
    let pane = state.panes[index]
    if !pane.closed {
      pane.terminal.next_slice(bytes)
      pane.flush_replies()
    }
  }
}

///|
fn handle_pane_closed(state : MuxState, index : Int, code : Int) -> Unit {
  if index >= 0 && index < state.panes.length() {
    let pane = state.panes[index]
    pane.closed = true
    pane.exit_code = Some(code)
    state.status = "pane \{pane.id} exited with \{code}"
  }
}

///|
async fn handle_terminal_event(
  state : MuxState,
  group : @async.TaskGroup[Unit],
  events : @aqueue.Queue[MuxEvent],
  event : @tty.Event,
) -> Unit {
  match event {
    Input(Key(key)) => handle_key(state, group, events, key)
    Input(Paste(text)) => send_to_active_pane(state, @utf8.encode(text))
    Input(Unknown(bytes)) => send_to_active_pane(state, bytes)
    Input(Mouse(_)) => ()
    Input(FocusIn) => ()
    Input(FocusOut) => ()
    Resize(size) => {
      state.rows = @cmp.maximum(size.rows, 2)
      state.cols = @cmp.maximum(size.cols, 20)
      resize_visible_panes(state)
      state.status = "resized to \{state.cols}x\{state.rows}"
    }
  }
}

///|
async fn run_mux(tty : @tty.Tty) -> Unit {
  @async.with_task_group() <| group => {
    let events : @aqueue.Queue[MuxEvent] = Queue(kind=Unbounded)
    let (rows, cols) = terminal_size(tty)
    let state = MuxState::new(rows, cols)
    tty.hide_cursor()
    add_pane(state, group, events)
    render(tty, state)
    group.spawn_bg(no_wait=true) <| () => { read_terminal_events(tty, events) }
    while !state.done {
      match events.get() {
        Terminal(event) => handle_terminal_event(state, group, events, event)
        TerminalClosed => state.done = true
        PaneOutput(index, bytes) => handle_pane_output(state, index, bytes)
        PaneClosed(index, code) => handle_pane_closed(state, index, code)
        Message(text) => state.status = text
      }
      render(tty, state)
    }
    for pane in state.panes {
      pane.shutdown()
    }
  }
}

///|
async fn restore_terminal(tty : @tty.Tty) -> Unit {
  tty.reset_style()
  tty.show_cursor()
}

///|
async fn main {
  let tty = @tty.Tty::open()
  try tty.with_alt_screen(() => tty.with_raw_mode(() => run_mux(tty))) catch {
    error => {
      restore_terminal(tty)
      tty.close()
      println("mini tmux demo failed.")
      println(@debug.to_string(error))
    }
  } noraise {
    _ => {
      restore_terminal(tty)
      tty.close()
    }
  }
}
