export function register() {
  customElements.define("lustre-portal", Portal)
}

const portals = Symbol('portals');

class Portal extends HTMLElement {

  // -- CUSTOM ELEMENT IMPLEMENTATION ------------------------------------------
  
  static observedAttributes = ["to"];

  #targetElement = null;
  #childNodes = [];
  #eventListeners = [];
  #attributes = new Map();

  constructor() {
    super()
    this.#targetElement = this.#queryTarget();
    this.#childNodes = [...super.childNodes];
  }

  connectedCallback() {
    this.#mount(this.#getFragment());
  }

  disconnectedCallback() {
    this.#unmount();
  }

  connectedMoveCallback() {
    const portalsAtTarget = (this.#targetElement[portals] ??= []);
    const oldIndex = removeElement(portalsAtTarget, this);
    const newIndex = addElement(portalsAtTarget, this);

    if (oldIndex !== newIndex) {
     const referenceNode = portalsAtTarget[newIndex+1]?.firstChild ?? null;
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
    return super.getAttribute('to')
  }

  set to(value) {
    super.setAttribute('to', value);
  }

  // -- INTERNALs --------------------------------------------------------------

  #unmount() {
    if (this.#targetElement) {
      removeElement(this.#targetElement[portals], this);  
    }
    
    for (const attributeName of this.#attributes.keys()) {
      this.#removeAttribute(attributeName);
    }

    for (const { type, listener, options } of this.#eventListeners) {
      this.#removeEventListener(type, listener, options);
    }

    return this.#getFragment();
  }

  #mount(fragment) {
    if (!this.isConnected) {
      return;
    }
    
    for (const [name, value] of this.#attributes.entries()) {
      this.#setAttribute(name, value)
    }

    for (const { type, listener, options } of this.#eventListeners) {
      this.#addEventListener(type, listener, options);
    }

    if (this.#targetElement) {
      const portalsAtTarget = (this.#targetElement[portals] ??= []);
      const index = addElement(portalsAtTarget, this);
      const referenceNode = portalsAtTarget[index+1]?.firstChild ?? null;
      this.#targetElement.insertBefore(fragment, referenceNode);
      this.style.display = 'none';
    } else {
      super.replaceChildren(fragment);
      this.style.removeProperty('display');
    }
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
    const to = this.to;
    if (!to) {
      return null;
    }

    const rootNode = this.getRootNode();
    if (rootNode === this) {
      return document.querySelector(to);
    } else {
      return rootNode.querySelector(to);
    }
  }

  #getFragment() {
    const fragment = document.createDocumentFragment();
    for (const childNode of this.#childNodes) {
      fragment.appendChild(childNode);
    }

    return fragment;
  }

  #setAttribute(name, value) {
    const isOwnAttribute = Portal.observedAttributes.includes(name);
    if (!this.#targetElement || isOwnAttribute) {
      super.setAttribute(name, value);
    } else if (name === 'class') {
      this.#removeClasses();
      this.#targetElement.setAttribute(name, (this.#targetElement.getAttribute(name) ?? '') + ' ' + value)
    } else if (name === 'style') {
      this.#removeStyles();
      this.#targetElement.style.cssText += value;
    } else {
      this.#targetElement.setAttribute(name, value);
    }
  }

