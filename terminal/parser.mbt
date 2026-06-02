///|
const MaxIntermediate : Int = 4

///|
const MaxParams : Int = 24

///|
const MaxParamDigits : Int = 255

///|
const MaxParamValue : UInt16 = 65535

///|
priv struct SepList {
  mut bits : UInt64
} derive(Debug)

///|
fn SepList::init_empty() -> SepList {
  { bits: 0UL }
}

///|
fn SepList::set(self : SepList, index : Int) -> Unit {
  self.bits = self.bits | (1UL << index)
}

///|
fn SepList::is_set(self : SepList, index : Int) -> Bool {
  (self.bits & (1UL << index)) != 0UL
}

///|
fn SepList::count(self : SepList) -> Int {
  let mut result = 0
  for index in 0..<MaxParams {
    if self.is_set(index) {
      result += 1
    }
  }
  result
}

///|
priv struct Csi {
  intermediates : Array[Byte]
  params : Array[UInt16]
  params_sep : SepList
  final_byte : Byte
}

///|
priv struct Esc {
  intermediates : Array[Byte]
  final_byte : Byte
}

///|
priv struct Dcs {
  intermediates : Array[Byte]
  params : Array[UInt16]
  final_byte : Byte
}

///|
priv enum Action {
  Print(UInt)
  Execute(Byte)
  CsiDispatch(Csi)
  EscDispatch(Esc)
  OscDispatch(Command)
  DcsHook(Dcs)
  DcsPut(Byte)
  DcsUnhook
  ApcStart
  ApcPut(Byte)
  ApcEnd
}

///|
type ActionList = FixedArray[Action?]

///|
priv struct Parser {
  mut state : ParserState
  mut intermediates : Array[Byte]
  mut params : Array[UInt16]
  mut params_sep : SepList
  mut param_acc : UInt16
  mut param_acc_idx : Int
  osc_parser : OscParser
}

///|
fn Parser::new() -> Parser {
  {
    state: Ground,
    intermediates: [],
    params: [],
    params_sep: SepList::init_empty(),
    param_acc: 0,
    param_acc_idx: 0,
    osc_parser: OscParser::new(),
  }
}

///|
fn Parser::deinit(self : Parser) -> Unit {
  self.osc_parser.deinit()
}

///|
fn Parser::next(self : Parser, c : Byte) -> ActionList {
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
fn clone_bytes(source : Array[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  for value in source {
    result.push(value)
  }
  result
}

///|
fn clone_params(source : Array[UInt16]) -> Array[UInt16] {
  let result : Array[UInt16] = []
  for value in source {
    result.push(value)
  }
  result
}
