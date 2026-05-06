import SwiftCrossUI
import UIKit

final class RootViewController: UIViewController {
    unowned var backend: UIKitBackend
    var resizeHandler: ((CGSize) -> Void)?
    private var childWidget: (any WidgetProtocol)?

    #if os(visionOS)
        init(backend: UIKitBackend) {
            self.backend = backend
            super.init(nibName: nil, bundle: nil)

            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: RootViewController, _: UITraitCollection) in
                self.backend.onTraitCollectionChange?()
            }
        }
    #else
        init(backend: UIKitBackend) {
            self.backend = backend
            super.init(nibName: nil, bundle: nil)
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            let previous = previousTraitCollection?.userInterfaceStyle
            if UITraitCollection.current.userInterfaceStyle != previous {
                backend.onTraitCollectionChange?()
            }
        }
    #endif

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used for the root view controller")
    }

    override func viewWillTransition(
        to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        resizeHandler?(size)
        super.viewWillTransition(to: size, with: coordinator)
    }

    func setChild(to child: some WidgetProtocol) {
        childWidget?.removeFromParentWidget()
        child.removeFromParentWidget()

        let childController = child.controller
        view.addSubview(child.view)
        if let childController {
            addChild(childController)
            childController.didMove(toParent: self)
        }
        childWidget = child

        NSLayoutConstraint.activate([
            child.view.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor),
            child.view.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor),
        ])
    }
}

extension UIKitBackend {
    public typealias Surface = UIWindow

    public func createSurface(withDefaultSize _: SIMD2<Int>?) -> Surface {
        let window: UIWindow

        if !Self.hasReturnedAWindow {
            if let mainWindow = Self.mainWindow {
                window = mainWindow
            } else {
                window = UIWindow()
                Self.mainWindow = window
            }
            Self.hasReturnedAWindow = true
        } else {
            window = UIWindow()
        }

        #if !os(tvOS)
            window.backgroundColor = .systemBackground
        #endif

        window.rootViewController = RootViewController(backend: self)
        return window
    }

    public func updateSurface(_ surface: Surface, environment: EnvironmentValues) {
        // TODO(stackotter): Support preferredColorScheme
        surface.backgroundColor = switch environment.colorScheme {
            case .light: .white
            case .dark: .black
        }
    }

    public func setTitle(ofSurface surface: Surface, to title: String) {
        // I don't think this achieves much of anything but might as well
        surface.rootViewController!.title = title
    }

    public func setChild(ofSurface surface: Surface, to child: Widget) {
        let viewController = surface.rootViewController as! RootViewController
        viewController.setChild(to: child)
    }

    public func size(ofSurface surface: Surface) -> SIMD2<Int> {
        // For now, Views have no way to know where the safe area insets are, and the edges
        // of the screen could be obscured (e.g. covered by the notch). In the future we
        // might want to let users decide what to do, but for now, lie and say that the safe
        // area insets aren't even part of the window.
        // If/when this is updated, ``RootViewController`` and ``WidgetProtocolHelpers`` will
        // also need to be updated.
        let size = surface.safeAreaLayoutGuide.layoutFrame.size
        return SIMD2(Int(size.width), Int(size.height))
    }

    public func setResizeHandler(
        ofSurface surface: Surface,
        to action: @escaping (_ newSize: SIMD2<Int>) -> Void
    ) {
        let viewController = surface.rootViewController as! RootViewController
        viewController.resizeHandler = { size in
            action(SIMD2(Int(size.width), Int(size.height)))
        }
    }

    public func show(surface: Surface) {
        surface.makeKeyAndVisible()
    }

    public func isSurfaceProgrammaticallyResizable(_ surface: Surface) -> Bool {
        #if os(visionOS)
            true
        #else
            false
        #endif
    }

    public func setSize(ofSurface surface: Surface, to newSize: SIMD2<Int>) {
        #if os(visionOS)
            surface.bounds.size = CGSize(width: CGFloat(newSize.x), height: CGFloat(newSize.y))
        #else
            logger.notice(
                "ignoring \(#function) call",
                metadata: [
                    "currentWindowSize": "\(surface.bounds.width) x \(surface.bounds.height)",
                    "proposedWindowSize": "\(newSize.x) x \(newSize.y)",
                ]
            )
        #endif
    }

    public func setSizeLimits(
        ofSurface surface: Surface,
        minimum minimumSize: SIMD2<Int>,
        maximum maximumSize: SIMD2<Int>?
    ) {
        // if windowScene is nil, either the window isn't shown or it must be fullscreen
        // if sizeRestrictions is nil, the device doesn't support setting window size bounds
        surface.windowScene?.sizeRestrictions?.minimumSize =
            CGSize(width: minimumSize.x, height: minimumSize.y)
        surface.windowScene?.sizeRestrictions?.maximumSize =
            if let maximumSize {
                CGSize(width: maximumSize.x, height: maximumSize.y)
            } else {
                CGSize(width: Double.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            }
    }
}
