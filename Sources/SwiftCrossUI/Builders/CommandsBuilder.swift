/// A result builder for ``Commands``.
@resultBuilder
public struct CommandsBuilder {
    public static func buildBlock(_ blocks: any CommandsBuildingBlock...) -> Commands {
        var commands = Commands.empty
        for block in blocks {
            commands = commands.overlayed(with: block.commands)
        }
        return commands
    }

    public static func buildBlock(_ menus: CommandMenu...) -> Commands {
        Commands(menus: menus)
    }
}
