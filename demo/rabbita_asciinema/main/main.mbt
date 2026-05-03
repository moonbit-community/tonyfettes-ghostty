///|
priv struct Model {
  ready : Bool
}

///|
priv enum Msg {
  Noop
}

///|
fn initial_model() -> Model {
  { ready: true }
}

///|
fn update(
  _dispatch : @cmd.Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@cmd.Cmd, Model) {
  match msg {
    Noop => (@cmd.none, model)
  }
}

///|
fn view(_dispatch : @cmd.Dispatch[Msg], model : Model) -> @html.Html {
  let status = if model.ready { "ready" } else { "loading" }
  @html.main_(class="app-shell", [
    @html.section(class="player-shell", [
      @html.div(class="screen", [
        @html.div(class="terminal-toolbar", [
          @html.div(
            class="terminal-title",
            "Ghostty Rabbita asciinema · \{status}",
          ),
        ]),
        @html.div(class="terminal-host", "P16 demo shell"),
      ]),
    ]),
  ])
}

///|
fn subscriptions(_dispatch : @cmd.Dispatch[Msg], _model : Model) -> @sub.Sub {
  @sub.none
}

///|
#warnings("-alert_unstable")
fn main {
  let app = @rabbita.cell(model=initial_model(), update~, view~, subscriptions~)
  @rabbita.new(app).mount("app")
}
