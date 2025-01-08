import graffiti/command.{type Cmd}
import graffiti/subscription.{type Subscription}

import gleam/option.{type Option}

pub type Init(model, msg) =
  fn() -> #(model, List(fn() -> Cmd(msg)))

pub type Update(model, msg) =
  fn(model, msg) -> #(model, List(fn() -> Cmd(msg)))

pub type Render(model) =
  fn(model) -> String

pub type Source(model, msg) =
  fn(model) -> List(Subscription(msg))

pub type App(model, msg) {
  App(
    title: Option(String),
    init: Init(model, msg),
    update: Update(model, msg),
    render: Render(model),
    source: Source(model, msg),
  )
}
