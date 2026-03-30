// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence;
  } else {
    return alternative();
  }
}

// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label) => label in fields ? fields[label] : this[label]
    );
    return new this.constructor(...properties);
  }
};
var Result = class _Result extends CustomType {
  static isResult(data2) {
    return data2 instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value) {
    super();
    this[0] = value;
  }
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  isOk() {
    return false;
  }
};

// build/dev/javascript/gleam_stdlib/dict.mjs
var bits = 5;
var mask = (1 << bits) - 1;

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var MIN_I32 = -(1 ** 31);
var MAX_I32 = 2 ** 31 - 1;
var U32 = 2 ** 32;
var MAX_SAFE = Number.MAX_SAFE_INTEGER;
var MIN_SAFE = Number.MIN_SAFE_INTEGER;

// build/dev/javascript/lustre/lustre/internals/constants.ffi.mjs
var SUPPORTS_MOVE_BEFORE = !!globalThis.HTMLElement?.prototype?.moveBefore;

// build/dev/javascript/lustre/lustre/vdom/reconciler.ffi.mjs
var meta = Symbol("lustre");
var isLustreNode = (node) => meta in node;

// build/dev/javascript/lustre/lustre/runtime/client/runtime.ffi.mjs
var is_browser = () => !!globalThis.document;
var is_registered = (name2) => is_browser() && customElements.get(name2);

// build/dev/javascript/lustre/lustre.mjs
var ComponentAlreadyRegistered = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
  }
};
var NotABrowser = class extends CustomType {
};

