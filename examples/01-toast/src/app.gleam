// IMPORTS ---------------------------------------------------------------------

import gleam/float
import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/portal

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init:, update:, view:)

  let assert Ok(_) = portal.register()
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(toasts: List(Toast), next_id: Int)
}

type Toast {
  Toast(id: Int, message: String)
}

fn init(_) {
  let model = Model(toasts: [], next_id: 1)
  let effect = effect.none()

  #(model, effect)
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  UserClickedSubmit
  UserDismissedToast(id: Int)
  TimerDismissedToast
}

fn update(model: Model, msg: Msg) {
  case msg {
    UserClickedSubmit -> {
      let toast =
        Toast(id: model.next_id, message: "Form submitted successfully!")
      let model =
        Model(toasts: [toast, ..model.toasts], next_id: model.next_id + 1)
      let effect = schedule_dismiss()

      #(model, effect)
    }

    UserDismissedToast(id:) -> {
      let toasts = list.filter(model.toasts, fn(toast) { toast.id != id })
      let model = Model(..model, toasts:)
      let effect = effect.none()

      #(model, effect)
    }

    TimerDismissedToast -> {
      let toasts = list.drop(model.toasts, 1)
      let model = Model(..model, toasts:)
      let effect = effect.none()

      #(model, effect)
    }
  }
}

fn schedule_dismiss() -> Effect(Msg) {
  use dispatch <- effect.from
  use <- set_timeout(5000)

  dispatch(TimerDismissedToast)
}

@external(javascript, "./app.ffi.mjs", "set_timeout")
fn set_timeout(delay: Int, callback: fn() -> a) -> Nil

// VIEW ------------------------------------------------------------------------

const max_toasts: Int = 5

fn view(model: Model) {
  html.div(
    [attribute.class("w-screen h-screen flex items-center justify-center")],
    [
      html.button(
        [
          attribute.class("bg-blue-50 border border-blue-200 text-blue-700"),
          attribute.class("px-2 py-1 rounded cursor-pointer"),
          event.on_click(UserClickedSubmit),
        ],
        [html.text("Submit")],
      ),
      // These toasts are rendered into the `<body>` element outside of our app.
      // That way they always appear on top of any other content.
      portal.to("body", [], [
        keyed.fragment({
          use toast, i <- list.index_map(list.take(model.toasts, max_toasts))
          let key = int.to_string(toast.id)
          let toast = view_toast(toast.message, i)

          #(key, toast)
        }),
      ]),
    ],
  )
}

fn view_toast(message: String, index: Int) -> Element(msg) {
  let z_index = max_toasts - index
  let y = index * -10
  let opacity = int.to_float(100 - { index * 20 }) /. 100.0
  let scale = 1.0 -. { int.to_float(index) *. 0.05 }
  let transform =
    "translateY("
    <> int.to_string(y)
    <> "px) scale("
    <> float.to_string(scale)
    <> ")"

  html.div(
    [
      attribute.style("transform", transform),
      attribute.style("opacity", float.to_string(opacity)),
      attribute.style("z-index", int.to_string(z_index)),
      attribute.class(
        " starting:-bottom-4 starting:opacity-0
          bottom-8 left-8 p-2 fixed transition-all
          bg-green-50 border border-green-200 text-green-700 rounded shadow p-2
        ",
      ),
    ],
    [html.text(message)],
  )
}
