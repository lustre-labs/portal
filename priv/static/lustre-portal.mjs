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
  // @internal
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value) {
    super();
    this[0] = value;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};

// build/dev/javascript/gleam_stdlib/dict.mjs
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var trim_start_regex = /* @__PURE__ */ new RegExp(
  `^[${unicode_whitespaces}]*`
);
var trim_end_regex = /* @__PURE__ */ new RegExp(`[${unicode_whitespaces}]*$`);

// build/dev/javascript/lustre/lustre/internals/constants.ffi.mjs
var document2 = () => globalThis?.document;
var SUPPORTS_MOVE_BEFORE = !!globalThis.HTMLElement?.prototype?.moveBefore;

// build/dev/javascript/lustre/lustre/vdom/reconciler.ffi.mjs
var meta = Symbol("lustre");
var isLustreNode = (node) => !!node[meta];

// build/dev/javascript/lustre/lustre/runtime/client/runtime.ffi.mjs
var is_browser = () => !!document2();
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
function register(name2) {
  customElements.define(name2, Portal);
}
var portals = Symbol("portals");
var Portal = class _Portal extends HTMLElement {
  // -- CUSTOM ELEMENT IMPLEMENTATION ------------------------------------------
  static observedAttributes = ["target", "root"];
  #targetElement = null;
  #childNodes = [];
  constructor() {
    super();
    this.#targetElement = this.#queryTarget();
    this.#childNodes = [...super.childNodes];
  }
  connectedCallback() {
    this.style.display = "none";
    this.#mount(this.#getFragment());
  }
  disconnectedCallback() {
    this.#unmount();
  }
  connectedMoveCallback() {
    if (!this.#targetElement) {
      return;
    }
    const portalsAtTarget = this.#targetElement[portals] ??= [];
    const oldIndex = removeElement(portalsAtTarget, this);
    const newIndex = addElement(portalsAtTarget, this);
    if (oldIndex !== newIndex) {
      const referenceNode = portalsAtTarget[newIndex + 1]?.firstChild ?? null;
      for (const childNode of this.#childNodes) {
        this.#targetElement.moveBefore(childNode, referenceNode);
      }
    }
  }
  attributeChangedCallback(name2, oldValue, newValue) {
    if (oldValue === newValue)
      return;
    const newTargetElement = this.#queryTarget();
    if (this.#targetElement !== newTargetElement) {
      this.#remount(newTargetElement);
    }
  }
  get target() {
    return super.getAttribute("target") ?? "";
  }
  set target(value) {
    if (value instanceof HTMLElement) {
      const targetElement = this.#validateTargetElement(value);
      if (targetElement) {
        this.#remount(targetElement);
      } else {
        this.#unmount();
        this.#targetElement = null;
      }
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
  // -- INTERNALs --------------------------------------------------------------
  #unmount() {
    if (this.#targetElement) {
      removeElement(this.#targetElement[portals], this);
    }
    return this.#getFragment();
  }
  #mount(fragment3) {
    if (!this.isConnected || !this.#targetElement) {
      return;
    }
    const portalsAtTarget = this.#targetElement[portals] ??= [];
    const index2 = addElement(portalsAtTarget, this);
    const referenceNode = portalsAtTarget[index2 + 1]?.firstChild ?? null;
    this.#targetElement.insertBefore(fragment3, referenceNode);
  }
  #remount(newTarget) {
    if (this.isConnected) {
      const fragment3 = this.#unmount();
      this.#targetElement = newTarget;
      this.#mount(fragment3);
    } else {
      this.#targetElement = newTarget;
    }
  }
  #queryTarget() {
    if (!this.target) {
      return this.#dispatchError(
        missing_selector_tag,
        "The target attribute cannot be empty."
      );
    }
    let root3 = this.root === "relative" ? this.getRootNode() : document;
    let targetElement = null;
    try {
      targetElement = root3.querySelector(this.target);
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
    if (targetElement instanceof _Portal) {
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
  #getFragment() {
    const fragment3 = document.createDocumentFragment();
    for (const childNode of this.#childNodes) {
      fragment3.appendChild(childNode);
    }
    return fragment3;
  }
  #moveOrInsert(newNode, referenceNode, callback) {
    const newNodes = newNode.nodeType === Node.DOCUMENT_FRAGMENT_NODE ? [...newNode.childNodes] : [newNode];
    const oldIndex = this.#childNodes.indexOf(newNode);
    const result = callback(
      newNode,
      referenceNode ?? this.lastChild?.nextSibling ?? null
    );
    if (oldIndex >= 0) {
      this.#childNodes.splice(oldIndex, 1);
    }
    const index2 = referenceNode ? this.#childNodes.indexOf(referenceNode) : this.#childNodes.length;
    this.#childNodes.splice(index2, 0, ...newNodes);
    return result;
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
  removeChild(child) {
    const index2 = this.#childNodes.indexOf(child);
    this.#targetElement?.removeChild(child);
    this.#childNodes.splice(index2, 1);
  }
};
function findInsertionIndex(array3, node) {
  let low = 0;
  let high = array3.length - 1;
  while (low <= high) {
    const mid = (low + high) / 2 | 0;
    const position = node.compareDocumentPosition(array3[mid]);
    if (position & Node.DOCUMENT_POSITION_FOLLOWING) {
      high = mid - 1;
    } else if (position & Node.DOCUMENT_POSITION_PRECEDING) {
      low = mid + 1;
    } else {
      return mid;
    }
  }
  return low;
}
function addElement(array3, node) {
  const index2 = findInsertionIndex(array3, node);
  if (array3[index2] !== node) {
    array3.splice(index2, 0, node);
  }
  return index2;
}
function removeElement(array3, node) {
  const index2 = array3.indexOf(node);
  if (index2 >= 0) {
    array3.splice(index2, 1);
  }
  return index2;
}

// build/dev/javascript/lustre_portal/lustre/portal.mjs
var name = "lustre-portal";
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
var missing_selector_tag = "missing-selector";
var invalid_selector_tag = "invalid-selector";
var target_not_found_tag = "target-not-found";
var target_inside_lustre_tag = "target-inside-lustre";
var target_is_cross_origin_iframe_tag = "target-is-cross-origin-iframe";
var target_is_portal_tag = "target-is-portal";

// dev/entry.mjs
register2();
