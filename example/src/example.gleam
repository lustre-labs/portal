// IMPORTS ---------------------------------------------------------------------
import gleam/int
import gleam/list
import lustre
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import lustre/portal

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let assert Ok(_) = portal.register()
  let app = lustre.application(init, update, view)

  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(flashes: List(Flash), next_id: Int)
}

type Flash {
  Flash(id: Int, severity: Severity, message: String)
}

type Severity {
  Warning
  Error
  Info
  Success
}

fn init(_flags) {
  #(Model(flashes: [], next_id: 1), effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  UserClickedSave
  UserClickedReset
  UserClickedCancel
  UserClickedDelete
  FlashTimeoutExpired
  UserClickedAck(Int)
}

fn update(model, msg) {
  case msg {
    UserClickedSave -> {
      add_flash(model, Success, "Progress saved successfully!")
    }
    UserClickedCancel -> {
      add_flash(model, Warning, "Universe cancelled; please try again")
    }
    UserClickedReset -> {
      add_flash(model, Info, "World successfully reset.")
    }
    UserClickedDelete -> {
      add_flash(model, Error, "Could not delete: No such existence")
    }
    UserClickedAck(id) -> {
      let flashes = model.flashes |> list.filter(fn(flash) { flash.id != id })
      #(Model(..model, flashes:), effect.none())
    }
    FlashTimeoutExpired ->
      case model.flashes {
        [] -> #(model, effect.none())
        [_, ..flashes] -> {
          #(Model(..model, flashes:), effect.none())
        }
      }
  }
}

fn add_flash(model: Model, severity, message) {
  let flash = Flash(id: model.next_id, severity:, message:)
  let flashes = list.append(model.flashes, [flash])
  let model = Model(flashes:, next_id: model.next_id + 1)
  #(model, delay(5000, FlashTimeoutExpired))
}

fn delay(milliseconds: Int, msg: msg) -> Effect(msg) {
  use dispatch <- effect.from
  use <- set_timeout(milliseconds)
  dispatch(msg)
}

@external(javascript, "./example_ffi.mjs", "set_timeout")
fn set_timeout(timeout: Int, callback: fn() -> a) -> Nil

// VIEW ------------------------------------------------------------------------

fn view(model: Model) {
  html.div([], [
    html.h3([], [html.text("Lustre Portal Example")]),
    html.div([attribute.class("actions")], [
      view_button("Save", Success, UserClickedSave),
      view_button("Reset", Info, UserClickedReset),
      view_button("Cancel", Warning, UserClickedCancel),
      view_button("Delete", Error, UserClickedDelete),
    ]),
    portal.to(matching: "body", with: [], teleport: [
      view_flashes(model.flashes),
    ]),
  ])
}

fn view_button(
  label: String,
  severity_: Severity,
  on_click: msg,
) -> Element(msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class("btn"),
      severity(severity_),
      event.on_click(on_click),
    ],
    [html.text(label)],
  )
}

fn view_flashes(flashes: List(Flash)) -> Element(Msg) {
  keyed.div([attribute.class("flash-container")], {
    use flash <- list.map(flashes)

    let html =
      html.div([attribute.class("flash"), severity(flash.severity)], [
        html.p([], [html.text(flash.message)]),
        html.button([event.on_click(UserClickedAck(flash.id))], [
          html.text("Acknowledged"),
        ]),
      ])

    #(int.to_string(flash.id), html)
  })
}

fn severity(severity: Severity) -> Attribute(msg) {
  let severity_class = case severity {
    Warning -> "warning"
    Error -> "error"
    Info -> "info"
    Success -> "success"
  }
  attribute.class(severity_class)
}
