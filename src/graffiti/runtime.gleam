import graffiti/app.{type App}
import graffiti/command.{type Cmd}
import graffiti/subscription

import terminil
import terminil/clear
import terminil/cursor

import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option
import gleam/otp/task.{type Task}
import gleam/pair
import gleam/result
import gleam/set

fn poll_tasks(
  tasks: List(Task(msg)),
  acc: List(Task(msg)),
  messages: List(msg),
) -> #(List(Task(msg)), List(msg)) {
  case tasks {
    [task, ..remaining] ->
      case task.try_await(task, 0) {
        Ok(msg) -> poll_tasks(remaining, acc, [msg, ..messages])
        Error(task.Exit(_)) -> poll_tasks(remaining, acc, messages)
        Error(task.Timeout) -> poll_tasks(remaining, [task, ..acc], messages)
      }
    [] -> #(acc, messages)
  }
}

fn draw(model: model, with renderer: app.Render(model)) -> Cmd(msg) {
  command.Terminal(
    terminil.batch([
      terminil.clear(clear.All),
      cursor.to(0, 0),
      terminil.print(renderer(model)),
    ]),
  )
}

fn do_update(
  model: model,
  update: app.Update(model, msg),
  render: app.Render(model),
  messages: List(msg),
) -> #(model, List(Cmd(msg))) {
  let #(model, commands) =
    list.fold(messages, #(model, []), fn(acc, message) {
      let #(model, acc) = acc
      let #(model, cmds) = update(model, message)
      let commands =
        list.map(cmds, command.from_fn)
        |> list.append(acc)
      #(model, commands)
    })

  #(model, list.append(commands, [draw(model, render)]))
}

type SubscriptionRegistry(msg) =
  dict.Dict(
    subscription.Id(msg),
    #(Subject(msg), Subject(subscription.Message(msg))),
  )

fn compute_subscriptions(
  source: app.Source(model, msg),
  model: model,
  registry previous: SubscriptionRegistry(msg),
) -> SubscriptionRegistry(msg) {
  let #(old, new) =
    list.fold(source(model), #(set.new(), []), fn(acc, sub) {
      let id = subscription.id(sub)
      case dict.has_key(previous, id) {
        True -> #(set.insert(acc.0, id), acc.1)
        False -> #(acc.0, [sub, ..acc.1])
      }
    })

  let registry =
    list.fold(new, dict.new(), fn(acc, sub) {
      let receiver = process.new_subject()
      let controller = subscription.run(sub)
      process.send(controller, subscription.Yield(to: receiver))
      dict.insert(acc, subscription.id(sub), #(receiver, controller))
    })

  dict.fold(previous, registry, fn(acc, id, sub) {
    case set.contains(old, id) {
      True -> dict.insert(acc, id, sub)
      False -> {
        let #(_, controller) = sub
        process.send(controller, subscription.Shutdown)
        acc
      }
    }
  })
}

fn run_loop(
  app: App(model, msg),
  model: model,
  commands: List(Cmd(msg)),
  subscriptions: SubscriptionRegistry(msg),
  tasks: List(Task(msg)),
) -> model {
  case commands {
    [command.Quit, ..] -> {
      terminil.execute(terminil.leave_alternate_screen)
      model
    }
    [command.Register(task), ..remaining] -> {
      run_loop(app, model, remaining, subscriptions, [task, ..tasks])
    }
    [command.Terminal(command), ..remaining] -> {
      terminil.execute(command)
      run_loop(app, model, remaining, subscriptions, tasks)
    }
    [] -> {
      let #(tasks, messages) = poll_tasks(tasks, [], [])

      let messages =
        dict.fold(subscriptions, process.new_selector(), fn(selector, _, sub) {
          process.selecting(selector, sub.0, pair.new(sub, _))
        })
        |> process.select(10)
        |> result.replace_error(messages)
        |> result.map(fn(s) {
          let #(sub, msg) = s
          process.send(sub.1, subscription.Yield(sub.0))
          [msg, ..messages]
        })
        |> result.unwrap_both()

      case messages {
        [] -> run_loop(app, model, commands, subscriptions, tasks)
        _ -> {
          let #(model, commands) =
            do_update(model, app.update, app.render, messages)

          let subscriptions =
            compute_subscriptions(app.source, model, subscriptions)

          run_loop(app, model, commands, subscriptions, tasks)
        }
      }
    }
  }
}

pub fn launch(app: App(model, msg)) -> model {
  let #(model, commands) = app.init()

  let subscriptions = compute_subscriptions(app.source, model, dict.new())

  let commands =
    option.map(app.title, fn(content) {
      [command.terminal(terminil.title(content)), ..commands]
    })
    |> option.unwrap(commands)
    |> list.map(command.from_fn)

  run_loop(
    app,
    model,
    list.append(commands, [draw(model, app.render)]),
    subscriptions,
    [],
  )
}
