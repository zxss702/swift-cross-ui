/// Holds the view graph and window handle for a single window.
@MainActor
final class WindowReference<SceneType: WindowingScene> {
    /// The scene.
    private var scene: SceneType
    /// The view graph of the window's root view.
    private let viewGraph: ViewGraph<SceneType.Content>
    /// The window being rendered in.
    let window: Any
    /// `false` after the first scene update.
    private var isFirstUpdate = true
    /// The cached window size. Nil on first run or after a window is resized.
    private var cachedWindowSize: SIMD2<Int>?
    /// The environment most recently provided by this node's parent scene.
    private var parentEnvironment: EnvironmentValues
    /// The container used to center the root view in the window.
    private let containerWidget: AnyWidget
    /// The window's preferred color scheme, cached from the last update.
    private var preferredColorScheme: ColorScheme?
    /// Window min/max layout probes are expensive on large navigation trees.
    /// They only need to be recomputed when content or environment inputs may
    /// have changed, not for every intermediate frame of a user resize.
    private var cachedMinimumWindowSize: ViewSize?
    private var cachedMaximumWindowSize: ViewSize?
    private var pendingResizeSize: SIMD2<Int>?
    private var hasScheduledResizeUpdate = false

    /// - Parameters:
    ///   - closeHandler: The action to perform when the window is closed. Should
    ///     dispose of the scene's reference to this `WindowReference`.
    init<Backend: BaseAppBackend>(
        scene: SceneType,
        backend: Backend,
        environment: EnvironmentValues,
        onClose closeHandler: @escaping @Sendable @MainActor () -> Void
    ) {
        self.scene = scene
        let window = backend.createSurface(withDefaultSize: environment.defaultWindowSize)

        viewGraph = ViewGraph(
            for: scene.content(),
            backend: backend,
            environment: environment.with(\.window, window)
        )
        let rootWidget = viewGraph.rootNode.concreteNode(for: Backend.self).widget

        let container = backend.createContainer()
        backend.insert(rootWidget, into: container, at: 0)
        self.containerWidget = AnyWidget(container)

        backend.setChild(ofSurface: window, to: container)

        self.window = window
        WindowManager.shared.registerSurface(window)
        parentEnvironment = environment

        backend.setCloseHandler(ofSurface: window) { [weak self] in
            guard let self else { return }
            WindowManager.shared.unregisterSurface(self.window)
            closeHandler()
        }

        backend.setResizeHandler(ofSurface: window) { [weak self] newSize in
            guard let self else { return }
<<<<<<< Updated upstream
            self.update(
                self.scene,
                proposedWindowSize: newSize,
                needsWindowSizeCommit: false,
                backend: backend,
                environment: self.parentEnvironment,
                windowSizeIsFinal:
                    !backend.isWindowProgrammaticallyResizable(window)
            )
        }

        backend.setWindowEnvironmentChangeHandler(of: window) { [weak self] in
            guard let self else { return }
            self.update(
                self.scene,
                proposedWindowSize: backend.size(ofWindow: window),
                needsWindowSizeCommit: false,
                backend: backend,
                environment: self.parentEnvironment,
                windowSizeIsFinal:
                    !backend.isWindowProgrammaticallyResizable(window)
            )
        }
=======
            guard !self.isFirstUpdate else {
                return
            }
            self.pendingResizeSize = newSize
            guard !self.hasScheduledResizeUpdate else {
                return
            }
            self.hasScheduledResizeUpdate = true

            let transaction = TransactionContext.current
            let delay = 1.0 / max(backend.preferredFramesPerSecond, 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, backend] in
                guard let self else {
                    return
                }
                self.hasScheduledResizeUpdate = false
                guard let size = self.pendingResizeSize else {
                    return
                }
                self.pendingResizeSize = nil
                self.enqueueUpdate(
                    backend: backend,
                    transaction: transaction,
                    key: "window-resize"
                ) {
                    self.update(
                        self.scene,
                        proposedWindowSize: size,
                        needsWindowSizeCommit: false,
                        backend: backend,
                        environment: self.parentEnvironment,
                        windowSizeIsFinal:
                            !backend.isSurfaceProgrammaticallyResizable(window),
                        recomputeWindowSizeLimits: false
                    )
                }
            }
        }

