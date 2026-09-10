import SwiftUI
import AppKit

extension Font {
    /// Premium geometric modernist typeface (Avenir Next) perfectly harmonized with the circular dot design language
    public static func premium(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black:
            return .custom("AvenirNext-Bold", size: size)
        case .semibold:
            return .custom("AvenirNext-DemiBold", size: size)
        case .medium:
            return .custom("AvenirNext-Medium", size: size)
        case .light, .ultraLight:
            return .custom("AvenirNext-UltraLight", size: size)
        default:
            return .custom("AvenirNext-Regular", size: size)
        }
    }
}

extension NSFont {
    /// Premium geometric modernist typeface (Avenir Next) for AppKit components
    public static func premium(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = "AvenirNext-Bold"
        case .semibold:
            fontName = "AvenirNext-DemiBold"
        case .medium:
            fontName = "AvenirNext-Medium"
        case .light, .ultraLight:
            fontName = "AvenirNext-UltraLight"
        default:
            fontName = "AvenirNext-Regular"
        }
        return NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
}
