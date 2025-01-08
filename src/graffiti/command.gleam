import terminil

import gleam/otp/task

pub type Cmd(msg) {
  Quit
  Register(task.Task(msg))
  Terminal(terminil.Command)
}

pub fn quit() -> Cmd(msg) {
  Quit
}

pub fn task(run block: fn() -> msg) -> fn() -> Cmd(msg) {
  fn() { Register(task.async(block)) }
}

pub fn terminal(command: terminil.Command) -> fn() -> Cmd(msg) {
  fn() { Terminal(command) }
}

@internal
pub fn from_fn(f: fn() -> Cmd(msg)) -> Cmd(msg) {
  f()
}