>>>>>>> Stashed changes
    }

    func update<Backend: BaseAppBackend>(
        _ newScene: SceneType?,
        backend: Backend,
        environment: EnvironmentValues
    ) {
        guard let window = window as? Backend.Surface else {
            fatalError("Scene updated with a backend incompatible with the window it was given")
        }

        let isProgramaticallyResizable =
            backend.isSurfaceProgrammaticallyResizable(window)

        let proposedWindowSize: SIMD2<Int>
        let usedDefaultSize: Bool
        if isFirstUpdate && isProgramaticallyResizable {
            proposedWindowSize = environment.defaultWindowSize
            usedDefaultSize = true
        } else {
<<<<<<< Updated upstream
            proposedWindowSize = cachedWindowSize ?? backend.size(ofWindow: window)
=======
            proposedWindowSize = backend.size(ofSurface: window)
>>>>>>> Stashed changes
            usedDefaultSize = false
        }

        update(
            newScene,
            proposedWindowSize: proposedWindowSize,
            needsWindowSizeCommit: usedDefaultSize,
            backend: backend,
            environment: environment,
            windowSizeIsFinal: !isProgramaticallyResizable
        )
    }

    /// Updates the `WindowReference`.
    /// - Parameters:
    ///   - newScene: The scene. `nil` if reusing previous scene value.
    ///   - proposedWindowSize: The proposed window size.
    ///   - needsWindowSizeCommit: Whether the proposed window size matches the
    ///     windows current size (or imminent size in the case of a window
    ///     resize). We use this parameter instead of comparing to the window's
    ///     current size to the proposed size, because some backends (such as
    ///     AppKitBackend) trigger window resize handlers *before* the underlying
    ///     window gets assigned its new size (allowing us to pre-emptively update the
    ///     window's content to match the new size).
    ///   - backend: The backend to use.
    ///   - environment: The current environment.
    ///   - windowSizeIsFinal: If true, no further resizes can/will be made. This
    ///     is true on platforms that don't support programmatic window resizing,
    ///     and when a window is full screen.
    private func update<Backend: BaseAppBackend>(
        _ newScene: SceneType?,
        proposedWindowSize: SIMD2<Int>,
        needsWindowSizeCommit: Bool,
        backend: Backend,
        environment: EnvironmentValues,
        windowSizeIsFinal: Bool = false
    ) {
        update(
            newScene,
            proposedWindowSize: proposedWindowSize,
            needsWindowSizeCommit: needsWindowSizeCommit,
            backend: backend,
            environment: environment,
            windowSizeIsFinal: windowSizeIsFinal,
            recomputeWindowSizeLimits: true
        )
    }

    private func update<Backend: BaseAppBackend>(
        _ newScene: SceneType?,
        proposedWindowSize: SIMD2<Int>,
        needsWindowSizeCommit: Bool,
        backend: Backend,
        environment: EnvironmentValues,
        windowSizeIsFinal: Bool = false,
        recomputeWindowSizeLimits: Bool
    ) {
        guard let window = window as? Backend.Surface else {
            fatalError("Scene updated with a backend incompatible with the window it was given")
        }

        parentEnvironment = environment

        if let newScene {
            // Don't set default size even if it has changed. We only set that once
            // at window creation since some backends don't have a concept of
            // 'default' size which would mean that setting the default size every time
            // the default size changed would resize the window (which is incorrect
            // behaviour).
            scene = newScene
        }

        var environment =
<<<<<<< Updated upstream
            backend.computeWindowEnvironment(
                window: window,
                rootEnvironment: environment.with(\.window, window)
            )
=======
            environment
            .with(\.window, window)
            .with(\.graphUpdateHost, viewGraph.updateHost)
>>>>>>> Stashed changes
            .with(\.onResize) { [weak self] _ in
                guard let self else { return }
                self.cachedWindowSize = nil
                // TODO: Figure out whether this would still work if we didn't recompute the
                //   scene's body. I have a vague feeling that it wouldn't work in all cases?
                //   But I don't have the time to come up with a counterexample right now.
                self.update(
                    self.scene,
                    proposedWindowSize: backend.size(ofWindow: window),
                    needsWindowSizeCommit: false,
                    backend: backend,
<<<<<<< Updated upstream
                    environment: environment
                )
            }
=======
                    transaction: transaction,
                    key: "window-content-resize"
                ) {
                    self.update(
                        self.scene,
                        proposedWindowSize: backend.size(ofSurface: window),
                        needsWindowSizeCommit: false,
                        backend: backend,
                        environment: environment.withCurrentTransaction(transaction)
                    )
                }
        }
>>>>>>> Stashed changes
        let outerColorScheme = environment.colorScheme

        // Update environment with latest cached value before first update to
        // minimise toggling between outer color scheme and preferred color
        // scheme where possible (could confuse people when logging the color
        // scheme or debugging things)
        if let preferredColorScheme {
            environment.colorScheme = preferredColorScheme
        }

<<<<<<< Updated upstream
        let probingResult = viewGraph.computeLayout(
            with: newScene?.content(),
            proposedSize: .zero,
            environment: environment
                .with(\.allowLayoutCaching, true)
        )
        let minimumWindowSize = probingResult.size
        updateEnvironment(
            &environment,
            viewLayoutResult: probingResult,
            outerColorScheme: outerColorScheme,
            backend: backend
        )
=======
        let content = self.observe(in: backend) { newScene?.content() }
        let shouldRecomputeSizeLimits =
            recomputeWindowSizeLimits || cachedMinimumWindowSize == nil
        let minimumWindowSize: ViewSize
        if shouldRecomputeSizeLimits {
            let probingResult = viewGraph.computeLayout(
                with: content,
                proposedSize: .zero,
                environment: environment
                    .with(\.allowLayoutCaching, true)
            )
            minimumWindowSize = probingResult.size
            cachedMinimumWindowSize = minimumWindowSize
            updateEnvironment(
                &environment,
                viewLayoutResult: probingResult,
                outerColorScheme: outerColorScheme,
                backend: backend
            )
        } else {
            minimumWindowSize = cachedMinimumWindowSize!
        }
