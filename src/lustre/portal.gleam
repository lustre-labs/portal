import gleam/dynamic/decode
import lustre.{type Error}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/server_component

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
  with attributes: List(Attribute(msg)),
  teleport elements: List(Element(msg)),
) -> Element(msg) {
  element.element(
    component_name,
    [attribute.attribute("to", selector), ..attributes],
    elements,
  )
}

pub type InvalidReason {
  /// Emitted when the selector passed is missing or not valid.
  InvalidSelector
  /// Emitted when the selector does not match an element in the document.
  TargetNotFound
  /// Emitted whe the selector does match an element in the document, but that
  /// element is inside of another lustre app.
  ///
  /// This is intentionally not allowed to prevent 2 lustre apps updating the
  /// same node from 2 different places. It is recommended to use standard
  /// Gleam techniques (passing/returning data from functions) and re-structure
  /// your app in such a way that using a portal is no longer necessary.
  TargetInsideLustre
}

fn invalid_reason_decoder() -> decode.Decoder(InvalidReason) {
  use variant <- decode.then(decode.string)
  case variant {
    _ if variant == invalid_selector_tag -> decode.success(InvalidSelector)
    _ if variant == target_not_found_tag -> decode.success(TargetNotFound)
    _ if variant == target_inside_lustre_tag ->
      decode.success(TargetInsideLustre)
    _ -> decode.failure(InvalidSelector, "InvalidReason")
  }
}

@internal
pub const invalid_selector_tag = "invalid-selector"

@internal
pub const target_not_found_tag = "target-not-found"

@internal
pub const target_inside_lustre_tag = "target-inside-lustre"

/// An optional event that is fired whenever the selector is changed but no
/// element could be found.
///
/// This is rarely needed but might be useful for debugging.
pub fn on_invalid_target(handle: fn(InvalidReason) -> msg) -> Attribute(msg) {
  // event.on("invalid", decode.success(msg))
  let decoder = {
    use reason <- decode.field("detail", invalid_reason_decoder())
    decode.success(handle(reason))
  }

  event.on("invalid", decoder)
  |> server_component.include(["detail"])
}

/// Inline the portal component script as a `<script>` tag. Where possible
/// you should prefer using `register` in an SPA, or serving the pre-built client
/// runtime from lustre_portal's `priv/static` directory when using server-components.
///
/// This inline script can be useful for development or scenarios
/// where you don't control the HTML document.
///
pub fn script() -> Element(msg) {
  html.script(
    [attribute.type_("module")],
    // <<INJECT SCRIPT>>
    "var r=class{withFields(e){let t=Object.keys(this).map(o=>o in e?e[o]:this[o]);return new this.constructor(...t)}};var S=class n extends r{static isResult(e){return e instanceof n}},i=class extends S{constructor(e){super(),this[0]=e}isOk(){return!0}},s=class extends S{constructor(e){super(),this[0]=e}isOk(){return!1}};var Qe=5,H=Math.pow(2,Qe),cr=H-1,ar=H/2,fr=H/4;var we=[\" \",\"	\",`\\n`,\"\\v\",\"\\f\",\"\\r\",\"\\x85\",\"\\u2028\",\"\\u2029\"].join(\"\"),si=new RegExp(`^[${we}]*`),oi=new RegExp(`[${we}]*$`);var B=()=>globalThis?.document;var yt=!!globalThis.HTMLElement?.prototype?.moveBefore;var Wt=Symbol(\"lustre\");var De=n=>{for(;n;){if(n[Wt])return!0;n=n.parentNode}return!1};var j=()=>!!B(),re=n=>j()&&customElements.get(n);var N=class extends r{constructor(e){super(),this.name=e}};var E=class extends r{};function We(n){customElements.define(n,oe)}var se=Symbol(\"portals\"),oe=class extends HTMLElement{static observedAttributes=[\"to\"];#e=null;#t=[];constructor(){super(),this.#e=this.#i(),this.#t=[...super.childNodes]}connectedCallback(){this.style.display=\"none\",this.#n(this.#s())}disconnectedCallback(){this.#r()}connectedMoveCallback(){if(!this.#e)return;let e=this.#e[se]??=[],t=He(e,this),o=Ge(e,this);if(t!==o){let a=e[o+1]?.firstChild??null;for(let x of this.#t)this.#e.moveBefore(x,a)}}attributeChangedCallback(e,t,o){if(e===\"to\"&&t!==o){let a=this.#i();this.#e!==a&&this.#u(a)}}get to(){return super.getAttribute(\"to\")}set to(e){super.setAttribute(\"to\",e)}#r(){return this.#e&&He(this.#e[se],this),this.#s()}#n(e){if(!this.isConnected||!this.#e)return;let t=this.#e[se]??=[],o=Ge(t,this),a=t[o+1]?.firstChild??null;this.#e.insertBefore(e,a)}#u(e){if(this.isConnected){let t=this.#r();this.#e=e,this.#n(t)}else this.#e=e}#i(){let e=this.to;if(!e)return null;let t=document.querySelector(e);return t?De(t)?(console.warn(\"%clustre-portal%c Target of portal %o is not valid. Portal targets can not be inside a Lustre application.\",\"background-color: #ffaff3; color: #151515; border-radius: 3px; padding: 0 3px;\",\"\",this),null):t:null}#s(){let e=document.createDocumentFragment();for(let t of this.#t)e.appendChild(t);return e}#o(e,t,o){let a=e.nodeType===Node.DOCUMENT_FRAGMENT_NODE?[...e.childNodes]:[e],x=this.#t.indexOf(e),Je=o(e,t??this.lastChild?.nextSibling??null);x>=0&&this.#t.splice(x,1);let Xe=t?this.#t.indexOf(t):this.#t.length;return this.#t.splice(Xe,0,...a),Je}get childNodes(){return this.#t}get firstChild(){return this.#t[0]}get lastChild(){return this.#t[this.#t.length-1]}moveBefore(e,t){return this.#o(e,t,(o,a)=>this.#e?.moveBefore(o,a))}insertBefore(e,t){return this.#o(e,t,(o,a)=>this.#e?.insertBefore(o,a))}removeChild(e){let t=this.#t.indexOf(e);this.#e?.removeChild(e),this.#t.splice(t,1)}};function tr(n,e){let t=0,o=n.length-1;for(;t<=o;){let a=(t+o)/2|0,x=e.compareDocumentPosition(n[a]);if(x&Node.DOCUMENT_POSITION_FOLLOWING)o=a-1;else if(x&Node.DOCUMENT_POSITION_PRECEDING)t=a+1;else return a}return t}function Ge(n,e){let t=tr(n,e);return n[t]!==e&&n.splice(t,0,e),t}function He(n,e){let t=n.indexOf(e);return t>=0&&n.splice(t,1),t}var ue=\"lustre-portal\";function Ye(){return j()?re(ue)?new s(new N(ue)):(We(ue),new i(void 0)):new s(new E)}Ye();",
  )
}
