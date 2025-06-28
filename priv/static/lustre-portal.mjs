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
var isLustreNode = (node) => {
  while (node) {
    if (node[meta])
      return true;
    node = node.parentNode;
  }
  return false;
};

// build/dev/javascript/lustre/lustre/runtime/client/runtime.ffi.mjs
var is_browser = () => !!document2();
var is_registered = (name) => is_browser() && customElements.get(name);

// build/dev/javascript/lustre/lustre.mjs
var ComponentAlreadyRegistered = class extends CustomType {
  constructor(name) {
    super();
    this.name = name;
  }
};
var NotABrowser = class extends CustomType {
};

// build/dev/javascript/lustre_portal/lustre-portal.ffi.mjs
function register(name) {
  customElements.define(name, Portal);
}
var portals = Symbol("portals");
var Portal = class extends HTMLElement {
  // -- CUSTOM ELEMENT IMPLEMENTATION ------------------------------------------
  static observedAttributes = ["to"];
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
  attributeChangedCallback(name, oldValue, newValue) {
    if (name === "to" && oldValue !== newValue) {
      const newTarget = this.#queryTarget();
      if (this.#targetElement !== newTarget) {
        this.#remount(newTarget);
      }
    }
  }
  get to() {
    return super.getAttribute("to");
  }
  set to(value) {
    super.setAttribute("to", value);
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
    const to = this.to ?? "";
    let target = null;
    try {
      target = document.querySelector(to);
    } catch {
      return this.#dispatchInvalid(invalid_selector_tag);
    }
    if (!target) {
      return this.#dispatchInvalid(target_not_found_tag);
    }
    if (isLustreNode(target)) {
      return this.#dispatchInvalid(target_inside_lustre_tag);
    }
    return target;
  }
  #dispatchInvalid(reason) {
    this.dispatchEvent(new CustomEvent("invalid", {
      detail: reason
    }));
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
    const result = callback(newNode, referenceNode ?? this.lastChild?.nextSibling ?? null);
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
      (newNode2, referenceNode2) => this.#targetElement?.moveBefore(newNode2, referenceNode2)
    );
  }
  insertBefore(newNode, referenceNode) {
    return this.#moveOrInsert(
      newNode,
      referenceNode,
      (newNode2, referenceNode2) => this.#targetElement?.insertBefore(newNode2, referenceNode2)
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
var component_name = "lustre-portal";
function register2() {
  let $ = is_browser();
  if ($) {
    let $1 = is_registered(component_name);
    if ($1) {
      return new Error(new ComponentAlreadyRegistered(component_name));
    } else {
      let $2 = register(component_name);
      return new Ok(void 0);
    }
  } else {
    return new Error(new NotABrowser());
  }
}
var invalid_selector_tag = "invalid-selector";
var target_not_found_tag = "target-not-found";
var target_inside_lustre_tag = "target-inside-lustre";

// dev/entry.mjs
register2();
