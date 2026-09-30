import Foundation

/// A view that presents a file importer when `isPresented` becomes true and
/// forwards the chosen URLs to `onCompletion`.
private struct FileImporterView<Content: View>: View {
    var content: Content
    var isPresented: Binding<Bool>
    var allowsMultipleSelection: Bool
    var onCompletion: (Result<[URL], Error>) -> Void

    @Environment(\.chooseFiles) var chooseFiles

    var body: some View {
        content.onChange(of: isPresented.wrappedValue) { _, presented in
            guard presented else { return }
            isPresented.wrappedValue = false
            Task { @MainActor in
                let urls = await chooseFiles(
                    allowSelectingMultiple: allowsMultipleSelection
                )
                onCompletion(.success(urls))
            }
        }
    }
}

extension View {
    /// Presents a file importer when `isPresented` is true.
    ///
    /// The importer is driven through the environment's file-dialog action
    /// (`EnvironmentValues/chooseFiles`); selected URLs are delivered to
    /// `onCompletion` and `isPresented` is reset.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that triggers the importer when set to
    ///     `true`.
    ///   - allowsMultipleSelection: Whether the user may pick several files.
    ///   - onCompletion: Called with the selected URLs, or an empty array on
    ///     cancellation.
    public func fileImporter(
        isPresented: Binding<Bool>,
        allowsMultipleSelection: Bool,
        onCompletion: @escaping (Result<[URL], Error>) -> Void
    ) -> some View {
        FileImporterView(
            content: self,
            isPresented: isPresented,
            allowsMultipleSelection: allowsMultipleSelection,
            onCompletion: onCompletion
        )
    }
}
