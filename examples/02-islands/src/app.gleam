// IMPORTS ---------------------------------------------------------------------

import lustre
import lustre/element
import lustre/element/html
import lustre/portal

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app =
    lustre.element(
      element.fragment([
        html.div([], [
          html.p([], [html.text("Main content rendered by lustre")]),
        ]),
        // We can portal part of our view to a container in the sidebar to have
        // two separate islands of content both controlled by the same Lustre
        // app.
        portal.to("#sidebar", [], [
          html.p([], [html.text("Sidebar content rendered by lustre")]),
        ]),
      ]),
    )

  let assert Ok(_) = portal.register()
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
