//// A portal changes the physical placaement of its children in the DOM, while
//// keeping them logically inside your Lustre app. This makes it possible to
//// implement things like modals and tooltips that typically need to be rendered
//// outside of the app root to ensure they properly overlay other elements.
////

// IMPORTS ---------------------------------------------------------------------

import gleam/bool
import gleam/dynamic/decode.{type Decoder}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/server_component

// CONSTANTS -------------------------------------------------------------------

/// The name of the `<lustre-portal>` custom element. You might use this if you're
/// rendering the element yourself or if you want to check if the component has
/// already been registered.
///
pub const name = "lustre-portal"

// TYPES -----------------------------------------------------------------------

/// It's possible for the portal to fail when teleporting its children for a
/// number of reasons. If that happens, the element will emit an `"error"` event
/// with details on what went wrong.
///
pub type Error {
  /// The portal's `"target"` attribute was missing or empty.
  ///
  MissingSelector

  /// The portal's `"target"` attribute was not a valid CSS selector.
  ///
  InvalidSelector(selector: String)

  /// No element could be found matching the portal's `"target"` attribute.
  ///
  TargetNotFound(selector: String)

  /// An element was found matching the portal's `"target"` attribute, but it
  /// is "owned" by Lustre. Teleporting this portal's children to it would conflict
  /// with Lustre's virtual DOM and cause unexpected behaviour.
  ///
  TargetInsideLustre(selector: String)

  /// The portal's `"target"` attribute points to an iframe but that iframe's
  /// source is from a different origin. The portal can only teleport children
  /// into an iframe when the iframe is from the same origin as your Lustre app.
  ///
  TargetIsCrossOriginIframe(selector: String)

  /// The portal's `"target"` attribute points to another portal element.
  /// This might lead to elements being teleported back and forth between multiple
  /// portals, causing runtime errors and unexpected behaviour.
  TargetIsPortal(selector: String)
}

/// The root element the portal will use to find the target element. This is used
/// with the [`root`](#root) attribute to better control where the portal's children
/// will be teleported to.
///
pub type Root {
  /// Use the `document` root, meaning the portal will use `document.querySelector`
  /// to find the target element. This is the default behaviour and in most cases
  /// is what you want.
  ///
  Document

  /// Use the nearest root node in the DOM as the basis for the query. This is
  /// found by calling [`getRootNode()`](https://developer.mozilla.org/en-US/docs/Web/API/Node/getRootNode)
  /// on the portal element itself, and is useful in cases where the portal is
  /// rendered inside another Lustre component.
  ///
  Relative
}

@internal
pub const missing_selector_tag = "missing-selector"

@internal
pub const invalid_selector_tag = "invalid-selector"

@internal
pub const target_not_found_tag = "target-not-found"

@internal
pub const target_inside_lustre_tag = "target-inside-lustre"

@internal
pub const target_is_cross_origin_iframe_tag = "target-is-cross-origin-iframe"

@internal
pub const target_is_portal_tag = "target-is-portal"

// ATTRIBUTES ------------------------------------------------------------------

/// A valid CSS selector used to locate the target element the portal's children
/// should be teleported to. If it is missing or invalid the `<lustre-portal`>
/// element will emit an `"error"` event that can be handled with the
/// [`on_error`](#on_error) listener.
///
/// > **Note**: the _first_ element that matches the selector will be used as
/// > the portal's target. If you need to match a different element, make sure
/// > the selector is specific enough to only match the element you want.
///
fn target(selector: String) -> Attribute(msg) {
  attribute.attribute("target", selector)
}

/// The `"root"` attribute determines how the portal will find the target element.
/// By default, the portal will use the `Document` root, meaning queries for the
/// target element will use `document.querySelector`.
///
/// Alternatively, you can set the root to `Relative`, which will cause the portal
/// to use the nearest root node in the DOM as the basis for the query. This can
/// be useful if you're rendering the portal inside another Lustre component and
/// want to ensure the portal's children don't escape the component's shadow DOM.
///
pub fn root(root: Root) -> Attribute(msg) {
  attribute.attribute("root", case root {
    Document -> "document"
    Relative -> "relative"
  })
}