// build/dev/javascript/lustre_portal/lustre/portal.ffi.mjs
var symbol = Symbol("lustre-portal");
function register(name2) {
  customElements.define(
    name2,
    class Portal extends HTMLElement {
      // -- CUSTOM ELEMENT IMPLEMENTATION ------------------------------------------
      static observedAttributes = ["target", "root"];
      #targetElement = null;
      #childNodes = [];
      constructor() {
        super();
        this.#childNodes = [...super.childNodes];
        this.#childNodes.forEach((node) => this.#initChildNode(node));
      }
      connectedCallback() {
        this.style.display = "none";
        this.#targetElement = this.#queryTarget();
        this.#remount();
      }
      disconnectedCallback() {
        this.#remount();
      }
      connectedMoveCallback() {
      }
      attributeChangedCallback(_name, oldValue, newValue) {
        if (oldValue === newValue)
          return;
        this.targetElement = this.#queryTarget();
      }
      get targetElement() {
        return this.#targetElement;
      }
      set targetElement(element4) {
        if (element4 === this.#targetElement) {
          return;
        }
        this.#targetElement = this.#validateTargetElement(element4);
        this.#remount();
      }
      get target() {
        return super.getAttribute("target") ?? "";
      }
      set target(value) {
        if (value instanceof HTMLElement) {
          this.targetElement = value;
        } else {
          super.setAttribute("target", typeof value === "string" ? value : "");
        }
      }
      get root() {
        return super.getAttribute("root");
      }
      set root(value) {
        super.setAttribute(
          "root",
          value !== "relative" && value !== "document" ? "document" : value
        );
      }
      // -- INTERNALS --------------------------------------------------------------
      #remount() {
        const fragment3 = document.createDocumentFragment();
        for (const childNode of this.#childNodes) {
          fragment3.appendChild(childNode);
        }
        if (this.isConnected) {
          this.#targetElement?.insertBefore(fragment3, null);
        }
      }
      #queryTarget() {
        if (!this.target) {
          return this.#dispatchError(
            missing_selector_tag,
            "The target attribute cannot be empty."
          );
        }
        let root2 = this.root === "relative" ? this.getRootNode() : document;
        let targetElement = null;
        try {
          targetElement = root2.querySelector(this.target);
        } catch {
          return this.#dispatchError(
            invalid_selector_tag,
            `The target "${this.target}" is not a valid query selector.`
          );
        }
        return this.#validateTargetElement(targetElement);
      }
      #validateTargetElement(targetElement) {
        if (!targetElement) {
          return this.#dispatchError(
            target_not_found_tag,
            `No element matching "${this.target}".`
          );
        }
        if (targetElement instanceof HTMLIFrameElement) {
          const iframeBody = targetElement.contentDocument?.body;
          if (!iframeBody) {
            return this.#dispatchError(
              target_is_cross_origin_iframe_tag,
              `Only same-origin iframes can be targeted.`
            );
          } else {
            return iframeBody;
          }
        }
        if (targetElement instanceof Portal) {
          return this.#dispatchError(
            target_is_portal_tag,
            `The element matching "${this.target}" must not be another portal.`
          );
        }
        if (isLustreNode(targetElement)) {
          return this.#dispatchError(
            target_inside_lustre_tag,
            `The element matching "${this.target}" must not be owned by Lustre.`
          );
        }
        return targetElement;
      }
      #dispatchError(tag, message = "", detail = {}) {
        this.dispatchEvent(
          new CustomEvent("error", {
            detail: { tag, message, selector: this.target, ...detail }
          })
        );
        return null;
      }
      #moveOrInsert(newNode, referenceNode, callback) {
        const newNodes = newNode.nodeType === Node.DOCUMENT_FRAGMENT_NODE ? [...newNode.childNodes] : [newNode];
        const oldIndex = this.#childNodes.indexOf(newNode);
        const result = callback(
          newNode,
          referenceNode ?? this.lastChild?.nextSibling ?? null
        );
        newNodes.forEach((node) => this.#initChildNode(node));
        if (oldIndex >= 0) {
          this.#childNodes.splice(oldIndex, 1);
        }
        const index2 = referenceNode ? this.#childNodes.indexOf(referenceNode) : this.#childNodes.length;
        this.#childNodes.splice(index2, 0, ...newNodes);
        return result;
      }
      #initChildNode(node) {
        if (node.nodeType !== Node.ELEMENT_NODE) {
          return;
        }
        node[symbol] ??= {};
        if (!node[symbol].provider) {
          node[symbol].provider = (event4) => {
            event4.stopImmediatePropagation();
            const retargeted = new Event(event4.type, {
              bubbles: event4.bubbles,
              composed: event4.composed
            });
            retargeted.context = event4.context;
            retargeted.subscribe = event4.subscribe;
            retargeted.callback = event4.callback;
            this.dispatchEvent(retargeted);
          };
          node.addEventListener("context-request", node[symbol].provider);
        }
      }
      #deinitChildNode(node) {
        if (!node[symbol]) {
          return;
        }
        if (node[symbol].provider) {
          node.removeEventListener("context-request", node[symbol].provider);
          node[symbol].provider = null;
        }
      }
      // -- FORWARD FUNCTIONS CALLED BY THE RECONCILER -----------------------------
      get childNodes() {
        return this.#childNodes;
      }
      get firstChild() {
        return this.#childNodes[0];
      }
      get lastChild() {
        return this.#childNodes[this.#childNodes.length - 1];
      }
      moveBefore(newNode, referenceNode) {
        return this.#moveOrInsert(
          newNode,
          referenceNode,
          (newNode2, referenceNode2) => {
            this.#targetElement?.moveBefore(newNode2, referenceNode2);
          }
        );
      }
      insertBefore(newNode, referenceNode) {
        return this.#moveOrInsert(
          newNode,
          referenceNode,
          (newNode2, referenceNode2) => {
            this.#targetElement?.insertBefore(newNode2, referenceNode2);
          }
        );
      }
      removeChild(child2) {
        const index2 = this.#childNodes.indexOf(child2);
        this.#targetElement?.removeChild(child2);
        this.#deinitChildNode(child2);
        this.#childNodes.splice(index2, 1);
      }
    }
  );
}

// build/dev/javascript/lustre_portal/lustre/portal.mjs
var name = "lustre-portal";
var missing_selector_tag = "missing-selector";
var invalid_selector_tag = "invalid-selector";
var target_not_found_tag = "target-not-found";
var target_inside_lustre_tag = "target-inside-lustre";
var target_is_cross_origin_iframe_tag = "target-is-cross-origin-iframe";
var target_is_portal_tag = "target-is-portal";
function register2() {
  return guard(
    !is_browser(),
    new Error(new NotABrowser()),
    () => {
      return guard(
        is_registered(name),
        new Error(new ComponentAlreadyRegistered(name)),
        () => {
          return new Ok(register(name));
        }
      );
    }
  );
}

// dev/entry.mjs
register2();
