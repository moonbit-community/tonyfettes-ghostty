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
const DiscoveryVersion : Int = 1

///|
const StartingTimeoutMs : UInt64 = 5000UL

///|
const AttachPollMs : Int = 100

///|
let server_mode_env : String = "MOONBIT_MINI_TMUX_SERVER_DIR"

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
extern "c" fn self_executable_bytes() -> Bytes = "moonbit_mini_tmux_self_executable"

///|
extern "c" fn self_args_flat_bytes() -> Bytes = "moonbit_mini_tmux_self_args_flat"

///|
#borrow(argv_flat, env_key, env_value, log_path)
extern "c" fn spawn_detached_process(
  argv_flat : Bytes,
  env_key : Bytes,
  env_value : Bytes,
  log_path : Bytes,
) -> Int = "moonbit_mini_tmux_spawn_detached"

///|
extern "c" fn current_process_id() -> Int = "moonbit_mini_tmux_process_id"

///|
extern "c" fn platform_bytes() -> Bytes = "moonbit_mini_tmux_platform"

///|
priv enum CliMode {
  Attach
  KillSession
  Server(String)
}

///|
priv enum DiscoveryState {
  DiscoveryStarting
  DiscoveryRunning
}

///|
priv struct Discovery {
  state : DiscoveryState
  pid : Int
  port : Int?
  created_at_unix_ms : UInt64
}

///|
priv struct DiscoveryPaths {
  dir : String
  lock_path : String
  json_path : String
  tmp_path : String
  log_path : String
}

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
  PaneOutput(Int, Bytes)
  PaneClosed(Int, Int)
  Message(String)
  ClientConnected(@socket.Tcp)
  ClientLine(Int, String)
  ClientClosed(Int)
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
priv struct ServerClient {
  id : Int
  conn : @socket.Tcp
  mut attached : Bool
}

///|
priv struct CursorPosition {
  row : Int
  col : Int
}

///|
priv struct ServerFrame {
  text : String
  cursor : CursorPosition?
}

///|
priv enum ClientEvent {
  LocalTerminal(@tty.Event)
  LocalTerminalClosed
  RemoteFrame(ServerFrame)
  RemoteClosed
  LocalMessage(String)
}

///|
priv enum ClientCommand {
  AttachClient(Int, Int)
  ClientInput(Bytes)
  ClientResize(Int, Int)
  ClientPrefix(Bool)
  ClientNewPane
  ClientNextPane
  ClientPrevPane
  ClientDisplayPanes
  ClientKillPane
  ClientDetach
  ClientKillSession
  ClientStatus(String)
}

///|
fn platform_name() -> String {
  @utf8.decode_lossy(platform_bytes())
}

///|
fn current_executable() -> String {
  let path = @utf8.decode_lossy(self_executable_bytes())
  if !path.is_empty() {
    path
  } else {
    @env.args().get(0).unwrap_or("tmux")
  }
}

///|
fn current_self_args() -> Array[String] {
  let flat = self_args_flat_bytes()
  let args : Array[String] = []
  let mut start = 0
  let mut index = 0
  for i in 0..<flat.length() {
    if flat[i] == b'\x00' {
      if index > 0 {
        args.push(@utf8.decode_lossy(flat[start:i]))
      }
      index += 1
      start = i + 1
    }
  }
  args
}

///|
fn env_non_empty(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => Some(value)
    _ => None
  }
}

///|
fn path_separator() -> String {
  if platform_name() == "windows" {
    "\\"
  } else {
    "/"
  }
}

///|
fn join_path(base : String, name : String) -> String {
  let sep = path_separator()
  if base.is_empty() {
    name
  } else if base.has_suffix(sep) {
    base + name
  } else {
    base + sep + name
  }
}

///|
fn temp_root() -> String {
  match env_non_empty("TMPDIR") {
    Some(path) => path
    None =>
      match env_non_empty("TEMP") {
        Some(path) => path
        None =>
          match env_non_empty("TMP") {
            Some(path) => path
            None => @env.current_dir().unwrap_or(".")
          }
      }
  }
}

