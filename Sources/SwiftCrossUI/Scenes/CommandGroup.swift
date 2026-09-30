/// The placement of a ``CommandGroup`` within the menu bar.
public struct CommandGroupPlacement: Hashable, Sendable {
    var name: String

    /// Items replacing or augmenting the app's "about" section.
    public static let appInfo = CommandGroupPlacement(name: "appInfo")
    /// Items augmenting the settings section.
    public static let appSettings = CommandGroupPlacement(name: "appSettings")
    /// Items augmenting the help menu.
    public static let help = CommandGroupPlacement(name: "help")
    /// Items augmenting the file menu.
    public static let newItem = CommandGroupPlacement(name: "newItem")
    /// Items augmenting the save section.
    public static let saveItem = CommandGroupPlacement(name: "saveItem")
    /// Items augmenting the undo/redo section.
    public static let undoRedo = CommandGroupPlacement(name: "undoRedo")
    /// Items augmenting the text editing section.
    public static let textEditing = CommandGroupPlacement(name: "textEditing")
    /// Items augmenting the window menu.
    public static let windowList = CommandGroupPlacement(name: "windowList")
}

/// A value that contributes menus to a ``CommandsBuilder`` result.
public protocol CommandsBuildingBlock {
    /// The commands contributed by this block.
    var commands: Commands { get }
}

extension CommandMenu: CommandsBuildingBlock {
    public var commands: Commands {
        Commands(menus: [self])
    }
}

/// A group of commands added to the menu bar. Groups target a placement,
/// which merges into the menu bar through ``Commands``' merge-by-name
/// semantics.
public struct CommandGroup: CommandsBuildingBlock {
    var menus: [CommandMenu]

    /// Creates a command group added after the content at `placement`.
    @MainActor
    public init<Content: View>(
        adding placement: CommandGroupPlacement,
        @ViewBuilder content: () -> Content
    ) {
        menus = [
            CommandMenu(name: placement.name, content: content()._asMenuItems)
        ]
    }

    /// Creates a command group replacing the content at `placement`.
    @MainActor
    public init<Content: View>(
        replacing placement: CommandGroupPlacement,
        @ViewBuilder content: () -> Content
    ) {
        menus = [
            CommandMenu(name: placement.name, content: content()._asMenuItems)
        ]
    }

    /// Creates a command group inserted before `placement`.
    @MainActor
    public init<Content: View>(
        before placement: CommandGroupPlacement,
        @ViewBuilder content: () -> Content
    ) {
        menus = [
            CommandMenu(name: placement.name, content: content()._asMenuItems)
        ]
    }

    public var commands: Commands {
        Commands(menus: menus)
    }
}

/// A single command item added to the menu bar.
public struct CommandMenuItem: CommandsBuildingBlock {
    var item: MenuItem
    var placement: CommandGroupPlacement

    /// Creates a command item with a title and action.
    @MainActor
    public init(
        _ title: String,
        placement: CommandGroupPlacement = .appInfo,
        action: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        item = .button(Button(title, action: action))
        self.placement = placement
    }

    public var commands: Commands {
        Commands(menus: [CommandMenu(name: placement.name, content: [item])])
    }
}
