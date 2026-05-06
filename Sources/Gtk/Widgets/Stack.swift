//
//  Copyright © 2015 Tomas Linhart. All rights reserved.
//

import CGtk

open class Stack: Widget {
    private var pages = [Widget]()
    public var notifyVisibleChild: ((Stack) -> Void)?

    public convenience init(transitionDuration: Int, transitionType: StackTransitionType) {
        self.init(gtk_stack_new())
        self.transitionDuration = transitionDuration
        self.transitionType = transitionType
    }

    /// Transition duration in milliseconds
    @GObjectProperty(named: "transition-duration") public var transitionDuration: Int

    /// Transition type
    @GObjectProperty(named: "transition-type") public var transitionType: StackTransitionType

    public func add(_ child: Widget, named name: String, title: String? = nil) {
        pages.append(child)
        child.parentWidget = self
        if let title {
            gtk_stack_add_titled(opaquePointer, child.castedPointer(), name, title)
        } else {
            gtk_stack_add_named(opaquePointer, child.castedPointer(), name)
        }
    }

    public func remove(_ child: Widget) {
        if let index = pages.lastIndex(where: { $0 === child }) {
            gtk_stack_remove(opaquePointer, child.castedPointer())
            pages.remove(at: index)
            child.parentWidget = nil
        }
    }

    public func setVisible(_ child: Widget) {
        if pages.contains(where: { $0 === child }) {
            gtk_stack_set_visible_child(opaquePointer, child.castedPointer())
        }
    }

    public var visibleChild: Widget? {
        guard let childPointer = gtk_stack_get_visible_child(opaquePointer) else {
            return nil
        }
        return pages.first { $0.widgetPointer == childPointer }
    }

    open override func didMoveToParent() {
        super.didMoveToParent()

        let handler:
            @convention(c) (UnsafeMutableRawPointer, OpaquePointer, UnsafeMutableRawPointer) -> Void =
                { _, value1, data in
                    SignalBox1<OpaquePointer>.run(data, value1)
                }

        addSignal(name: "notify::visible-child", handler: gCallback(handler)) {
            [weak self] (_: OpaquePointer) in
            guard let self else { return }
            self.notifyVisibleChild?(self)
        }
    }
}