///|
fn state_root() -> String {
  match platform_name() {
    "windows" =>
      match env_non_empty("LOCALAPPDATA") {
        Some(path) => path
        None => temp_root()
      }
    "macos" =>
      match env_non_empty("HOME") {
        Some(home) => join_path(home, "Library/Application Support")
        None => temp_root()
      }
    _ =>
      match env_non_empty("XDG_RUNTIME_DIR") {
        Some(path) => path
        None =>
          match env_non_empty("XDG_STATE_HOME") {
            Some(path) => path
            None =>
              match env_non_empty("HOME") {
                Some(home) => join_path(join_path(home, ".local"), "state")
                None => temp_root()
              }
          }
      }
  }
}

///|
fn discovery_paths(dir : String) -> DiscoveryPaths {
  {
    dir,
    lock_path: join_path(dir, "server.lock"),
    json_path: join_path(dir, "server.json"),
    tmp_path: join_path(dir, "server.json.tmp"),
    log_path: join_path(dir, "server.log"),
  }
}

///|
fn default_discovery_paths() -> DiscoveryPaths {
  discovery_paths(join_path(state_root(), "ghostty-mini-tmux"))
}

///|
async fn ensure_state_dir(paths : DiscoveryPaths) -> Unit {
  @fs.mkdir(paths.dir, permission=0o700, recursive=true) catch {
    _ => ()
  }
}