/// A portal could fail for a number of reasons. When it does, it will emit an
/// `"error"` event with some information on what went wrong. You might use this
/// event listener to log errors in something like Sentry, or recover your ui if
/// something important could not be teleported.
///
pub fn on_error(handler: fn(Error) -> msg) -> Attribute(msg) {
  let handle_error =
    decode.at(["detail", "tag"], error_decoder())
    |> decode.map(handler)

  event.on("error", handle_error)
  |> server_component.include(["detail.tag"])
  |> server_component.include(["detail.selector"])
  |> server_component.include(["detail.message"])
}

/// Decode the `detail` of a portal's `"error"` event. You might use this decoder
/// if you're writing your own event handler instead of the [provided one](#on_error).
///
pub fn error_decoder() -> Decoder(Error) {
  use tag <- decode.field("tag", decode.string)
  use selector <- decode.field("selector", decode.string)

  case tag {
    _ if tag == missing_selector_tag -> decode.success(MissingSelector)

    _ if tag == invalid_selector_tag ->
      decode.success(InvalidSelector(selector:))

    _ if tag == target_not_found_tag ->
      decode.success(TargetNotFound(selector:))

    _ if tag == target_inside_lustre_tag ->
      decode.success(TargetInsideLustre(selector:))

    _ if tag == target_is_cross_origin_iframe_tag ->
      decode.success(TargetIsCrossOriginIframe(selector))

    _ if tag == target_is_portal_tag -> decode.success(TargetIsPortal(selector))

    _ -> decode.failure(MissingSelector, "portal.Error")
  }
}

// ELEMENTS --------------------------------------------------------------------

/// Register the `<lustre-portal>` component. If you have not included the
/// standalone JavaScript bundle in your HTML document, it's typical to call this
/// function before you start your Lustre application.
///
/// > **Note**: this function is only meaningful when running in the browser and
/// > will produce a `NotABrowser` error if called on the server. If you want to
/// > use portals in server components or in server-rendered HTML, you should
/// > include the pre-built JavaScript bundle found in `priv/static/lustre-portal.min.mjs`
/// > or embed the inline script using the [`script`](#script) function.
///
pub fn register() -> Result(Nil, lustre.Error) {
  use <- bool.guard(!lustre.is_browser(), Error(lustre.NotABrowser))
  use <- bool.guard(lustre.is_registered(name), {
    Error(lustre.ComponentAlreadyRegistered(name))
  })

  Ok(do_register(name))
}

@external(javascript, "./portal.ffi.mjs", "register")
fn do_register(name: String) -> Nil

/// Render a portal, teleporting all children to another element in the DOM
/// outside of Lustre's control. The target must be a valid CSS selector, and the
/// first element matching that selector will be used as the target to teleport
/// the children to.
///
pub fn to(
  target selector: String,
  with attributes: List(Attribute(msg)),
  teleport children: List(Element(msg)),
) -> Element(msg) {
  element.element(name, [target(selector), ..attributes], children)
}

