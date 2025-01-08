import gleam/erlang/process
import gleam/int
import gleam/option.{None, Some}
import graffiti
import graffiti/command
import graffiti/subscription
import terminil

// A command can be used to control among other things, the application's
// runtime, and the terminal window.
type Cmd =
  graffiti.Cmd(Msg)

type Subscription =
  subscription.Subscription(Msg)

// The state of your application.
pub type Model {
  Model(tick: Int, enabled: Bool)
}

// This is your message type, messages get produced by either
// tasks (command.task) or subscriptions, each `Msg` will essentially
// be an event your application can react to, to update your `Model` state.
type Msg {
  Quit
  Toggle
  Tick
}

// initialise the application's state, and (optionally) provide
// some commands to the runtime to be run immediately, such as
// a command to enter the alternate screen.
fn init() -> #(Model, Cmd) {
  #(Model(tick: 0, enabled: False), [
    command.terminal(terminil.enter_alternate_screen),
  ])
}

pub fn main() {
  // Enabling "raw mode" is required if you want to access the user's
  // keypresses as they come in, try removing this line and see what
  // happens. By default the terminal is in "cooked mode" which basically
  // means that the terminal will handle the user's input, until for example,
  // the user hits return.
  terminil.enable_raw_mode()

  graffiti.app(init, update, render)
  |> graffiti.source(subscriptions)
  |> graffiti.title("ticker")
  |> graffiti.run()
}

// The core of your application, this function will run
// every time your application receieves a message from
// either your subscriptions, or your running tasks.
fn update(model: Model, msg: Msg) -> #(Model, Cmd) {
  case msg {
    Quit -> #(model, [command.quit])
    Toggle -> #(Model(..model, enabled: !model.enabled), [])
    Tick -> #(Model(..model, tick: model.tick + 1), [])
  }
}

// Return a string to the runtime, the result of this function
// will be rendered to the terminal every time your state updates.
pub fn render(model: Model) -> String {
  "Times ticked: " <> int.to_string(model.tick)
}

// A basic subscription that continually reads terminal input (keypresses)
// and essentially maps them to optional messages (your `Msg` type).
//
// `Some(msg)` will be yielded to the runtime, while `None` will cause the
// subscription to recurse and try to produce a message again.
fn on_key_press() -> Subscription {
  subscription.filter_map(terminil.read_char, fn(key) {
    case key {
      <<"q">> -> Some(Quit)
      <<" ">> -> Some(Toggle)
      _ -> None
    }
  })
}

// This function defines what subscriptions run in your application
// based on the `Model` state. Subscriptions *are* stateful and they
// persist through `update` calls, unless you remove them altogether.
//
// This function gets called every time your state updates.
fn subscriptions(model: Model) -> List(Subscription) {
  let ticker =
    // A subscription that continually yields the `Tick` message.
    subscription.stateless(fn() {
      process.sleep(33)
      Tick
    })

  case model.enabled {
    // The model indicates the ticker should be enabled, so let's add it.
    True -> [ticker, on_key_press()]

    // The model now indicates the ticker should be disabled, remove it.
    False -> [on_key_press()]
  }
}
