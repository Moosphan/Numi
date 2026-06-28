import Foundation

public extension Date {
    func numiFormatted(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(NumiLocalized.currentLocale))
    }

    func numiTimeText() -> String {
        numiFormatted(.dateTime.hour().minute())
    }
}
