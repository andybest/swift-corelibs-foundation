// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import CoreFoundation
/*!
    @class NSXMLElement
    @abstract An XML element
    @discussion Note: Trying to add a document, namespace, attribute, or node with a parent throws an exception. To add a node with a parent first detach or create a copy of it.
*/
open class XMLElement: XMLNode {

    /*!
        @method initWithName:
        @abstract Returns an element <tt>&lt;name>&lt;/name></tt>.
    */
    public convenience init(name: String) {
        self.init(name: name, uri: nil)
    }

    /*!
        @method initWithName:URI:
        @abstract Returns an element whose full QName is specified.
    */
    public init(name: String, uri URI: String?) {
        super.init(kind: .element, options: [])
        self.uri = URI
        self.name = name
    }

    /*!
        @method initWithName:stringValue:
        @abstract Returns an element with a single text node child <tt>&lt;name>string&lt;/name></tt>.
    */
    public convenience init(name: String, stringValue string: String?) {
        self.init(name: name, uri: nil)
        if let string = string {
            let child = _CFXMLNewTextNode(string)
            _CFXMLNodeAddChild(_xmlNode, child)
        }
    }

    /*!
        @method initWithXMLString:error:
        @abstract Returns an element created from a string. Parse errors are collected in <tt>error</tt>.
    */
    public convenience init(xmlString string: String) throws {
        // If we prepend the XML line to the string
        let docString = """
        <?xml version="1.0" encoding="utf-8" standalone="yes"?>\(string)
        """
        // we can use the document string parser to get the element
        let doc = try XMLDocument(xmlString: docString, options: [])
        // We know the doc has a root element and first child or else the above line would have thrown
        self.init(ptr:  _CFXMLCopyNode(_CFXMLNodeGetFirstChild(doc._xmlNode)!, true))
    }

    public convenience override init(kind: XMLNode.Kind, options: XMLNode.Options = []) {
        self.init(name: "", uri: nil)
    }

    /*!
        @method elementsForName:
        @abstract Returns all of the child elements that match this name.
    */
    open func elements(forName name: String) -> [XMLElement] {
        return self.filter({ _CFXMLNodeGetType($0._xmlNode) == _kCFXMLTypeElement }).filter({ $0.name == name }).flatMap({ $0 as? XMLElement })
    }

    /*!
        @method elementsForLocalName:URI
        @abstract Returns all of the child elements that match this localname URI pair.
    */
    open func elements(forLocalName localName: String, uri URI: String?) -> [XMLElement] {
        return self.filter({ _CFXMLNodeGetType($0._xmlNode) == _kCFXMLTypeElement }).filter({ $0.localName == localName && $0.uri == uri }).flatMap({ $0 as? XMLElement })
    }

    /*!
        @method addAttribute:
        @abstract Adds an attribute. Attributes with duplicate names are not added.
    */
    open func addAttribute(_ attribute: XMLNode) {
        guard let name = _CFXMLNodeCopyName(attribute._xmlNode)?._swiftObject else {
            fatalError("Attributes must have a name!")
        }

        name.cString(using: .utf8)!.withUnsafeBufferPointer() {
            guard let ptr = $0.baseAddress, _CFXMLNodeHasProp(_xmlNode, ptr) == nil else { return }
            addChild(attribute)
        }
    }

    /*!
        @method removeAttributeForName:
        @abstract Removes an attribute based on its name.
    */
    open func removeAttribute(forName name: String) {
        if let prop = _CFXMLNodeHasProp(_xmlNode, name) {
            let propNode = XMLNode._objectNodeForNode(_CFXMLNodePtr(prop))
            _childNodes.remove(propNode)
            // We can't use `xmlRemoveProp` because someone else may still have a reference to this attribute
            _CFXMLUnlinkNode(_CFXMLNodePtr(prop))
        }
    }

    /*!
        @method setAttributes
        @abstract Set the attributes. In the case of duplicate names, the first attribute with the name is used.
    */
    open var attributes: [XMLNode]? {
        get {
            var result: [XMLNode] = []
            var nextAttribute = _CFXMLNodeProperties(_xmlNode)
            while let attribute = nextAttribute {
                result.append(XMLNode._objectNodeForNode(attribute))
                nextAttribute = _CFXMLNodeGetNextSibling(attribute)
            }
            return !result.isEmpty ? result : nil // This appears to be how Darwin does it
        }

        set {
            removeAttributes()

            guard let attributes = newValue else {
                return
            }

            for attribute in attributes {
                addAttribute(attribute)
            }
        }
    }

    private func removeAttributes() {
        var nextAttribute = _CFXMLNodeProperties(_xmlNode)
        while let attribute = nextAttribute {
            var shouldFreeNode = true
            if let privateData = _CFXMLNodeGetPrivateData(attribute) {
                _childNodes.remove(XMLNode.unretainedReference(privateData))

                shouldFreeNode = false
            }

            let temp = _CFXMLNodeGetNextSibling(attribute)
            _CFXMLUnlinkNode(attribute)
            if shouldFreeNode {
                _CFXMLFreeNode(attribute)
            }

            nextAttribute = temp
        }
    }

    /*!
     @method setAttributesWithDictionary:
     @abstract Set the attributes based on a name-value dictionary.
     */
    open func setAttributesWith(_ attributes: [String : String]) {
        removeAttributes()
        for (name, value) in attributes {
            addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
        }
    }

