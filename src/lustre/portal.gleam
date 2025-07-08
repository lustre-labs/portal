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
  TargetIsCrossOriginIframe
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

  case tag {
    _ if tag == missing_selector_tag -> decode.success(MissingSelector)

    _ if tag == invalid_selector_tag -> {
      use selector <- decode.field("selector", decode.string)
      decode.success(InvalidSelector(selector:))
    }

    _ if tag == target_not_found_tag -> {
      use selector <- decode.field("selector", decode.string)
      decode.success(TargetNotFound(selector:))
    }

    _ if tag == target_inside_lustre_tag -> {
      use selector <- decode.field("selector", decode.string)
      decode.success(TargetInsideLustre(selector:))
    }

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
/// > include the pre-built JavaScript bundle found in `priv/static/lustre-porta.min.mjs`
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
    "function L(n,e,t){return n?e:t()}var r=class{withFields(e){let t=Object.keys(this).map(o=>o in e?e[o]:this[o]);return new this.constructor(...t)}};var A=class n extends r{static isResult(e){return e instanceof n}},i=class extends A{constructor(e){super(),this[0]=e}isOk(){return!0}},s=class extends A{constructor(e){super(),this[0]=e}isOk(){return!1}};var at=5,X=Math.pow(2,at),Tr=X-1,Br=X/2,Or=X/4;var ge=[\" \",\"	\",`\\n`,\"\\v\",\"\\f\",\"\\r\",\"\\x85\",\"\\u2028\",\"\\u2029\"].join(\"\"),Kr=new RegExp(`^[${ge}]*`),Zr=new RegExp(`[${ge}]*$`);var B=()=>globalThis?.document;var Nt=!!globalThis.HTMLElement?.prototype?.moveBefore;var or=Symbol(\"lustre\");var Xe=n=>{for(;n;){if(n[or])return!0;n=n.parentNode}return!1};var S=()=>!!B(),ce=n=>S()&&customElements.get(n);var I=class extends r{constructor(e){super(),this.name=e}};var C=class extends r{};function tt(n){customElements.define(n,me)}var _e=Symbol(\"portals\"),me=class extends HTMLElement{static observedAttributes=[\"target\",\"root\"];#e=null;#t=[];constructor(){super(),this.#e=this.#s(),this.#t=[...super.childNodes]}connectedCallback(){this.style.display=\"none\",this.#i(this.#o())}disconnectedCallback(){this.#n()}connectedMoveCallback(){if(!this.#e)return;let e=this.#e[_e]??=[],t=et(e,this),o=Qe(e,this);if(t!==o){let c=e[o+1]?.firstChild??null;for(let x of this.#t)this.#e.moveBefore(x,c)}}attributeChangedCallback(e,t,o){if(t===o)return;let c=this.#s();this.#e!==c&&this.#l(c)}get target(){return super.getAttribute(\"target\")}set target(e){super.setAttribute(\"target\",typeof e==\"string\"?e:\"\")}get root(){return super.getAttribute(\"root\")}set root(e){super.setAttribute(\"root\",e!==\"relative\"&&e!==\"document\"?\"document\":e)}#n(){return this.#e&&et(this.#e[_e],this),this.#o()}#i(e){if(!this.isConnected||!this.#e)return;let t=this.#e[_e]??=[],o=Qe(t,this),c=t[o+1]?.firstChild??null;this.#e.insertBefore(e,c)}#l(e){if(this.isConnected){let t=this.#n();this.#e=e,this.#i(t)}else this.#e=e}#s(){if(!this.target)return this.#r(rt,\"The target attribute cannot be empty.\");let e=this.root===\"relative\"?this.getRootNode():document,t=null;try{t=e.querySelector(this.target)}catch{return this.#r(nt,`The target \"${this.target}\" is not a valid query selector.`,{selector:this.target})}return t?Xe(t)?this.#r(st,`The element matching \"${this.target}\" must not be owned by Lustre.`):t:this.#r(it,`No element matching \"${this.target}\".`,{selector:this.target})}#r(e,t=\"\",o={}){return this.dispatchEvent(new CustomEvent(\"error\",{detail:{tag:e,message:t,...o}})),null}#o(){let e=document.createDocumentFragment();for(let t of this.#t)e.appendChild(t);return e}#u(e,t,o){let c=e.nodeType===Node.DOCUMENT_FRAGMENT_NODE?[...e.childNodes]:[e],x=this.#t.indexOf(e),ut=o(e,t??this.lastChild?.nextSibling??null);x>=0&&this.#t.splice(x,1);let lt=t?this.#t.indexOf(t):this.#t.length;return this.#t.splice(lt,0,...c),ut}get childNodes(){return this.#t}get firstChild(){return this.#t[0]}get lastChild(){return this.#t[this.#t.length-1]}moveBefore(e,t){return this.#u(e,t,(o,c)=>{this.#e?.moveBefore(o,c)})}insertBefore(e,t){return this.#u(e,t,(o,c)=>{this.#e?.insertBefore(o,c)})}removeChild(e){let t=this.#t.indexOf(e);this.#e?.removeChild(e),this.#t.splice(t,1)}};function vr(n,e){let t=0,o=n.length-1;for(;t<=o;){let c=(t+o)/2|0,x=e.compareDocumentPosition(n[c]);if(x&Node.DOCUMENT_POSITION_FOLLOWING)o=c-1;else if(x&Node.DOCUMENT_POSITION_PRECEDING)t=c+1;else return c}return t}function Qe(n,e){let t=vr(n,e);return n[t]!==e&&n.splice(t,0,e),t}function et(n,e){let t=n.indexOf(e);return t>=0&&n.splice(t,1),t}var he=\"lustre-portal\";function ot(){return L(!S(),new s(new C),()=>L(ce(he),new s(new I(he)),()=>new i(tt(he))))}var rt=\"missing-selector\",nt=\"invalid-selector\",it=\"target-not-found\",st=\"target-inside-lustre\";ot();",
  )
}
