///|
const MaxIntermediate : Int = 4

///|
const MaxParams : Int = 24

///|
const MaxParamDigits : Int = 255

///|
const MaxParamValue : UInt16 = 65535

///|
/// Dispatch payload borrowing the parser's reused accumulators. Like upstream
/// (`Parser.zig`: `self.intermediates[0..idx]`, `self.params[0..idx]`), the
/// `intermediates` / `params` views alias the parser's `Array` buffers and are
/// only valid for the synchronous dispatch window — the next `Parser::next`
/// rewinds and overwrites those buffers via `clear()`. Consumers must read them
/// during dispatch and copy (not store) anything that must outlive it.
pub(all) struct Csi {
  intermediates : ArrayView[Byte]
  params : ArrayView[UInt16]
  params_sep : @seplist.SepList
  final_byte : Byte
}

///|
/// Borrowed dispatch payload; see `Csi` for the aliasing/lifetime contract.
pub(all) struct Esc {
  intermediates : ArrayView[Byte]
  final_byte : Byte
}

///|
/// Borrowed dispatch payload; see `Csi` for the aliasing/lifetime contract.
/// The stream layer copies these views into an owned `DcsHookPayload` because
/// the DCS hook outlives the synchronous dispatch (mirrors upstream
/// `dcs.zig`'s copy-into-Command).
pub(all) struct Dcs {
  intermediates : ArrayView[Byte]
  params : ArrayView[UInt16]
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
/// The up-to-three actions a single `next` step can emit, in dispatch order:
/// the state-exit action, the transition action, then the state-entry action.
/// An immutable `#valtype` of three inline `Action?` words — returned by value
/// with no heap object, so the hot escape-parsing path allocates nothing per
/// byte beyond the (rare) `Action` payloads themselves. The type stays opaque
/// (representation/order private); callers read the three slots in dispatch
/// order through `exit`/`transition`/`entry`, each a single field read that
/// avoids the `match index` branch the old `op_get` carried.
#valtype
struct ActionList {
  exit : Action?
  transition : Action?
  entry : Action?
}

///|
/// The state-exit action (dispatched first), if any.
pub fn ActionList::exit(self : ActionList) -> Action? {
  self.exit
}

///|
/// The transition action (dispatched second), if any.
pub fn ActionList::transition(self : ActionList) -> Action? {
  self.transition
}

///|
/// The state-entry action (dispatched last), if any.
pub fn ActionList::entry(self : ActionList) -> Action? {
  self.entry
}

///|
/// Abstract (no `pub`): the type name crosses the package boundary but its
/// mutable transition state stays opaque. The stream layer drives the parser
/// only through `new`/`next`/`is_ground`/`enter_escape`/`reset_ground`/`deinit`,
/// so the state-machine invariants enforced by `next()`/`clear()` cannot be
/// bypassed by assigning fields from another package.
struct Parser {
  mut state : ParserState
  intermediates : Array[Byte]
  params : Array[UInt16]
  mut params_sep : @seplist.SepList
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
    params_sep: @seplist.SepList::init_empty(),
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
              intermediates: self.intermediates,
              params: self.params,
              final_byte: c,
            }),
          )
        }
      SosPmApcString => Some(ApcStart)
      _ => None
    }
  }

  self.state = next_state
  { exit: exit_action, transition: transition_action, entry: entry_action }
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
              intermediates: self.intermediates,
              params: self.params,
              params_sep: self.params_sep,
              final_byte: c,
            }),
          )
        }
      }
    EscDispatch =>
      Some(EscDispatch({ intermediates: self.intermediates, final_byte: c }))
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
      self.params_sep = self.params_sep.set(self.params.length())
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
  // Reset length to zero while keeping the backing buffers, mirroring upstream's
  // fixed-size arrays + length counters (`clear()` just rewinds the counts).
  // The dispatched `Csi`/`Esc`/`Dcs` payloads borrow views into these buffers
  // (like upstream's slices) and are consumed synchronously before the next
  // `next()` rewinds them here, so reuse is safe.
  self.intermediates.clear()
  self.params.clear()
  self.params_sep = @seplist.SepList::init_empty()
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
