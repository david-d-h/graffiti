import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/otp/actor

pub type Id(msg) =
  fn(Dynamic) -> #(Dynamic, Option(msg))

pub opaque type Subscription(msg) {
  // A subscription is not actually type-safe, so we need it to be opaque,
  // this way we can still achieve type-safety by controlling what type
  // of subscription is allowed to be instantiated.
  Subscription(
    state: Dynamic,
    generator: fn(Dynamic) -> #(Dynamic, Option(msg)),
  )
}

@external(erlang, "graffiti_ffi", "identity")
fn transmute(a: Dynamic) -> b

@internal
pub fn id(of subscription: Subscription(msg)) -> Id(msg) {
  subscription.generator
}

@internal
pub fn parts(of subscription: Subscription(msg)) -> #(Dynamic, Id(msg)) {
  #(subscription.state, subscription.generator)
}

pub fn new(
  initial state: state,
  generator block: fn(state) -> #(state, msg),
) -> Subscription(msg) {
  Subscription(dynamic.from(Nil), fn(_) {
    let #(state, msg): #(state, msg) = block(state)
    #(dynamic.from(state), option.Some(msg))
  })
}

pub fn map(
  generator block: fn() -> a,
  with mapper: fn(a) -> msg,
) -> Subscription(msg) {
  stateless(fn() { mapper(block()) })
}

pub fn filter_map(
  generator block: fn() -> a,
  with mapper: fn(a) -> Option(msg),
) -> Subscription(msg) {
  Subscription(dynamic.from(Nil), fn(_) {
    #(dynamic.from(Nil), mapper(block()))
  })
}

pub fn actor(
  start: fn() -> Subject(a),
  mapper: fn(a) -> msg,
) -> Subscription(msg) {
  Subscription(dynamic.from(option.None), fn(subject) {
    let subject: Option(Subject(a)) = transmute(subject)
    let subject: Subject(a) = option.lazy_unwrap(subject, start)
    let msg = process.receive_forever(subject)
    #(dynamic.from(option.Some(subject)), option.Some(mapper(msg)))
  })
}

pub fn stateless(generator f: fn() -> msg) -> Subscription(msg) {
  new(Nil, fn(_) { #(Nil, f()) })
}

fn move(x: a) -> a {
  x
}

pub fn unique(id: a, generator f: fn() -> msg) -> Subscription(msg) {
  new(Nil, fn(_) {
    move(id)
    #(Nil, f())
  })
}

pub type Message(msg) {
  Shutdown
  Yield(to: Subject(msg))
}

pub fn run(subscription: Subscription(msg)) -> Subject(Message(msg)) {
  let assert Ok(subject) = actor.start(subscription, loop)
  subject
}

fn loop(
  message: Message(msg),
  subscription: Subscription(msg),
) -> actor.Next(Message(msg), Subscription(msg)) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
    Yield(to) -> {
      let #(sub, msg) = produce_message(subscription)
      process.send(to, msg)
      actor.continue(sub)
    }
  }
}

fn produce_message(sub: Subscription(msg)) -> #(Subscription(msg), msg) {
  case sub.generator(sub.state) {
    #(state, option.Some(msg)) -> #(Subscription(..sub, state:), msg)
    #(state, option.None) -> produce_message(Subscription(..sub, state:))
  }
}
