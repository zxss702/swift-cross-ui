import Foundation

/// Presents an 'Open files' dialog fit for selecting multiple files.
@available(tvOS, unavailable, message: "tvOS does not provide file system access")
public struct PresentMultipleFilesOpenDialogAction: Sendable {
    let backend: any BaseAppBackend
    let window: MainActorBox<Any?>

    /// Presents an 'Open files' dialog fit for selecting multiple files.
    ///
    /// - Parameters:
    ///   - title: The dialog's title. Defaults to "Open".
    ///   - message: The dialog's message. Defaults to an empty string.
    ///   - defaultButtonLabel: The label for the dialog's default button.
    ///     Defaults to "Open".
    ///   - initialDirectory: The directory to start the dialog in. Defaults
    ///     to `nil`, which lets the backend choose (usually it'll be the
    ///     app's current working directory and/or the directory where the
    ///     previous dialog was dismissed).
    ///   - showHiddenFiles: Whether to show hidden files. Defaults to `false`.
    ///   - allowSelectingMultiple: Whether to allow selecting multiple items.
    ///     Defaults to `true`.
    /// - Returns: The URLs of the user's chosen files, empty if the user
    ///   cancelled the dialog.
    public func callAsFunction(
        title: String = "Open",
        message: String = "",
        defaultButtonLabel: String = "Open",
        initialDirectory: URL? = nil,
        showHiddenFiles: Bool = false,
        allowSelectingMultiple: Bool = true
    ) async -> [URL] {
        guard let backend = backend as? any BackendFeatures.FileOpenDialogs else {
            logger.warnOnce("\(type(of: backend)) does not support file open dialogs")
            return []
        }

        func chooseFiles<Backend: BackendFeatures.FileOpenDialogs>(backend: Backend) async -> [URL] {
            await withCheckedContinuation { continuation in
                backend.runInMainThread {
                    let window = self.window.value.map { $0 as! Backend.Window }

                    backend.showOpenDialog(
                        fileDialogOptions: FileDialogOptions(
                            title: title,
                            defaultButtonLabel: defaultButtonLabel,
                            allowedContentTypes: [],
                            showHiddenFiles: showHiddenFiles,
                            allowOtherContentTypes: true,
                            initialDirectory: initialDirectory
                        ),
                        openDialogOptions: OpenDialogOptions(
                            allowSelectingFiles: true,
                            allowSelectingDirectories: false,
                            allowMultipleSelections: allowSelectingMultiple
                        ),
                        window: window
                    ) { result in
                        switch result {
                            case .success(let urls):
                                continuation.resume(returning: urls)
                            case .cancelled:
                                continuation.resume(returning: [])
                        }
                    }
                }
            }
        }
        return await chooseFiles(backend: backend)
    }
}
