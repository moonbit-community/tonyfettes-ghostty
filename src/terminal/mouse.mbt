///|
pub enum MouseEvent {
  None
  X10
  Normal
  Button
  Any
} derive(Eq, Debug)

///|
pub fn mouse_event_sends_motion(event : MouseEvent) -> Bool {
  event == MouseEvent::Button || event == MouseEvent::Any
}

///|
pub enum MouseFormat {
  X10
  Utf8
  Sgr
  Urxvt
  SgrPixels
} derive(Eq, Debug)

///|
pub enum MouseShape {
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
  ("default", MouseShape::Default),
  ("context-menu", MouseShape::ContextMenu),
  ("help", MouseShape::Help),
  ("pointer", MouseShape::Pointer),
  ("progress", MouseShape::Progress),
  ("wait", MouseShape::Wait),
  ("cell", MouseShape::Cell),
  ("crosshair", MouseShape::Crosshair),
  ("text", MouseShape::Text),
  ("vertical-text", MouseShape::VerticalText),
  ("alias", MouseShape::Alias),
  ("copy", MouseShape::Copy),
  ("move", MouseShape::Move),
  ("no-drop", MouseShape::NoDrop),
  ("not-allowed", MouseShape::NotAllowed),
  ("grab", MouseShape::Grab),
  ("grabbing", MouseShape::Grabbing),
  ("all-scroll", MouseShape::AllScroll),
  ("col-resize", MouseShape::ColResize),
  ("row-resize", MouseShape::RowResize),
  ("n-resize", MouseShape::NResize),
  ("e-resize", MouseShape::EResize),
  ("s-resize", MouseShape::SResize),
  ("w-resize", MouseShape::WResize),
  ("ne-resize", MouseShape::NeResize),
  ("nw-resize", MouseShape::NwResize),
  ("se-resize", MouseShape::SeResize),
  ("sw-resize", MouseShape::SwResize),
  ("ew-resize", MouseShape::EwResize),
  ("ns-resize", MouseShape::NsResize),
  ("nesw-resize", MouseShape::NeswResize),
  ("nwse-resize", MouseShape::NwseResize),
  ("zoom-in", MouseShape::ZoomIn),
  ("zoom-out", MouseShape::ZoomOut),
  ("left_ptr", MouseShape::Default),
  ("question_arrow", MouseShape::Help),
  ("hand", MouseShape::Pointer),
  ("left_ptr_watch", MouseShape::Progress),
  ("watch", MouseShape::Wait),
  ("cross", MouseShape::Crosshair),
  ("xterm", MouseShape::Text),
  ("dnd-link", MouseShape::Alias),
  ("dnd-copy", MouseShape::Copy),
  ("dnd-move", MouseShape::Move),
  ("dnd-no-drop", MouseShape::NoDrop),
  ("crossed_circle", MouseShape::NotAllowed),
  ("hand1", MouseShape::Grab),
  ("right_side", MouseShape::EResize),
  ("top_side", MouseShape::NResize),
  ("top_right_corner", MouseShape::NeResize),
  ("top_left_corner", MouseShape::NwResize),
  ("bottom_side", MouseShape::SResize),
  ("bottom_right_corner", MouseShape::SeResize),
  ("bottom_left_corner", MouseShape::SwResize),
  ("left_side", MouseShape::WResize),
  ("fleur", MouseShape::AllScroll),
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
