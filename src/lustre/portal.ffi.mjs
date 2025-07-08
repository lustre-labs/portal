import { isLustreNode } from "../../lustre/lustre/vdom/reconciler.ffi.mjs";
import {
  missing_selector_tag,
  invalid_selector_tag,
  target_inside_lustre_tag,
  target_not_found_tag,
  target_is_cross_origin_iframe_tag,
} from "./portal.mjs";

export function register(name) {
  customElements.define(name, Portal);
}

const portals = Symbol("portals");

class Portal extends HTMLElement {
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
    // the portal element exists in the tree, but we do not want it to have any
    // impact on layout.
    this.style.display = "none";

    // if the target is invalid, this call to getFragment will remove all
    // elements from the tree.
    this.#mount(this.#getFragment());
  }

  disconnectedCallback() {
    this.#unmount();
  }

  connectedMoveCallback() {
    if (!this.#targetElement) {
      return;
    }

    const portalsAtTarget = (this.#targetElement[portals] ??= []);
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
    if (oldValue === newValue) return;

    const newTargetElement = this.#queryTarget();

    if (this.#targetElement !== newTargetElement) {
      this.#remount(newTargetElement);
    }
  }

  get target() {
    return super.getAttribute("target");
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
      value !== "relative" && value !== "document" ? "document" : value,
    );
  }

  // -- INTERNALs --------------------------------------------------------------

  #unmount() {
    if (this.#targetElement) {
      removeElement(this.#targetElement[portals], this);
    }

    return this.#getFragment();
  }

  #mount(fragment) {
    if (!this.isConnected || !this.#targetElement) {
      return;
    }

    const portalsAtTarget = (this.#targetElement[portals] ??= []);
    const index = addElement(portalsAtTarget, this);
    const referenceNode = portalsAtTarget[index + 1]?.firstChild ?? null;
    this.#targetElement.insertBefore(fragment, referenceNode);
  }

  #remount(newTarget) {
    if (this.isConnected) {
      const fragment = this.#unmount();
      this.#targetElement = newTarget;
      this.#mount(fragment);
    } else {
      this.#targetElement = newTarget;
    }
  }

  #queryTarget() {
    if (!this.target) {
      return this.#dispatchError(
        missing_selector_tag,
        "The target attribute cannot be empty.",
      );
    }

    let root = this.root === "relative" ? this.getRootNode() : document;
    let targetElement = null;

    try {
      targetElement = root.querySelector(this.target);
    } catch {
      return this.#dispatchError(
        invalid_selector_tag,
        `The target "${this.target}" is not a valid query selector.`,
        { selector: this.target },
      );
    }

    return this.#validateTargetElement(targetElement);
  }

  #validateTargetElement(targetElement) {
    if (!targetElement) {
      return this.#dispatchError(
        target_not_found_tag,
        `No element matching "${this.target}".`,
        { selector: this.target },
      );
    }

    if (targetElement instanceof HTMLIFrameElement) {
      const iframeBody = targetElement.contentDocument?.body;

      if (!iframeBody) {
        return this.#dispatchError(
          target_is_cross_origin_iframe_tag,
          `Only same-origin iframes can be targeted.`,
        );
      } else {
        return iframeBody;
      }
    }

    // we do not allow you to target Lustre elements - so querying an element
    // in the same ShadowRoot cannot ever make sense, because you already
    // control the entire tree! It only makes sense to target top-level elements.
    if (isLustreNode(targetElement)) {
      return this.#dispatchError(
        target_inside_lustre_tag,
        `The element matching "${this.target}" must not be owned by Lustre.`,
      );
    }

    return targetElement;
  }

  #dispatchError(tag, message = "", detail = {}) {
    this.dispatchEvent(
      new CustomEvent("error", {
        detail: { tag, message, ...detail },
      }),
    );

    return null;
  }

  #getFragment() {
    const fragment = document.createDocumentFragment();

    for (const childNode of this.#childNodes) {
      fragment.appendChild(childNode);
    }

    return fragment;
  }

  #moveOrInsert(newNode, referenceNode, callback) {
    const newNodes =
      newNode.nodeType === Node.DOCUMENT_FRAGMENT_NODE
        ? [...newNode.childNodes]
        : [newNode];

    const oldIndex = this.#childNodes.indexOf(newNode);

    const result = callback(
      newNode,
      referenceNode ?? this.lastChild?.nextSibling ?? null,
    );

    if (oldIndex >= 0) {
      this.#childNodes.splice(oldIndex, 1);
    }

    const index = referenceNode
      ? this.#childNodes.indexOf(referenceNode)
      : this.#childNodes.length;

    this.#childNodes.splice(index, 0, ...newNodes);

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
      (newNode, referenceNode) => {
        this.#targetElement?.moveBefore(newNode, referenceNode);
      },
    );
  }

  insertBefore(newNode, referenceNode) {
    return this.#moveOrInsert(
      newNode,
      referenceNode,
      (newNode, referenceNode) => {
        this.#targetElement?.insertBefore(newNode, referenceNode);
      },
    );
  }

  removeChild(child) {
    const index = this.#childNodes.indexOf(child);

    this.#targetElement?.removeChild(child);
    this.#childNodes.splice(index, 1);
  }
}

// -- BINARY SEARCH ------------------------------------------------------------

function findInsertionIndex(array, node) {
  let low = 0;
  let high = array.length - 1;

  while (low <= high) {
    const mid = ((low + high) / 2) | 0;
    const position = node.compareDocumentPosition(array[mid]);
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

function addElement(array, node) {
  const index = findInsertionIndex(array, node);

  if (array[index] !== node) {
    array.splice(index, 0, node);
  }

  return index;
}

function removeElement(array, node) {
  // NOTE: we cannot use the binary search here, because the element is already
  // no longer part of the document tree, compareDocumentPosition will not work!
  const index = array.indexOf(node);

  if (index >= 0) {
    array.splice(index, 1);
  }

  return index;
}