///|
async fn[T] with_discovery_lock(paths : DiscoveryPaths, f : async () -> T) -> T {
  ensure_state_dir(paths)
  let file = @fs.open(
    paths.lock_path,
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  defer file.close()
  file.lock(Exclusive)
  defer file.unlock()
  f()
}

///|
fn discovery_state_text(state : DiscoveryState) -> String {
  match state {
    DiscoveryStarting => "starting"
    DiscoveryRunning => "running"
  }
}

///|
fn discovery_json(discovery : Discovery) -> Json {
  let obj : Map[String, Json] = {
    "version": Json::number(DiscoveryVersion.to_double()),
    "state": Json::string(discovery_state_text(discovery.state)),
    "pid": Json::number(discovery.pid.to_double()),
    "created_at_unix_ms": Json::number(discovery.created_at_unix_ms.to_double()),
  }
  match discovery.port {
    Some(port) => obj["port"] = Json::number(port.to_double())
    None => ()
  }
  Json::object(obj)
}

///|
fn json_string_value(value : Json?) -> String? {
  match value {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_int_value(value : Json?) -> Int? {
  match value {
    Some(Number(number, ..)) => Some(number.to_int())
    _ => None
  }
}

///|
fn json_uint64_value(value : Json?) -> UInt64? {
  match value {
    Some(Number(number, ..)) => Some(number.to_uint64())
    _ => None
  }
}

///|
fn parse_discovery_json(root : Json) -> Discovery? {
  guard root is Object(obj) else { return None }
  guard json_int_value(obj.get("version")) is Some(DiscoveryVersion) else {
    return None
  }
  let state = match json_string_value(obj.get("state")) {
    Some("starting") => DiscoveryStarting
    Some("running") => DiscoveryRunning
    _ => return None
  }
  guard json_int_value(obj.get("pid")) is Some(pid) else { return None }
  guard json_uint64_value(obj.get("created_at_unix_ms")) is Some(created_at) else {
    return None
  }
  {
    state,
    pid,
    port: json_int_value(obj.get("port")),
    created_at_unix_ms: created_at,
  }
  |> Some
}

///|
async fn read_discovery_unlocked(paths : DiscoveryPaths) -> Discovery? {
  if !@fs.exists(paths.json_path) {
    return None
  }
  let text = @fs.read_file(paths.json_path).text() catch { _ => return None }
  let parsed = @json.parse(text) catch { _ => return None }
  parse_discovery_json(parsed)
}

///|
async fn write_discovery_unlocked(
  paths : DiscoveryPaths,
  discovery : Discovery,
) -> Unit {
  @fs.write_file(
    paths.tmp_path,
    discovery_json(discovery).stringify(indent=2),
    create_mode=CreateOrTruncate,
    permission=0o600,
  )
  @fs.rename(paths.tmp_path, paths.json_path, replace=true)
}

///|
async fn clear_discovery_unlocked(paths : DiscoveryPaths) -> Unit {
  @fs.remove(paths.json_path) catch {
    _ => ()
  }
  @fs.remove(paths.tmp_path) catch {
    _ => ()
  }
}

///|
fn starting_is_fresh(discovery : Discovery) -> Bool {
  @env.now() <= discovery.created_at_unix_ms + StartingTimeoutMs
}

///|
async fn spawn_server(paths : DiscoveryPaths) -> Int {
  let detached_pid = spawn_detached_process(
    self_args_flat_bytes(),
    @utf8.encode(server_mode_env),
    @utf8.encode(paths.dir),
    @utf8.encode(paths.log_path),
  )
  if detached_pid >= 0 {
    return detached_pid
  }
  let out = @process.redirect_to_file(
    paths.log_path,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  let err = @process.redirect_to_file(
    paths.log_path,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  let extra_env : Map[String, String] = {}
  extra_env[server_mode_env] = paths.dir
  @process.spawn_orphan(
    current_executable(),
    current_self_args(),
    extra_env~,
    inherit_env=true,
    stdout=out,
    stderr=err,
  )
}

///|
async fn connect_to_port(port : Int) -> @socket.Tcp? {
  try @socket.Tcp::connect(@socket.Addr::parse("127.0.0.1:\{port}")) catch {
    _ => None
  } noraise {
    conn => Some(conn)
  }
}

///|
async fn connect_or_spawn(paths : DiscoveryPaths) -> @socket.Tcp {
  ensure_state_dir(paths)
  while true {
    let discovery = with_discovery_lock(paths, () => {
      let current = read_discovery_unlocked(paths)
      match current {
        Some(discovery) =>
          match discovery.state {
            DiscoveryRunning if discovery.port is Some(_) => Some(discovery)
            DiscoveryStarting if starting_is_fresh(discovery) => Some(discovery)
            _ => {
              let pid = spawn_server(paths)
              let discovery : Discovery = {
                state: DiscoveryStarting,
                pid,
                port: None,
                created_at_unix_ms: @env.now(),
              }
              write_discovery_unlocked(paths, discovery)
              Some(discovery)
            }
          }
        _ => {
          let pid = spawn_server(paths)
          let discovery : Discovery = {
            state: DiscoveryStarting,
            pid,
            port: None,
            created_at_unix_ms: @env.now(),
          }
          write_discovery_unlocked(paths, discovery)
          Some(discovery)
        }
      }
    })
    match discovery {
      Some({ state: DiscoveryRunning, port: Some(port), .. }) =>
        match connect_to_port(port) {
          Some(conn) => return conn
          None =>
            with_discovery_lock(paths, () => clear_discovery_unlocked(paths))
        }
      _ => ()
    }
    @async.sleep(AttachPollMs)
  }
  abort("unreachable")
}

///|
fn parse_cli() -> CliMode raise {
  match env_non_empty(server_mode_env) {
    Some(dir) => return Server(dir)
    None => ()
  }
  let cmd = @argparse.Command(
    "tmux",
    flags=[FlagArg("server", long="server", hidden=true)],
    options=[OptionArg("state-dir", long="state-dir", hidden=true)],
    subcommands=[Command("attach"), Command("kill-session")],
  )
  let matches = cmd.parse()
  let state_dir = match matches.values {
    { "state-dir": [path], .. } => Some(path)
    _ => None
  }
  if matches.flags.get("server").unwrap_or(false) {
    Server(state_dir.unwrap_or(default_discovery_paths().dir))
  } else {
    match matches.subcommand {
      Some(("kill-session", _)) => KillSession
      _ => Attach
    }
  }
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
    status: "ready",
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
fn resize_mux(state : MuxState, rows : Int, cols : Int) -> Unit {
  state.rows = @cmp.maximum(rows, 2)
  state.cols = @cmp.maximum(cols, 20)
  resize_visible_panes(state)
  state.status = "resized to \{state.cols}x\{state.rows}"
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
    state.prefix = false
    state.status = "active pane \{state.panes[state.active].id}"
    resize_visible_panes(state)
  }
}

///|
fn switch_prev(state : MuxState) -> Unit {
  if state.panes.length() > 0 {
    state.active = (state.active + state.panes.length() - 1) %
      state.panes.length()
    state.prefix = false
    state.status = "active pane \{state.panes[state.active].id}"
    resize_visible_panes(state)
  }
}

///|
fn display_panes(state : MuxState) -> Unit {
  let out = StringBuilder()
  out.write_string("panes:")
  for i in 0..<state.panes.length() {
    let pane = state.panes[i]
    let marker = if i == state.active { "*" } else { " " }
    out.write_string(" \{marker}\{pane.id}")
  }
  state.prefix = false
  state.status = out.to_string()
}

///|
fn kill_active_pane(state : MuxState) -> Unit {
  match state.active_pane() {
    Some(pane) =>
      if pane.closed {
        state.status = "pane \{pane.id} already closed"
      } else {
        pane.closed = true
        pane.exit_code = Some(-1)
        pane.pty.cancel()
        pane.pty.close()
        state.prefix = false
        state.status = "killed pane \{pane.id}"
      }
    None => state.status = "no active pane"
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
  "mini tmux | panes=\{state.panes.length()} active=\{state.active} | \{mode} | Ctrl-b d detach c new n/o next p prev x kill Q kill-session | \{state.status}"
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
fn server_frame(state : MuxState) -> ServerFrame {
  { text: render_text(state), cursor: active_cursor_position(state) }
}

///|
fn hex_encode(bytes : Bytes) -> String {
  let out = StringBuilder()
  for byte in bytes {
    out.write_string(Byte::to_hex(byte))
  }
  out.to_string()
}

///|
fn hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex_decode(text : String) -> Bytes? {
  let bytes : Array[Byte] = []
  let mut high : Int? = None
  for ch in text {
    match hex_value(ch) {
      Some(value) =>
        match high {
          Some(prefix) => {
            bytes.push((prefix * 16 + value).to_byte())
            high = None
          }
          None => high = Some(value)
        }
      None => return None
    }
  }
  match high {
    Some(_) => None
    None => Some(Bytes::from_array(bytes))
  }
}

///|
fn frame_line(frame : ServerFrame) -> String {
  let (visible, row, col) = match frame.cursor {
    Some(pos) => (1, pos.row, pos.col)
    None => (0, 0, 0)
  }
  "frame \{visible} \{row} \{col} \{hex_encode(@utf8.encode(frame.text))}\n"
}

///|
fn bye_line(reason : String) -> String {
  "bye \{hex_encode(@utf8.encode(reason))}\n"
}

///|
fn parse_int_opt(text : String) -> Int? {
  try @string.parse_int(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_bool_flag(text : String) -> Bool? {
  match text {
    "0" => Some(false)
    "1" => Some(true)
    _ => None
  }
}

///|
fn split_line(line : String) -> Array[String] {
  line.split(" ").map(part => part.to_owned()).collect()
}

///|
fn parse_client_command(line : String) -> ClientCommand? {
  let parts = split_line(line)
  if parts.length() == 0 {
    return None
  }
  match parts[0] {
    "attach" if parts.length() == 3 =>
      match (parse_int_opt(parts[1]), parse_int_opt(parts[2])) {
        (Some(rows), Some(cols)) => Some(AttachClient(rows, cols))
        _ => None
      }
    "input" if parts.length() == 2 =>
      match hex_decode(parts[1]) {
        Some(bytes) => Some(ClientInput(bytes))
        None => None
      }
    "resize" if parts.length() == 3 =>
      match (parse_int_opt(parts[1]), parse_int_opt(parts[2])) {
        (Some(rows), Some(cols)) => Some(ClientResize(rows, cols))
        _ => None
      }
    "prefix" if parts.length() == 2 =>
      match parse_bool_flag(parts[1]) {
        Some(value) => Some(ClientPrefix(value))
        None => None
      }
    "new-pane" => Some(ClientNewPane)
    "next" => Some(ClientNextPane)
    "prev" => Some(ClientPrevPane)
    "display-panes" => Some(ClientDisplayPanes)
    "kill-pane" => Some(ClientKillPane)
    "detach" => Some(ClientDetach)
    "kill-session" => Some(ClientKillSession)
    "status" if parts.length() == 2 =>
      match hex_decode(parts[1]) {
        Some(bytes) => Some(ClientStatus(@utf8.decode_lossy(bytes)))
        None => None
      }
    _ => None
  }
}

///|
fn parse_server_frame(line : String) -> ServerFrame? {
  let parts = split_line(line)
  if parts.length() != 5 || parts[0] != "frame" {
    return None
  }
  match
    (
      parse_bool_flag(parts[1]),
      parse_int_opt(parts[2]),
      parse_int_opt(parts[3]),
      hex_decode(parts[4]),
    ) {
    (Some(visible), Some(row), Some(col), Some(bytes)) => {
      let cursor = if visible { Some({ row, col }) } else { None }
      Some({ text: @utf8.decode_lossy(bytes), cursor })
    }
    _ => None
  }
}

///|
async fn write_protocol_line(conn : @socket.Tcp, line : String) -> Bool {
  try conn.write(line) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
async fn send_frame(conn : @socket.Tcp, frame : ServerFrame) -> Bool {
  write_protocol_line(conn, frame_line(frame))
}

///|
async fn send_bye(conn : @socket.Tcp, reason : String) -> Bool {
  write_protocol_line(conn, bye_line(reason))
}

///|
async fn broadcast_frame(
  clients : Array[ServerClient],
  state : MuxState,
) -> Unit {
  let frame = server_frame(state)
  let failed : Array[Int] = []
  for client in clients {
    if client.attached {
      let ok = send_frame(client.conn, frame)
      if !ok {
        failed.push(client.id)
      }
    }
  }
  for id in failed {
    remove_client(clients, id)
  }
}

///|
fn find_client_index(clients : Array[ServerClient], id : Int) -> Int? {
  for i in 0..<clients.length() {
    if clients[i].id == id {
      return Some(i)
    }
  }
  None
}

///|
fn remove_client(clients : Array[ServerClient], id : Int) -> Unit {
  let mut i = 0
  while i < clients.length() {
    if clients[i].id == id {
      clients[i].conn.close()
      ignore(clients.remove(i))
    } else {
      i += 1
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
async fn handle_server_command(
  state : MuxState,
  group : @async.TaskGroup[Unit],
  events : @aqueue.Queue[MuxEvent],
  command : ClientCommand,
) -> Bool {
  match command {
    AttachClient(rows, cols) => resize_mux(state, rows, cols)
    ClientInput(bytes) => {
      state.prefix = false
      send_to_active_pane(state, bytes)
    }
    ClientResize(rows, cols) => resize_mux(state, rows, cols)
    ClientPrefix(value) => {
      state.prefix = value
      state.status = if value { "prefix" } else { "ready" }
    }
    ClientNewPane => add_pane(state, group, events)
    ClientNextPane => switch_next(state)
    ClientPrevPane => switch_prev(state)
    ClientDisplayPanes => display_panes(state)
    ClientKillPane => kill_active_pane(state)
    ClientDetach => {
      state.prefix = false
      state.status = "client detached"
      return true
    }
    ClientKillSession => {
      state.prefix = false
      state.status = "killing session"
      state.done = true
    }
    ClientStatus(text) => {
      state.prefix = false
      state.status = text
    }
  }
  false
}

///|
async fn accept_clients(
  server : @socket.TcpServer,
  events : @aqueue.Queue[MuxEvent],
) -> Unit {
  while true {
    let (conn, _) = server.accept() catch { _ => return }
    events.put(ClientConnected(conn))
  }
}

///|
async fn read_client_lines(
  id : Int,
  conn : @socket.Tcp,
  events : @aqueue.Queue[MuxEvent],
) -> Unit {
  while true {
    let line = conn.read_until("\n") catch {
      _ => {
        events.put(ClientClosed(id))
        return
      }
    }
    match line {
      Some(text) => events.put(ClientLine(id, text))
      None => {
        events.put(ClientClosed(id))
        return
      }
    }
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
async fn publish_running(paths : DiscoveryPaths, port : Int) -> Unit {
  with_discovery_lock(paths, () => {
    write_discovery_unlocked(paths, {
      state: DiscoveryRunning,
      pid: current_process_id(),
      port: Some(port),
      created_at_unix_ms: @env.now(),
    })
  })
}

///|
async fn clear_discovery(paths : DiscoveryPaths) -> Unit {
  with_discovery_lock(paths, () => clear_discovery_unlocked(paths))
}

///|
async fn run_server(paths : DiscoveryPaths) -> Unit {
  @env.unset_env_var(server_mode_env)
  ensure_state_dir(paths)
  @async.with_task_group() <| group => {
    let events : @aqueue.Queue[MuxEvent] = Queue(kind=Unbounded)
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    publish_running(paths, server.addr.port())
    let clients : Array[ServerClient] = []
    let state = MuxState::new(24, 80)
    let mut next_client_id = 0
    add_pane(state, group, events)
    group.spawn_bg(no_wait=true) <| () => { accept_clients(server, events) }
    while !state.done {
      match events.get() {
        PaneOutput(index, bytes) => handle_pane_output(state, index, bytes)
        PaneClosed(index, code) => handle_pane_closed(state, index, code)
        Message(text) => state.status = text
        ClientConnected(conn) => {
          let id = next_client_id
          next_client_id += 1
          clients.push({ id, conn, attached: false })
          group.spawn_bg(no_wait=true) <| () => {
            read_client_lines(id, conn, events)
          }
        }
        ClientLine(id, line) =>
          match find_client_index(clients, id) {
            Some(index) =>
              match parse_client_command(line) {
                Some(command) => {
                  if command is AttachClient(_, _) {
                    clients[index].attached = true
                  }
                  let detach = handle_server_command(
                    state, group, events, command,
                  )
                  if detach {
                    remove_client(clients, id)
                  }
                }
                None => state.status = "bad client command"
              }
            None => ()
          }
        ClientClosed(id) => remove_client(clients, id)
      }
      broadcast_frame(clients, state)
    }
    for client in clients {
      ignore(send_bye(client.conn, "session killed"))
      client.conn.close()
    }
    for pane in state.panes {
      pane.shutdown()
    }
    server.close()
    clear_discovery(paths)
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
async fn send_client_command(conn : @socket.Tcp, command : String) -> Bool {
  write_protocol_line(conn, command + "\n")
}

///|
async fn send_client_input(conn : @socket.Tcp, bytes : Bytes) -> Bool {
  send_client_command(conn, "input \{hex_encode(bytes)}")
}

///|
async fn send_client_status(conn : @socket.Tcp, text : String) -> Bool {
  send_client_command(conn, "status \{hex_encode(@utf8.encode(text))}")
}

///|
async fn read_local_terminal_events(
  tty : @tty.Tty,
  events : @aqueue.Queue[ClientEvent],
) -> Unit {
  while true {
    let event = tty.read_event(esc_timeout_ms=EscTimeoutMs) catch {
      @async/io.ReaderClosed => {
        events.put(LocalTerminalClosed)
        return
      }
      error => {
        events.put(LocalMessage("tty read failed: \{@debug.to_string(error)}"))
        return
      }
    }
    events.put(LocalTerminal(event))
  }
}

///|
async fn read_server_frames(
  conn : @socket.Tcp,
  events : @aqueue.Queue[ClientEvent],
) -> Unit {
  while true {
    let line = conn.read_until("\n") catch {
      _ => {
        events.put(RemoteClosed)
        return
      }
    }
    match line {
      Some(text) =>
        if text.has_prefix("bye ") {
          events.put(RemoteClosed)
          return
        } else {
          match parse_server_frame(text) {
            Some(frame) => events.put(RemoteFrame(frame))
            None => events.put(LocalMessage("bad server frame"))
          }
        }
      None => {
        events.put(RemoteClosed)
        return
      }
    }
  }
}

///|
async fn render_frame(tty : @tty.Tty, frame : ServerFrame) -> Unit {
  tty.hide_cursor()
  tty.set_cursor_position(1, 1)
  tty.erase_display()
  tty.write(frame.text)
  match frame.cursor {
    Some(pos) => {
      tty.set_cursor_position(pos.row, pos.col)
      tty.show_cursor()
    }
    None => tty.hide_cursor()
  }
}

///|
async fn handle_prefix_client_key(
  conn : @socket.Tcp,
  key : @tty/input.KeyEvent,
) -> Bool {
  match key.code {
    Char('c') | Char('C') => send_client_command(conn, "new-pane")
    Char('n') | Char('N') | Char('o') | Char('O') =>
      send_client_command(conn, "next")
    Char('p') | Char('P') => send_client_command(conn, "prev")
    Char('b') | Char('B') => send_client_input(conn, b"\x02")
    Char('d') | Char('D') => send_client_command(conn, "detach")
    Char('x') => send_client_command(conn, "kill-pane")
    Char('Q') => send_client_command(conn, "kill-session")
    Char('q') => send_client_command(conn, "display-panes")
    _ => send_client_status(conn, "unknown prefix key")
  }
}

///|
async fn handle_client_terminal_event(
  conn : @socket.Tcp,
  event : @tty.Event,
  prefix : Bool,
) -> (Bool, Bool) {
  match event {
    Input(Key(key)) =>
      if prefix {
        let ok = handle_prefix_client_key(conn, key)
        let done = match key.code {
          Char('d') | Char('D') | Char('Q') => true
          _ => false
        }
        (false, done || !ok)
      } else if is_prefix_key(key) {
        let ok = send_client_command(conn, "prefix 1")
        (ok, !ok)
      } else {
        match key_bytes(key) {
          Some(bytes) => (false, !send_client_input(conn, bytes))
          None => (false, !send_client_status(conn, "ignored key"))
        }
      }
    Input(Paste(text)) => (false, !send_client_input(conn, @utf8.encode(text)))
    Input(Unknown(bytes)) => (false, !send_client_input(conn, bytes))
    Input(Mouse(_)) => (prefix, false)
    Input(FocusIn) => (prefix, false)
    Input(FocusOut) => (prefix, false)
    Resize(size) => {
      let ok = send_client_command(
        conn,
        "resize \{@cmp.maximum(size.rows, 2)} \{@cmp.maximum(size.cols, 20)}",
      )
      (prefix, !ok)
    }
  }
}

///|
async fn run_client(tty : @tty.Tty, conn : @socket.Tcp) -> Unit {
  @async.with_task_group() <| group => {
    let events : @aqueue.Queue[ClientEvent] = Queue(kind=Unbounded)
    let (rows, cols) = terminal_size(tty)
    ignore(send_client_command(conn, "attach \{rows} \{cols}"))
    tty.hide_cursor()
    group.spawn_bg(no_wait=true) <| () => {
      read_local_terminal_events(tty, events)
    }
    group.spawn_bg(no_wait=true) <| () => { read_server_frames(conn, events) }
    let mut prefix = false
    let mut done = false
    while !done {
      match events.get() {
        LocalTerminal(event) => {
          let (next_prefix, stop) = handle_client_terminal_event(
            conn, event, prefix,
          )
          prefix = next_prefix
          done = stop
        }
        LocalTerminalClosed => done = true
        RemoteFrame(frame) => render_frame(tty, frame)
        RemoteClosed => done = true
        LocalMessage(text) => ignore(send_client_status(conn, text))
      }
    }
  }
}

///|
async fn restore_terminal(tty : @tty.Tty) -> Unit {
  tty.reset_style()
  tty.show_cursor()
}

///|
async fn run_attach() -> Unit {
  let conn = connect_or_spawn(default_discovery_paths())
  let tty = @tty.Tty::open()
  try
    tty.with_alt_screen(() => tty.with_raw_mode(() => run_client(tty, conn)))
  catch {
    error => {
      conn.close()
      restore_terminal(tty)
      tty.close()
      println("mini tmux demo failed.")
      println(@debug.to_string(error))
    }
  } noraise {
    _ => {
      conn.close()
      restore_terminal(tty)
      tty.close()
    }
  }
}

///|
async fn run_kill_session() -> Unit {
  let paths = default_discovery_paths()
  let discovery = with_discovery_lock(paths, () => {
    read_discovery_unlocked(paths)
  })
  match discovery {
    Some({ state: DiscoveryRunning, port: Some(port), .. }) =>
      match connect_to_port(port) {
        Some(conn) => {
          ignore(send_client_command(conn, "kill-session"))
          conn.close()
          println("mini tmux session kill requested.")
        }
        None => {
          with_discovery_lock(paths, () => clear_discovery_unlocked(paths))
          println("no reachable mini tmux server.")
        }
      }
    _ => println("no mini tmux server.")
  }
}

///|
async fn main {
  match parse_cli() {
    Attach => run_attach()
    KillSession => run_kill_session()
    Server(dir) => run_server(discovery_paths(dir))
  }
}
