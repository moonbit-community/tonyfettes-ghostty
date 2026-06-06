///|
const MaxIntermediate : Int = 4

///|
const MaxParams : Int = 24

///|
const MaxParamDigits : Int = 255

///|
const MaxParamValue : UInt16 = 65535

///|
/// Abstract (no `pub`): a colon-vs-semicolon separator bitset built and read
/// only through `init_empty`/`set`/`is_set`/`count`, so its backing word stays
/// sealed across the package boundary.
struct SepList {
  mut bits : UInt64
} derive(Debug)

///|
pub fn SepList::init_empty() -> SepList {
  { bits: 0UL }
}

///|
pub fn SepList::set(self : SepList, index : Int) -> Unit {
  self.bits = self.bits | (1UL << index)
}

///|
pub fn SepList::is_set(self : SepList, index : Int) -> Bool {
  (self.bits & (1UL << index)) != 0UL
}

///|
pub fn SepList::count(self : SepList) -> Int {
  let mut result = 0
  for index in 0..<MaxParams {
    if self.is_set(index) {
      result += 1
    }
  }
  result
}

///|
pub(all) struct Csi {
  intermediates : Bytes
  params : ReadOnlyArray[UInt16]
  params_sep : SepList
  final_byte : Byte
}

///|
pub(all) struct Esc {
  intermediates : Bytes
  final_byte : Byte
}

///|
pub(all) struct Dcs {
  intermediates : Bytes
  params : ReadOnlyArray[UInt16]
  final_byte : Byte
}

///|
pub(all) enum Action {
  Print(UInt)
  Execute(Byte)
  CsiDispatch(Csi)
  EscDispatch(Esc)
  OscDispatch(@osc.Command)
  DcsHook(Dcs)
  DcsPut(Byte)
  DcsUnhook
  ApcStart
  ApcPut(Byte)
  ApcEnd
}

///|
pub type ActionList = FixedArray[Action?]

///|
/// Abstract (no `pub`): the type name crosses the package boundary but its
/// mutable transition state stays opaque. The stream layer drives the parser
/// only through `new`/`next`/`is_ground`/`enter_escape`/`reset_ground`/`deinit`,
/// so the state-machine invariants enforced by `next()`/`clear()` cannot be
/// bypassed by assigning fields from another package.
struct Parser {
  mut state : ParserState
  mut intermediates : Array[Byte]
  mut params : Array[UInt16]
  mut params_sep : SepList
  mut param_acc : UInt16
  mut param_acc_idx : Int
  osc_parser : @osc.OscParser
}

///|
pub fn Parser::new() -> Parser {
  {
    state: Ground,
    intermediates: [],
    params: [],
    params_sep: SepList::init_empty(),
    param_acc: 0,
    param_acc_idx: 0,
    osc_parser: @osc.OscParser::new(),
  }
}

///|
pub fn Parser::deinit(self : Parser) -> Unit {
  self.osc_parser.deinit()
}

///|
/// Whether the parser is at the ground state. Read-only boundary accessor so
/// the stream layer can drive its ground-state fast path without access to the
/// private parser-state machine.
pub fn Parser::is_ground(self : Parser) -> Bool {
  self.state == Ground
}

///|
/// Force the parser into the escape state and clear its accumulators. Boundary
/// helper for the stream layer's bare-ESC handling.
pub fn Parser::enter_escape(self : Parser) -> Unit {
  self.state = Escape
  self.clear()
}

///|
/// Reset the parser to the ground state. Boundary helper for callers that need
/// to rewind the parser without rebuilding it.
pub fn Parser::reset_ground(self : Parser) -> Unit {
  self.state = Ground
}

///|
pub fn Parser::next(self : Parser, c : Byte) -> ActionList {
  let effect = transition_for(c, self.state)
  let next_state = effect.state
  let action = effect.action

  let exit_action : Action? = if self.state == next_state {
    None
  } else {
    match self.state {
      OscString =>
        match self.osc_parser.end(Some(c)) {
          Some(command) => Some(OscDispatch(command))
          None => None
        }
      DcsPassthrough => Some(DcsUnhook)
      SosPmApcString => Some(ApcEnd)
      _ => None
    }
  }

  let transition_action = self.do_action(action, c)

  let entry_action : Action? = if self.state == next_state {
    None
  } else {
    match next_state {
      Escape | DcsEntry | CsiEntry => {
        self.clear()
        None
      }
      OscString => {
        self.osc_parser.reset()
        None
      }
      DcsPassthrough =>
        if self.params.length() >= MaxParams {
          None
        } else {
          if self.param_acc_idx > 0 {
            self.params.push(self.param_acc)
          }
          Some(
            DcsHook({
              intermediates: clone_bytes(self.intermediates),
              params: clone_params(self.params),
              final_byte: c,
            }),
          )
        }
      SosPmApcString => Some(ApcStart)
      _ => None
    }
  }

  self.state = next_state
  [exit_action, transition_action, entry_action]
}

///|
fn Parser::collect(self : Parser, c : Byte) -> Unit {
  if self.intermediates.length() >= MaxIntermediate {
    return
  }
  self.intermediates.push(c)
}

///|
fn Parser::do_action(
  self : Parser,
  action : TransitionAction,
  c : Byte,
) -> Action? {
  match action {
    None | Ignore => None
    Print => Some(Print(c.to_uint()))
    Execute => Some(Execute(c))
    Collect => {
      self.collect(c)
      None
    }
    Param => self.consume_param(c)
    OscPut => {
      self.osc_parser.next(c)
      None
    }
    CsiDispatch =>
      if self.params.length() >= MaxParams {
        None
      } else {
        if self.param_acc_idx > 0 {
          self.params.push(self.param_acc)
        }

        if c != b'm' && self.params_sep.count() > 0 {
          None
        } else {
          Some(
            CsiDispatch({
              intermediates: clone_bytes(self.intermediates),
              params: clone_params(self.params),
              params_sep: self.params_sep,
              final_byte: c,
            }),
          )
        }
      }
    EscDispatch =>
      Some(
        EscDispatch({
          intermediates: clone_bytes(self.intermediates),
          final_byte: c,
        }),
      )
    Put => Some(DcsPut(c))
    ApcPut => Some(ApcPut(c))
  }
}

///|
fn Parser::consume_param(self : Parser, c : Byte) -> Action? {
  if c == b';' || c == b':' {
    if self.params.length() >= MaxParams {
      return None
    }

    if c == b':' {
      self.params_sep.set(self.params.length())
    }
    self.params.push(self.param_acc)
    self.param_acc = 0
    self.param_acc_idx = 0
    return None
  }

  self.param_acc = saturating_param_append(self.param_acc, c)
  if self.param_acc_idx >= MaxParamDigits {
    return None
  }
  self.param_acc_idx += 1
  None
}

///|
fn Parser::clear(self : Parser) -> Unit {
  self.intermediates = []
  self.params = []
  self.params_sep = SepList::init_empty()
  self.param_acc = 0
  self.param_acc_idx = 0
}

///|
fn saturating_param_append(value : UInt16, digit : Byte) -> UInt16 {
  let next_value = value.to_int() * 10 + (digit.to_int() - b'0'.to_int())
  if next_value >= MaxParamValue.to_int() {
    MaxParamValue
  } else {
    next_value.to_uint16()
  }
}

///|
pub fn clone_bytes(source : Array[Byte]) -> Bytes {
  let result = Buffer()
  for value in source {
    result.write_byte(value)
  }
  result.to_bytes()
}

///|
pub fn clone_params(source : Array[UInt16]) -> ReadOnlyArray[UInt16] {
  ReadOnlyArray::from_array(source)
}