    /*!
        @method attributeForName:
        @abstract Returns an attribute matching this name.
    */
    open func attribute(forName name: String) -> XMLNode? {
        guard let attribute = _CFXMLNodeHasProp(_xmlNode, name) else { return nil }
        return XMLNode._objectNodeForNode(attribute)
    }

    /*!
        @method attributeForLocalName:URI:
        @abstract Returns an attribute matching this localname URI pair.
    */
    open func attribute(forLocalName localName: String, uri URI: String?) -> XMLNode? {
        NSUnimplemented()
    }

    /*!
        @method addNamespace:URI:
        @abstract Adds a namespace. Namespaces with duplicate names are not added.
    */
    open func addNamespace(_ aNamespace: XMLNode) {
        if ((namespaces ?? []).flatMap({ $0.name }).contains(aNamespace.name ?? "")) {
            return
        }
        _CFXMLAddNamespace(_xmlNode, aNamespace._xmlNode)
    }

    /*!
        @method addNamespace:URI:
        @abstract Removes a namespace with a particular name.
    */
    open func removeNamespace(forPrefix name: String) {
        _CFXMLRemoveNamespace(_xmlNode, name)
    }

    /*!
        @method namespaces
        @abstract Set the namespaces. In the case of duplicate names, the first namespace with the name is used.
    */
    open var namespaces: [XMLNode]? {
        get {
            var count: Int = 0
            if let result = _CFXMLNamespaces(_xmlNode, &count) {
                defer {
                    free(result)
                }
                let namespacePtrs = UnsafeBufferPointer<_CFXMLNodePtr>(start: result, count: count)
                return namespacePtrs.map { XMLNode._objectNodeForNode($0) }
            }

            return nil
        }

        set {
            if var nodes = newValue?.map({ $0._xmlNode }) {
                nodes.withUnsafeMutableBufferPointer({ (bufPtr) in
                    _CFXMLSetNamespaces(_xmlNode, bufPtr.baseAddress, bufPtr.count)
                })
            } else {
                _CFXMLSetNamespaces(_xmlNode, nil, 0);
            }
        }
    }

    /*!
        @method namespaceForPrefix:
        @abstract Returns the namespace matching this prefix.
    */
    open func namespace(forPrefix name: String) -> XMLNode? {
        NSUnimplemented()
    }

    /*!
        @method resolveNamespaceForName:
        @abstract Returns the namespace who matches the prefix of the name given. Looks in the entire namespace chain.
    */
    open func resolveNamespace(forName name: String) -> XMLNode? {
        NSUnimplemented()
    }

    /*!
        @method resolvePrefixForNamespaceURI:
        @abstract Returns the URI of this prefix. Looks in the entire namespace chain.
    */
    open func resolvePrefix(forNamespaceURI namespaceURI: String) -> String? {
        NSUnimplemented()
    }

    /*!
        @method insertChild:atIndex:
        @abstract Inserts a child at a particular index.
    */
    open func insertChild(_ child: XMLNode, at index: Int) {
        _insertChild(child, atIndex: index)
    }

    /*!
        @method insertChildren:atIndex:
        @abstract Insert several children at a particular index.
    */
    open func insertChildren(_ children: [XMLNode], at index: Int) {
        _insertChildren(children, atIndex: index)
    }

    /*!
        @method removeChildAtIndex:atIndex:
        @abstract Removes a child at a particular index.
    */
    open func removeChild(at index: Int) {
        _removeChildAtIndex(index)
    }

    /*!
        @method setChildren:
        @abstract Removes all existing children and replaces them with the new children. Set children to nil to simply remove all children.
    */
    open func setChildren(_ children: [XMLNode]?) {
        _setChildren(children)
    }

    /*!
        @method addChild:
        @abstract Adds a child to the end of the existing children.
    */
    open func addChild(_ child: XMLNode) {
        _addChild(child)
    }

    /*!
        @method replaceChildAtIndex:withNode:
        @abstract Replaces a child at a particular index with another child.
    */
    open func replaceChild(at index: Int, with node: XMLNode) {
        _replaceChildAtIndex(index, withNode: node)
    }

    /*!
        @method normalizeAdjacentTextNodesPreservingCDATA:
        @abstract Adjacent text nodes are coalesced. If the node's value is the empty string, it is removed. This should be called with a value of NO before using XQuery or XPath.
    */
    open func normalizeAdjacentTextNodesPreservingCDATA(_ preserve: Bool) { NSUnimplemented() }

    internal override class func _objectNodeForNode(_ node: _CFXMLNodePtr) -> XMLElement {
        precondition(_CFXMLNodeGetType(node) == _kCFXMLTypeElement)

        if let privateData = _CFXMLNodeGetPrivateData(node) {
            return XMLElement.unretainedReference(privateData)
        }

        return XMLElement(ptr: node)
    }

    internal override init(ptr: _CFXMLNodePtr) {
        super.init(ptr: ptr)
    }
}

extension XMLElement {
    /*!
        @method setAttributesAs:
        @abstract Set the attributes base on a name-value dictionary.
        @discussion This method is deprecated and does not function correctly. Use -setAttributesWith: instead.
     */
    @available(*, unavailable, renamed:"setAttributesWith")
    public func setAttributesAs(_ attributes: [NSObject : AnyObject]) { NSUnimplemented() }
}