/// Inline the portal component script as a `<script>` tag. Where possible you
/// should prefer using `register` in an SPA, or serving the pre-built client
/// runtime from lustre_portal's `priv/static` directory when using
/// server-components.
///
/// This inline script can be useful for development or scenarios where you don't
/// control the HTML document.
///
pub fn script() -> Element(msg) {
  html.script(
    [attribute.type_("module")],
    // <<INJECT SCRIPT>>
    "function q(a,e,n){return a?e:n()}var t=class{withFields(e){let n=Object.keys(this).map(f=>f in e?e[f]:this[f]);return new this.constructor(...n)}};var C=class a extends t{static isResult(e){return e instanceof a}},r=class extends C{constructor(e){super(),this[0]=e}isOk(){return!0}},i=class extends C{constructor(e){super(),this[0]=e}isOk(){return!1}};var at=5,J=Math.pow(2,at),jr=J-1,Er=J/2,Sr=J/4;var ye=[\" \",\"	\",`\\n`,\"\\v\",\"\\f\",\"\\r\",\"\\x85\",\"\\u2028\",\"\\u2029\"].join(\"\"),Gr=new RegExp(`^[${ye}]*`),Wr=new RegExp(`[${ye}]*$`);var B=()=>globalThis?.document;var Bt=!!globalThis.HTMLElement?.prototype?.moveBefore;var rr=Symbol(\"lustre\");var Ke=a=>!!a[rr];var j=()=>!!B(),ce=a=>j()&&customElements.get(a);var I=class extends t{constructor(e){super(),this.name=e}};var E=class extends t{};function Ze(a){customElements.define(a,_e)}var _e=class a extends HTMLElement{static observedAttributes=[\"target\",\"root\"];#t=null;#e=[];constructor(){super(),this.#t=this.#i(),this.#e=[...super.childNodes]}connectedCallback(){this.style.display=\"none\",this.#n()}disconnectedCallback(){this.#n()}connectedMoveCallback(){}attributeChangedCallback(e,n,f){n!==f&&(this.targetElement=this.#i())}get targetElement(){return this.#t}set targetElement(e){e!==this.#t&&(this.#t=this.#s(e),this.#n())}get target(){return super.getAttribute(\"target\")??\"\"}set target(e){e instanceof HTMLElement?this.targetElement=e:super.setAttribute(\"target\",typeof e==\"string\"?e:\"\")}get root(){return super.getAttribute(\"root\")}set root(e){super.setAttribute(\"root\",e!==\"relative\"&&e!==\"document\"?\"document\":e)}#n(){let e=document.createDocumentFragment();for(let n of this.#e)e.appendChild(n);this.isConnected&&this.#t?.insertBefore(e,null)}#i(){if(!this.target)return this.#r(et,\"the target attribute cannot be empty.\");let e=this.root===\"relative\"?this.getrootnode():document,n=null;try{n=e.queryselector(this.target)}catch{return this.#r(tt,`the target \"${this.target}\" is not a valid query selector.`)}return this.#s(n)}#s(e){if(!e)return this.#r(rt,`no element matching \"${this.target}\".`);if(e instanceof htmliframeelement){let n=e.contentdocument?.body;return n||this.#r(it,\"only same-origin iframes can be targeted.\")}return e instanceof a?this.#r(st,`the element matching \"${this.target}\" must not be another portal.`):ke(e)?this.#r(nt,`the element matching \"${this.target}\" must not be owned by lustre.`):e}#r(e,n=\"\",f={}){return this.dispatchEvent(new CustomEvent(\"error\",{detail:{tag:e,message:n,selector:this.target,...f}})),null}#o(e,n,f){let S=e.nodeType===Node.DOCUMENT_FRAGMENT_NODE?[...e.childNodes]:[e],he=this.#e.indexOf(e),ut=f(e,n??this.lastChild?.nextSibling??null);he>=0&&this.#e.splice(he,1);let lt=n?this.#e.indexOf(n):this.#e.length;return this.#e.splice(lt,0,...S),ut}get childNodes(){return this.#e}get firstChild(){return this.#e[0]}get lastChild(){return this.#e[this.#e.length-1]}moveBefore(e,n){return this.#o(e,n,(f,S)=>{this.#t?.moveBefore(f,S)})}insertBefore(e,n){return this.#o(e,n,(f,S)=>{this.#t?.insertBefore(f,S)})}removeChild(e){let n=this.#e.indexOf(e);this.#t?.removeChild(e),this.#e.splice(n,1)}};var me=\"lustre-portal\";function ot(){return q(!j(),new i(new E),()=>q(ce(me),new i(new I(me)),()=>new r(Ze(me))))}var et=\"missing-selector\",tt=\"invalid-selector\",rt=\"target-not-found\",nt=\"target-inside-lustre\",it=\"target-is-cross-origin-iframe\",st=\"target-is-portal\";ot();",
  )
}
