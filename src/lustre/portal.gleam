import lustre
import lustre/attribute
import lustre/element

/// Register the `lustre-portal` Web Component.
///
/// This lets you use portals in your Lustre browser app. You should call this
/// function once early in your main entry point.
/// 
/// **Note:** This function is only meaningful when running in the browser and
/// will produce a NotABrowser error if called anywhere else. 
pub fn register() -> Result(Nil, lustre.Error) {
  case lustre.is_browser() {
    True -> {
      do_register()
      Ok(Nil)
    }
    False -> Error(lustre.NotABrowser)
  }
}

@external(javascript, "../lustre-portal.ffi.mjs", "register")
fn do_register() -> Nil

/// Render a portal, teleporting all given attributes and children to another
/// element in the DOM, outside of lustres control.
///
/// The `selector` can be any valid CSS selector. The first found matching
/// element will be used as the target.
///
/// **Note:** Please see the [README](../index.html) for additional usage notes.
pub fn portal(
  to selector: String,
  attributes attributes: List(attribute.Attribute(msg)),
  children children: List(element.Element(msg)),
) -> element.Element(msg) {
  element.element(
    "lustre-portal",
    [attribute.attribute("to", selector), ..attributes],
    children,
  )
}
