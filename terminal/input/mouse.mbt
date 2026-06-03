///|
pub(all) enum MouseEvent {
  None
  X10
  Normal
  Button
  Any
} derive(Eq, Debug)

///|
pub fn mouse_event_sends_motion(event : MouseEvent) -> Bool {
  event == Button || event == Any
}

///|
pub(all) enum MouseFormat {
  X10
  Utf8
  Sgr
  Urxvt
  SgrPixels
} derive(Eq, Debug)

///|
pub(all) enum MouseShape {
  Default
  ContextMenu
  Help
  Pointer
  Progress
  Wait
  Cell
  Crosshair
  Text
  VerticalText
  Alias
  Copy
  Move
  NoDrop
  NotAllowed
  Grab
  Grabbing
  AllScroll
  ColResize
  RowResize
  NResize
  EResize
  SResize
  WResize
  NeResize
  NwResize
  SeResize
  SwResize
  EwResize
  NsResize
  NeswResize
  NwseResize
  ZoomIn
  ZoomOut
} derive(Eq, Debug)

///|
let mouse_shape_names : ReadOnlyArray[(String, MouseShape)] = [
  ("default", Default),
  ("context-menu", ContextMenu),
  ("help", Help),
  ("pointer", Pointer),
  ("progress", Progress),
  ("wait", Wait),
  ("cell", Cell),
  ("crosshair", Crosshair),
  ("text", Text),
  ("vertical-text", VerticalText),
  ("alias", Alias),
  ("copy", Copy),
  ("move", Move),
  ("no-drop", NoDrop),
  ("not-allowed", NotAllowed),
  ("grab", Grab),
  ("grabbing", Grabbing),
  ("all-scroll", AllScroll),
  ("col-resize", ColResize),
  ("row-resize", RowResize),
  ("n-resize", NResize),
  ("e-resize", EResize),
  ("s-resize", SResize),
  ("w-resize", WResize),
  ("ne-resize", NeResize),
  ("nw-resize", NwResize),
  ("se-resize", SeResize),
  ("sw-resize", SwResize),
  ("ew-resize", EwResize),
  ("ns-resize", NsResize),
  ("nesw-resize", NeswResize),
  ("nwse-resize", NwseResize),
  ("zoom-in", ZoomIn),
  ("zoom-out", ZoomOut),
  ("left_ptr", Default),
  ("question_arrow", Help),
  ("hand", Pointer),
  ("left_ptr_watch", Progress),
  ("watch", Wait),
  ("cross", Crosshair),
  ("xterm", Text),
  ("dnd-link", Alias),
  ("dnd-copy", Copy),
  ("dnd-move", Move),
  ("dnd-no-drop", NoDrop),
  ("crossed_circle", NotAllowed),
  ("hand1", Grab),
  ("right_side", EResize),
  ("top_side", NResize),
  ("top_right_corner", NeResize),
  ("top_left_corner", NwResize),
  ("bottom_side", SResize),
  ("bottom_right_corner", SeResize),
  ("bottom_left_corner", SwResize),
  ("left_side", WResize),
  ("fleur", AllScroll),
]

///|
pub fn MouseShape::from_string(value : String) -> MouseShape? {
  for entry in mouse_shape_names {
    if entry.0 == value {
      return Some(entry.1)
    }
  }
  None
}
