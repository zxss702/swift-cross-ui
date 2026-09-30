/// How lines of text should be aligned relative to each other.
///
/// In SwiftCrossUI, multiline text alignment reuses ``HorizontalAlignment``.
public typealias TextAlignment = HorizontalAlignment

/// The weight of a font.
public typealias FontWeight = Font.Weight

/// The design of a font.
public typealias FontDesign = Font.Design

/// A key that identifies a localized string, as in SwiftUI.
///
/// SwiftCrossUI does not localize strings; this is a `String` so localized
/// keys can flow through APIs expecting the SwiftUI spelling.
public typealias LocalizedStringKey = String
