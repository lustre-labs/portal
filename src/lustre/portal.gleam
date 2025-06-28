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
          // see https://github.com/gleam-lang/gleam/issues/4726
          let _ = do_register(component_name)
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
    "var r=class{withFields(e){let t=Object.keys(this).map(u=>u in e?e[u]:this[u]);return new this.constructor(...t)}};var A=class n extends r{static isResult(e){return e instanceof n}},i=class extends A{constructor(e){super(),this[0]=e}isOk(){return!0}},s=class extends A{constructor(e){super(),this[0]=e}isOk(){return!1}};var ot=5,X=Math.pow(2,ot),Cr=X-1,Ar=X/2,Tr=X/4;var $e=[\" \",\"	\",`\\n`,\"\\v\",\"\\f\",\"\\r\",\"\\x85\",\"\\u2028\",\"\\u2029\"].join(\"\"),Xr=new RegExp(`^[${$e}]*`),Jr=new RegExp(`[${$e}]*$`);var B=()=>globalThis?.document;var Bt=!!globalThis.HTMLElement?.prototype?.moveBefore;var ir=Symbol(\"lustre\");var Ke=n=>{for(;n;){if(n[ir])return!0;n=n.parentNode}return!1};var S=()=>!!B(),le=n=>S()&&customElements.get(n);var I=class extends r{constructor(e){super(),this.name=e}};var C=class extends r{};function Qe(n){customElements.define(n,de)}var pe=Symbol(\"portals\"),de=class extends HTMLElement{static observedAttributes=[\"to\"];#e=null;#t=[];constructor(){super(),this.#e=this.#s(),this.#t=[...super.childNodes]}connectedCallback(){this.style.display=\"none\",this.#i(this.#o())}disconnectedCallback(){this.#n()}connectedMoveCallback(){if(!this.#e)return;let e=this.#e[pe]??=[],t=Ze(e,this),u=Ye(e,this);if(t!==u){let c=e[u+1]?.firstChild??null;for(let x of this.#t)this.#e.moveBefore(x,c)}}attributeChangedCallback(e,t,u){if(e===\"to\"&&t!==u){let c=this.#s();this.#e!==c&&this.#l(c)}}get to(){return super.getAttribute(\"to\")}set to(e){super.setAttribute(\"to\",e)}#n(){return this.#e&&Ze(this.#e[pe],this),this.#o()}#i(e){if(!this.isConnected||!this.#e)return;let t=this.#e[pe]??=[],u=Ye(t,this),c=t[u+1]?.firstChild??null;this.#e.insertBefore(e,c)}#l(e){if(this.isConnected){let t=this.#n();this.#e=e,this.#i(t)}else this.#e=e}#s(){let e=this.to??\"\",t=null;try{t=document.querySelector(e)}catch{return this.#r(et)}return t?Ke(t)?this.#r(rt):t:this.#r(tt)}#r(e){return this.dispatchEvent(new CustomEvent(\"invalid\",{detail:e})),null}#o(){let e=document.createDocumentFragment();for(let t of this.#t)e.appendChild(t);return e}#u(e,t,u){let c=e.nodeType===Node.DOCUMENT_FRAGMENT_NODE?[...e.childNodes]:[e],x=this.#t.indexOf(e),it=u(e,t??this.lastChild?.nextSibling??null);x>=0&&this.#t.splice(x,1);let st=t?this.#t.indexOf(t):this.#t.length;return this.#t.splice(st,0,...c),it}get childNodes(){return this.#t}get firstChild(){return this.#t[0]}get lastChild(){return this.#t[this.#t.length-1]}moveBefore(e,t){return this.#u(e,t,(u,c)=>this.#e?.moveBefore(u,c))}insertBefore(e,t){return this.#u(e,t,(u,c)=>this.#e?.insertBefore(u,c))}removeChild(e){let t=this.#t.indexOf(e);this.#e?.removeChild(e),this.#t.splice(t,1)}};function yr(n,e){let t=0,u=n.length-1;for(;t<=u;){let c=(t+u)/2|0,x=e.compareDocumentPosition(n[c]);if(x&Node.DOCUMENT_POSITION_FOLLOWING)u=c-1;else if(x&Node.DOCUMENT_POSITION_PRECEDING)t=c+1;else return c}return t}function Ye(n,e){let t=yr(n,e);return n[t]!==e&&n.splice(t,0,e),t}function Ze(n,e){let t=n.indexOf(e);return t>=0&&n.splice(t,1),t}var _e=\"lustre-portal\";function nt(){if(S()){if(le(_e))return new s(new I(_e));{let t=Qe(_e);return new i(void 0)}}else return new s(new C)}var et=\"invalid-selector\",tt=\"target-not-found\",rt=\"target-inside-lustre\";nt();",
  )
}
