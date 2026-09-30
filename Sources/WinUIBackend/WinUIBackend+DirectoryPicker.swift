import Foundation
import UWP
import WinAppSDK
import WinSDK
import WinUIInterop

/// Presents a folder picker and returns the chosen directory's URL.
///
/// Standalone counterpart to ``WinUIBackend/showOpenDialog`` for cases where
/// no ``EnvironmentValues/chooseFile`` action is in scope (e.g. async helpers
/// outside the view hierarchy). Uses `GetForegroundWindow` to parent the
/// picker, which suffices because pickers are only ever presented while the
/// app is in the foreground.
@MainActor
public func winUIChooseDirectory(
    title: String = "Open",
    initialDirectory: URL? = nil
) async -> URL? {
    let picker = FolderPicker()

    // Parent the picker to a real app window. `GetForegroundWindow` can return
    // an unrelated window (e.g. a console or another app), which leaves the
    // picker wedged in an unusable state.
    let hwnd = WinUIBackend.lastShownWindow?.getHWND() ?? GetForegroundWindow()
    if let hwnd {
        let interface: SwiftIInitializeWithWindow? = try? picker.thisPtr.QueryInterface()
        _ = try? interface?.initialize(with: hwnd)
    }

    picker.fileTypeFilter.append("*")

    guard let promise = try? picker.pickSingleFolderAsync() else {
        return nil
    }
    return await withCheckedContinuation { continuation in
        promise.completed = { operation, status in
            guard
                status == .completed,
                let folder = try? operation?.getResults()
            else {
                continuation.resume(returning: nil)
                return
            }
            continuation.resume(returning: URL(fileURLWithPath: folder.path))
        }
    }
}
