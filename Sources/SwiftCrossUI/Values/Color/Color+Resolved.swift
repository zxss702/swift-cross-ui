extension Color {
    /// A resolved RGBA color.
    public struct Resolved: Sendable, Equatable, Hashable, Codable {
        /// The red component (from 0 to 1).
        public var red: Float
        /// The green component (from 0 to 1).
        public var green: Float
        /// The blue component (from 0 to 1).
        public var blue: Float
        /// The alpha component (aka the opacity, from 0 to 1).
        public var opacity: Float

        /// Creates an instance.
        ///
        /// - Parameters:
        ///   - red: The red component.
        ///   - green: The green component.
        ///   - blue: The blue component.
        ///   - opacity: The alpha component (aka the opacity).
        public init(
            red: Float,
            green: Float,
            blue: Float,
            opacity: Float = 1.0
        ) {
            self.red = red
            self.green = green
            self.blue = blue
            self.opacity = opacity
        }

        /// The system red color.
        public static let systemRed = Resolved(red: 1, green: 0.231, blue: 0.188)
        /// The system green color.
        public static let systemGreen = Resolved(red: 0.157, green: 0.78, blue: 0.243)
        /// The system blue color.
        public static let systemBlue = Resolved(red: 0, green: 0.478, blue: 1)
        /// The system yellow color.
        public static let systemYellow = Resolved(red: 1, green: 0.8, blue: 0)
        /// The system orange color.
        public static let systemOrange = Resolved(red: 1, green: 0.584, blue: 0)
        /// The system purple color.
        public static let systemPurple = Resolved(red: 0.686, green: 0.322, blue: 0.871)
        /// The system pink color.
        public static let systemPink = Resolved(red: 1, green: 0.176, blue: 0.333)
        /// The system teal color.
        public static let systemTeal = Resolved(red: 0.188, green: 0.69, blue: 0.78)
        /// The system gray color.
        public static let systemGray = Resolved(red: 0.557, green: 0.557, blue: 0.576)
    }

    /// Resolves this color in the given environment.
    ///
    /// - Parameter environment: The environment.
    /// - Returns: The resolved color.
    @MainActor
    public func resolve(in environment: EnvironmentValues) -> Resolved {
        var resolvedColor =
            switch representation {
                case .rgb(let red, let green, let blue):
                    Resolved(red: Float(red), green: Float(green), blue: Float(blue))

                case .adaptive(let light, let dark):
                    switch environment.colorScheme {
                        case .light: light.resolve(in: environment)
                        case .dark: dark.resolve(in: environment)
                    }

                case .system(let systemColor):
                    if let backend = environment.backend as? any BackendFeatures.Colors {
                        backend.resolveAdaptiveColor(
                            systemColor,
                            in: environment
                        )
                    } else {
                        Color.defaultResolveAdaptiveColor(
                            systemColor,
                            in: environment
                        )
                    }
            }

        resolvedColor.opacity *= Float(self.opacityMultiplier)
        return resolvedColor
    }

    // NB: Also used in the default implementation for
    // `BackendFeatures.Colors.resolveAdaptiveColor(_:in:)`.
    @MainActor
    @_spi(Backends) public static func defaultResolveAdaptiveColor(
        _ adaptiveColor: Color.SystemAdaptive,
        in environment: EnvironmentValues
    ) -> Color.Resolved {
        let color: Color =
            switch adaptiveColor.kind {
                case .blue: .blue
                case .brown: .brown
                case .gray: .gray
                case .green: .green
                case .orange: .orange
                case .purple: .purple
                case .red: .red
                case .yellow: .yellow
            }

        return color.resolve(in: environment)
    }
}
