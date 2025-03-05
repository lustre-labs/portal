# lustre_portal

[![Package Version](https://img.shields.io/hexpm/v/lustre_portal)](https://hex.pm/packages/lustre_portal)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/lustre_portal/)

`lustre_portal` is a web component that allows you to "teleport" a part of an
app's view into a DOM node that exists outside of the DOM hierarchy controlled
by Lustre.

## Installation

```sh
gleam add lustre_portal@1
```

## Basic Usage

Sometimes a part of an app or of a component's view belongs to it logically, but
from a visual standpoint, it should be displayed somewhere else in the DOM,
outside of the hierarchy controlled by Lustre.

A common example of this is controlling elements inside of the body. Normally,
Lustre apps are mounted on a single element, so the body is not controlled by
Lustre directly. It can make sense to visually add elements to the body though,
for example to render full-screen modals or toasts that should be on top of all
other elements in the document. We want the code that renders these elements to
live locally in the part of the application where it makes logical sense, but
visually, we need to "move" the rendered elements outside of our app, to avoid
tricky issues with absolutely positioned elements.

Consider the following example:

```gleam
fn view(model) {
  html.div([], [
    html.h3("Lustre Portal Example"),
    view_flashes(model.flashes)
  ])
}

fn view_flashes(flashes) {
  html.div([attribute.class("flash-container")], {
    use flash <- list.map(model.flashes)
    let severity_class = case flash.severity {
      Warning -> "warning"
      Error -> "error"
      Info -> "info"
      Success -> "success"
    }
    
    html.div([attribute.class("flash"), attribute.class(severity_class)], [
      html.text(flash.message)
    ])
  })
}
```

with the following CSS:

```css
.flash-container {
  position: fixed;
  z-index: 999;
  bottom: 20%;
  right: 20%;
  width: 300px;
  margin-right: -150px;
}
.flash {
  margin-top: 15px;
  padding: 30px 15px;
  border-radius: 5px;
  width: 100%;
  color: white;
  
  &.warning {
    background-color: darkgoldenrod;
  }
  &.error {
    background-color: darkred;
  }
  &.info {
    background-color: darkblue;
  }
  &.success {
    background-color: darkgreen;
  }
}
```

We want to render a stack of flash / toast messages at the bottom-right corner
of the screen.

When keeping the `.flash-container` inside the DOM element controlled by Lustre,
there are a number of potential issues:

- `position: fixed` only places the element relative to the viewport when no
  ancestor element has `transform`, `perspective` or `filter` set.
- `z-index: 999` only constrains the z-index within the current stacking context,
  and when multiple elements have the same `z-index` value set, they are rendered
  in tree traversal order again.

`lustre_portal` makes it possible to avoid these issues by allowing us to break
out of the DOM structure, rendering our toast at the end of the body tag instead:

```gleam
import lustre/portal

pub fn main() {
  let assert Ok(_) = portal.register()
  // ...
}

pub fn view(model) {
  html.div([], [
    html.h3("Lustre Portal Example"),

    portal.portal(to: "body", attributes: [], children: [
      view_flashes(model.flashes)
    ])
  ])
}
```

The `to` target selector expects a CSS selector string. Here, we are essentially
telling Lustre to "render these elements inside the `body` tag".

The resulting HTML might look something like this:

```html
<body>
  <div id="app">
    <h3>Lustre Portal Example</h3>
    <lustre-portal to="body"></lustre-portal>
  </div>
  <div class="flash-container">
    <div class="flash success">
      Element successfully teleported!
    </div>
  </div>
</body>
```

Notice how the `.flash-container` is rendered outside of the `#app` div!

## Multiple Portals to the same target

When you have multiple portals targeting the same element, for example a toast
and a modal module both teleporting elements to the `body`, `luste_portal` tries
to preserve the order, such that the order of the teleported elements matches
the order of portals in the tree.

Given the following view:

```gleam
fn view() {
  html.div([], [
    portal.portal(to: "body", [], [html.div([], [text("A")])]),
    portal.portal(to: "body", [], [html.div([], [text("B")])])
  ])
}
```

The rendered result is guaranteed to be:

```html
<body>
  <!-- ... -->
  <div>A</div>
  <div>B</div>
</body>
```

## Portals with attributes

You can set attributes and event listeners on a portal like you would on any
other Lustre element. Like child elements, these will be added to the target
element instead.

Existing attributes on the target element will be overridden, and when multiple
portals define the same attribute, they may override each other in unpredictable
ways. `class` and `style` attributes are handled separately and are merged instead.

This can be used to add global event listeners and classes to the body tag:

```gleam
fn view() {
  html.div([], [
    portal.portal(
      to: "body",
      attributes: [attribute.class("light")],
      children: []
    )
  ])
}
```

will result in

```html
<body class="light">
  <!-- ... -->
</body>
```

**Note:** You can not use a portal to set properties on another element!

## Server-side rendering

`lustre_portal` is a browser-only Web Component, so server-side rendering is not
supported. When using SSR, you are usually in control of the entire document. It
is recommended to use other mechanisms or structure your code differently to
produce the desired markup.