  #removeAttribute(attributeName) {
    if (!this.#targetElement || Portal.observedAttributes.includes(attributeName)) {
      super.removeAttribute(attributeName);
    } else if (attributeName === 'class') {
      this.#removeClasses();
    } else if (attributeName === 'style') {
      this.#removeStyles();
    } else {
      this.#targetElement.removeAttribute(attributeName);
    }
  }

  #removeClasses() {
    const classNames = this.#attributes.get('class')?.split(/\s+/g) ?? []; 
    for (const className of classNames) {
      this.#targetElement.classList.remove(className);
    }
  }

  #removeStyles() {
    for (const property of extractPropertyNames(this.#attributes.get('style'))) {
      this.#targetElement.style.removeProperty(property);
    }
  }

  #addEventListener(type, listener, options) {
    if (this.#targetElement) {
      this.#targetElement.addEventListener(type, listener, options);
    } else {
      super.addEventListener(type, listener, options);
    }
  }

  #removeEventListener(type, listener, options) {
    if (this.#targetElement) {
      this.#targetElement.removeEventListener(type, listener, options);
    } else {
      super.removeEventListener(type, listener, options);
    }
  }

  #insertBefore(newNode, referenceNode) {
    if (this.#targetElement) {
      this.#targetElement.insertBefore(newNode, referenceNode)
    } else {
      super.insertBefore(newNode, referenceNode)
    }
  }

  #moveBefore(newNode, referenceNode) {
    if (this.#targetElement) {
      this.#targetElement.moveBefore(newNode, referenceNode)
    } else {
      super.moveBefore(newNode, referenceNode)
    }
  }

  #moveOrInsert(newNode, referenceNode, callback) {
    const newNodes = newNode.nodeType === Node.DOCUMENT_FRAGMENT_NODE
      ? [...newNode.childNodes]
      : [newNode];

    const oldIndex = this.#childNodes.indexOf(newNode)

    const result = callback(newNode, referenceNode ?? this.lastChild?.nextSibling ?? null)

    if (oldIndex >= 0) {
      this.#childNodes.splice(oldIndex, 1)
    }

    const index = referenceNode
      ? this.#childNodes.indexOf(referenceNode)
      : this.#childNodes.length;

    this.#childNodes.splice(index, 0, ...newNodes)

    return result
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

  getAttribute(attributeName) {
    if (!this.#targetElement || Portal.observedAttributes.includes(attributeName)) {
      return super.getAttribute(attributeName);
    } else {
      return this.#targetElement.getAttribute(attributeName);
    }
  }

  setAttribute(name, value) {
    this.#setAttribute(name, value);
    if (!Portal.observedAttributes.includes(name)) {
      this.#attributes.set(name, value);
    }
  }

  removeAttribute(attributeName) {
    this.#removeAttribute(attributeName);
    this.#attributes.delete(attributeName);
  }

  addEventListener(type, listener, options) {
    this.#addEventListener(type, listener, options);
    const capture = typeof options === 'boolean' ? options : !!options?.capture;
    this.#eventListeners.push({ type, listener, capture, options });
  }

  removeEventListener(type, listener, options) {
    this.#removeEventListener(type, listener, options);
    // SPEC: removeEventListener only matches options based on the capture flag.
    const capture = typeof options === 'boolean' ? options : !!options?.capture;
    const index = this.#eventListeners.findIndex(listener =>
      listener.type === type && listener.listener === listener && listener.capture === capture);
    this.#eventListeners.splice(index, 1);
  }

  moveBefore(newNode, referenceNode) {
    return this.#moveOrInsert(newNode, referenceNode,
      (newNode, referenceNode) => this.#moveBefore(newNode, referenceNode))
  }

  insertBefore(newNode, referenceNode) {
    return this.#moveOrInsert(newNode, referenceNode,
      (newNode, referenceNode, ) => this.#insertBefore(newNode, referenceNode))
  }

  removeChild(child) {
    const index = this.#childNodes.indexOf(child);

    if (this.#targetElement) {
      this.#targetElement.removeChild(child);
    } else {
      super.removeChild(child);
    }
    
    this.#childNodes.splice(index, 1);
  }
}

// -- BINARY SEARCH ------------------------------------------------------------

function findInsertionIndex(array, node) {
  let low = 0;
  let high = array.length - 1;

  while (low <= high) {
    const mid = ((low + high) / 2)|0;
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

// -- STYLE TAG PARSE ----------------------------------------------------------

const commentRe = /\/\*[^*]*\*+(?:[^\/*][^*]*\*+)*\//g;
const propertyRe = /[-#/*\\\w]+(?=\s*:)/g;

function extractPropertyNames(style) {
  if (!style) {
    return [];
  }
  
  return style.replaceAll(commentRe, '').match(propertyRe);
}
