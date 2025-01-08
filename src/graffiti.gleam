import graffiti/app.{
  type App, type Init, type Render, type Source, type Update, App,
}
import graffiti/command
import graffiti/runtime

import gleam/option

pub type Cmd(msg) =
  List(fn() -> command.Cmd(msg))

pub fn app(
  init: Init(model, msg),
  update: Update(model, msg),
  render: Render(model),
) -> App(model, msg) {
  App(title: option.None, init:, update:, render:, source: fn(_) { [] })
}

pub fn title(app: App(model, msg), of content: String) -> App(model, msg) {
  App(..app, title: option.Some(content))
}

pub fn source(
  app: App(model, msg),
  subscriptions source: Source(model, msg),
) -> App(model, msg) {
  App(..app, source:)
}

pub fn run(app: App(model, msg)) -> model {
  runtime.launch(app)
}
