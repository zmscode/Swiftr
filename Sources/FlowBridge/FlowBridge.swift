import SwiftFlow

/// SwiftFlow's `Node`, under a name that doesn't clash with Swiftr's own `Node`. (It can't be
/// written `SwiftFlow.Node` from Swiftr, because `SwiftFlow` is also the name of its canvas view.)
public typealias FlowNode<Data: Equatable & Sendable> = Node<Data>
