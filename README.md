<h1 align="center">Lustre Portal</h1>

<div align="center">
    Teleport elements anywhere in the DOM!
</div>

<br />

<div align="center">
  <a href="https://hex.pm/packages/lustre_portal">
      <img src="https://img.shields.io/hexpm/v/lustre_portal"
      alt="Available on Hex" />
  </a>
</div>

<div align="center">
  <h3>
    <a href="https://hexdocs.pm/lustre">
      Lustre
    </a>
    <span> | </span>
    <a href="https://discord.gg/Fm8Pwmy">
      Discord
    </a>
  </h3>
</div>

<div align="center">
  <sub>Built with ❤︎ by
  <a href="https://bsky.app/profile/joshi.monster">Yoshi~</a> and
  <a href="https://bsky.app/profile/hayleigh.dev">Hayleigh Thompson</a>
</div>

---

## Features

`lustre_portal` is a web component that allows you to "teleport" a part of an
app's view into a DOM node that exists outside of the DOM hierarchy controlled
by Lustre.

- Select any element using standard CSS selectors.

- Multiple portals can target the same element.

- Support for portalled content inside a Web Component's shadow DOM or inside
  an iframe's document.

- A **standalone Web Component bundle** that can be used in server-rendered HTML
  pages


## Installation

`lustre_portal` is published on [Hex](https://hex.pm/packages/lustre_portal)! You
can add it to your Gleam projects from the command line:

```sh
gleam add lustre lustre_portal
```

It is also possible to use `lustre_portal` in static HTML pages without Lustre or
Gleam by including the standalone Web Component bundle found in `priv/static` in
your HTML.

> **Note**: `lustre_portal` is not currently intended to be used by _other frameworks_
> like React or Vue. Teleporting may behave unpredictably or not at all in these
> cases. If you're interested in using `lustre_portal` with another framework,
> please [open an issue](https://github.com/lustre-labs/portal/issues/new) so we
> can better understand your use case and see if we can help!

## Examples

Below are some examples of the most-common scenarios where `lustre_portal` can
come in handy:

- [`01-toast`](https://github.com/lustre-labs/portal/tree/main/examples/01-toast)
  shows how to render toast messages that always appear above any element's in
  your app.

- [`02-islands`](https://github.com/lustre-labs/portal/tree/main/examples/02-islands)
  demonstrates how `lustre_portal` can be used to have multiple islands of dynamic
  content controlled by a single Lustre application.

- [`03-map-tooltip`](https://github.com/lustre-labs/portal/tree/main/examples/03-map-tooltip)
  renders Lustre elements inside of a Leaflet map tooltip, showcasing how `lustre_portal`
  can be used to insert Lustre-controlled content into a third-party library's
  DOM structure.

<!-- - [`04-server-side-rendering`](#) shows how to use `lustre_portal` without a client
  Lustre application. -->
