import DefaultBackend
import SwiftCrossUI

#if canImport(SwiftBundlerRuntime)
    import SwiftBundlerRuntime
#endif

@main
@HotReloadable
struct AnimationApp: App {
    var body: some Scene {
        WindowGroup("AnimationExample") {
            #hotReloadable {
                AnimationShowcaseView()
            }
        }
        .defaultSize(width: 820, height: 900)
    }
}
