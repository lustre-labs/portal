import { isLustreNode } from "../../lustre/lustre/vdom/reconciler.ffi.mjs";
import {
  missing_selector_tag,
  invalid_selector_tag,
  target_inside_lustre_tag,
  target_not_found_tag,
  target_is_cross_origin_iframe_tag,
  target_is_portal_tag,
} from "./portal.mjs";

export function register(name) {
  customElements.define(name, Portal);
}

const symbol = Symbol('lustre-portal');

class Portal extends HTMLElement {
  // -- CUSTOM ELEMENT IMPLEMENTATION ------------------------------------------

  static observedAttributes = ["target", "root"];

  #targetElement = null;
  #childNodes = [];

  constructor() {
    super();
    this.#targetElement = this.#queryTarget();
    this.#childNodes = [...super.childNodes];

    this.$childNodes.forEach((node) => this.#initChildNode(node));
  }

  connectedCallback() {
    // the portal element exists in the tree, but we do not want it to have any
    // impact on layout.
    this.style.display = "none";
    this.#remount();
  }

  disconnectedCallback() {
    this.#remount();
  }

  connectedMoveCallback() {
    // We do not want to remove and re-insert all child elements when the portal
    // element itself gets moved, so this is a no-op.
  }

  attributeChangedCallback(_name, oldValue, newValue) {
    if (oldValue === newValue) return;
    this.targetElement = this.#queryTarget();
  }

  get targetElement() {
    return this.#targetElement;
  }

  set targetElement(element) {
    if (element === this.#targetElement) {
      return;
    }

    this.#targetElement = this.#validateTargetElement(element);
    this.#remount();
  }

  get target() {
    return super.getAttribute("target") ?? '';
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
      value !== "relative" && value !== "document" ? "document" : value,
    );
  }

  // -- INTERNALS --------------------------------------------------------------

  #remount() {
    // move all elements to a fragment, effectively removing them.
    const fragment = document.createDocumentFragment()
    for (const childNode of this.#childNodes) {
      fragment.appendChild(childNode)
    }

    // if we are connected, insert them back at the desired target element.
    if (this.isConnected) {
      this.#targetElement?.insertBefore(fragment, null);
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
      );
    }

    return this.#validateTargetElement(targetElement);
  }

  #validateTargetElement(targetElement) {
    if (!targetElement) {
      return this.#dispatchError(
        target_not_found_tag,
        `No element matching "${this.target}".`,
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

    if (targetElement instanceof Portal) {
      return this.#dispatchError(
        target_is_portal_tag,
        `The element matching "${this.target}" must not be another portal.`,
      );
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
        detail: { tag, message, selector: this.target, ...detail },
      }),
    );

    return null;
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

    newNodes.forEach((node) => this.#initChildNode(node));

    if (oldIndex >= 0) {
      this.#childNodes.splice(oldIndex, 1);
    }

    const index = referenceNode
      ? this.#childNodes.indexOf(referenceNode)
      : this.#childNodes.length;

    this.#childNodes.splice(index, 0, ...newNodes);

    return result;
  }

  #initChildNode(node) {
    if (node.nodeType !== Node.ELEMENT_NODE) {
      return;
    }

    node[symbol] ??= {};
    if (!node[symbol].provider) {
      node[symbol].provider = (event) => {
        event.stopImmediatePropagation();

        const retargeted = new Event(event.type, {
          bubbles: event.bubbles,
          composed: event.composed
        });

        retargeted.context = event.context;
        retargeted.subscribe = event.subscribe;
        retargeted.callback = event.callback;

        this.dispatchEvent(retargeted);
      }
      node.addEventListener('context-request', node[symbol].provider);
    }
  }

  #deinitChildNode(node) {
    if (!node[symbol]) {
      return;
    }

    if (node[symbol].provider) {
      node.removeEventListener('context-request', node[symbol].provider);
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
    this.#deinitChildNode(child);

    this.#childNodes.splice(index, 1);
  }
}