>>>>>>> Stashed changes

        // With `.contentSize`, the window's maximum size is the maximum size of its
        // content. With `.contentMinSize` (and `.automatic`), there is no maximum
        // size.
        let maximumWindowSize: ViewSize?
        switch environment.windowResizability {
            case .contentSize:
                if shouldRecomputeSizeLimits || cachedMaximumWindowSize == nil {
                    let result = viewGraph.computeLayout(
                        with: newScene?.content(),
                        proposedSize: .infinity,
                        environment: environment.with(\.allowLayoutCaching, true)
                    )
                    updateEnvironment(
                        &environment,
                        viewLayoutResult: result,
                        outerColorScheme: outerColorScheme,
                        backend: backend
                    )
                    maximumWindowSize = result.size
                    cachedMaximumWindowSize = maximumWindowSize
                } else {
                    maximumWindowSize = cachedMaximumWindowSize
                }
            case .automatic, .contentMinSize:
                cachedMaximumWindowSize = nil
                maximumWindowSize = nil
        }

        let clampedWindowSize = ViewSize(
            min(
                maximumWindowSize?.width ?? .infinity,
                max(minimumWindowSize.width, Double(proposedWindowSize.x))
            ),
            min(
                maximumWindowSize?.height ?? .infinity,
                max(minimumWindowSize.height, Double(proposedWindowSize.y))
            )
        )

        if clampedWindowSize.vector != proposedWindowSize && !windowSizeIsFinal {
            // Restart the window update if the content has caused the window to
            // change size.
            return update(
                scene,
                proposedWindowSize: clampedWindowSize.vector,
                needsWindowSizeCommit: true,
                backend: backend,
                environment: environment,
                windowSizeIsFinal: true,
                recomputeWindowSizeLimits: false
            )
        }

        if shouldRecomputeSizeLimits || needsWindowSizeCommit {
            // Set these even if the window isn't programmatically resizable
            // because the window may still be user resizable.
            backend.setSizeLimits(
                ofSurface: window,
                minimum: minimumWindowSize.vector,
                maximum: maximumWindowSize?.vector
            )
        }

        let finalContentResult = viewGraph.computeLayout(
            proposedSize: ProposedViewSize(proposedWindowSize),
            environment: environment
        )
        updateEnvironment(
            &environment,
            viewLayoutResult: finalContentResult,
            outerColorScheme: outerColorScheme,
            backend: backend
        )

        backend.setPosition(
            ofChildAt: 0,
            in: containerWidget.into(),
            to: (proposedWindowSize &- finalContentResult.size.vector) / 2
        )

        if needsWindowSizeCommit {
            backend.setSize(ofSurface: window, to: proposedWindowSize)
        }
        cachedWindowSize = proposedWindowSize

        let shouldUpdateWindowChrome =
            recomputeWindowSizeLimits || needsWindowSizeCommit || isFirstUpdate

<<<<<<< Updated upstream
=======
        if shouldUpdateWindowChrome,
            let backend = backend as? any BackendFeatures.WindowToolbars
        {
            func setToolbar<NewBackend: BackendFeatures.WindowToolbars>(backend: NewBackend) {
                backend.setToolbar(
                    ofSurface: window as! NewBackend.Surface,
                    to: finalContentResult.preferences.toolbar,
                    navigationTitle: finalContentResult.preferences.navigationTitle,
                    environment: environment
                )
            }
            setToolbar(backend: backend)
        }

>>>>>>> Stashed changes
        // Generally just used to update the window color scheme
        backend.updateSurface(window, environment: environment)

        // Delay committing the view graph so that the View.inspectWindow(_:)
        // modifiers can be used to overwrite certain SwiftCrossUI behaviors
        viewGraph.commit()

        if isFirstUpdate {
            backend.show(surface: window)
            isFirstUpdate = false
        }
    }

    func activate<Backend: BaseAppBackend>(backend: Backend) {
        guard let window = window as? Backend.Surface else {
            fatalError("Scene updated with a backend incompatible with the window it was given")
        }

        // activate() has been removed from the backend protocol.
    }

    private func updateEnvironment<Backend: BaseAppBackend>(
        _ environment: inout EnvironmentValues,
        viewLayoutResult: ViewLayoutResult,
        outerColorScheme: ColorScheme,
        backend: Backend
    ) {
        preferredColorScheme = viewLayoutResult.preferences.preferredColorScheme

        // Update environment with preferred color scheme if provided
        if let preferredColorScheme, backend.canOverrideWindowColorScheme {
            environment.colorScheme = preferredColorScheme
        } else {
            // If the preferred color scheme just changed to nil, then we must
            // reset the environment's color scheme to the outer color scheme
            // provided by a higher scene or the system.
            environment.colorScheme = outerColorScheme
        }
    }
}
