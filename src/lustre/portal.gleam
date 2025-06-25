import lustre.{type Error}
import lustre/attribute
import lustre/element

const component_name = "lustre-portal"

/// Register the `lustre-portal` Web Component.
///
/// This lets you use portals in your Lustre browser app. You should call this
/// function once early in your main entry point.
/// 
/// **Note:** This function is only meaningful when running in the browser and
/// will produce a NotABrowser error if called anywhere else. 
pub fn register() -> Result(Nil, Error) {
  case lustre.is_browser() {
    True ->
      case lustre.is_registered(component_name) {
        False -> {
          do_register(component_name)
          Ok(Nil)
        }
        True -> Error(lustre.ComponentAlreadyRegistered(component_name))
      }
    False -> Error(lustre.NotABrowser)
  }
}

@external(javascript, "../lustre-portal.ffi.mjs", "register")
fn do_register(name: String) -> Nil

/// Render a portal, teleporting all children to another element in the DOM,
/// outside of lustres control.
///
/// The `selector` can be any valid CSS selector. The first found matching
/// element will be used as the target.
///
/// **Note:** Please see the [README](../index.html) for additional usage notes.
pub fn to(
  matching selector: String,
  teleport elements: List(element.Element(msg)),
) -> element.Element(msg) {
  element.element(
    "lustre-portal",
    [attribute.attribute("to", selector)],
    elements,
  )
}
