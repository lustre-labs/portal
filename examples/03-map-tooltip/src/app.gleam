// IMPORTS ---------------------------------------------------------------------

import gleam/float
import gleam/set.{type Set}
import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
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
  Loading
  Ready(map: Map, markers: Set(#(Float, Float)))
}

type Map

fn init(_) {
  let model = Loading
  let effect = setup_map()

  #(model, effect)
}

/// This effect mounts the leaflet.js map onto a Lustre element we render.
///
fn setup_map() {
  use dispatch, _ <- effect.before_paint
  let map = do_setup_map("#map")

  dispatch(MapMountedToDom(map:))
}

@external(javascript, "./leaflet.ffi.mjs", "setup_map")
fn do_setup_map(selector: String) -> Map

// UPDATE ----------------------------------------------------------------------

type Msg {
  MapMountedToDom(map: Map)
  MapMarkerReady(lat: Float, lon: Float)
}

fn update(model: Model, msg: Msg) {
  case model, msg {
    Loading, MapMountedToDom(map:) -> #(
      Ready(map:, markers: set.new()),
      add_marker(map, 50.8477, 4.3572),
    )

    Ready(map:, markers:), MapMarkerReady(lat:, lon:) -> {
      let markers = set.insert(markers, #(lat, lon))

      #(Ready(map:, markers:), effect.none())
    }

    Loading, _ | Ready(..), _ -> #(model, effect.none())
  }
}

/// This effect imperatively creates a new `<div>` element in the DOM and gives
/// it to leaflet.js to render a marker on the map. We'll then portal content
/// from our Lustre app into that container!
fn add_marker(map: Map, lat: Float, lon: Float) {
  use dispatch, _ <- effect.before_paint

  do_add_marker(map, lat, lon)
  dispatch(MapMarkerReady(lat:, lon:))
}

@external(javascript, "./leaflet.ffi.mjs", "add_marker")
fn do_add_marker(map: Map, lat: Float, lon: Float) -> Nil

// VIEW ------------------------------------------------------------------------

fn view(model: Model) {
  let map_container =
    // This is the container where leaflet.js will mount and render the map.
    // Lustre has no knowledge of the DOM structure inside this element, but
    // we can use portals to render content inside it.
    element.unsafe_raw_html(
      "",
      "div",
      [
        attribute.id("map"),
        attribute.class("rounded-md aspect-square w-[min(90vw,90vh)]"),
      ],
      "",
    )

  let markers = case model {
    Loading -> []
    Ready(..) -> {
      use markers, #(lat, lon) <- set.fold(model.markers, [])
      let key = float.to_string(lat) <> "-" <> float.to_string(lon)
      let marker = view_marker(lat, lon)

      [#(key, marker), ..markers]
    }
  }

  keyed.div([attribute.class("h-screen flex justify-center items-center")], [
    #("map", map_container),
    ..markers
  ])
}

fn view_marker(lat: Float, lon: Float) -> Element(msg) {
  let target =
    "[data-marker-id=\""
    <> float.to_string(lat)
    <> "-"
    <> float.to_string(lon)
    <> "\"]"

  let label =
    "Marker at " <> float.to_string(lat) <> ", " <> float.to_string(lon)

  portal.to(target, [], [html.p([], [html.text(label)])])
}
