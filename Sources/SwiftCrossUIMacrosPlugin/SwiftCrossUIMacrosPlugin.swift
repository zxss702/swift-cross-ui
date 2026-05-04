import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftCrossUIMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ObservableObjectMacro.self,
        ObservableObjectIgnoredMacro.self,
        HotReloadableAppMacro.self,
        HotReloadableExprMacro.self,
        EntryMacro.self,
        CastBackendMacro.self,
    ]
}
