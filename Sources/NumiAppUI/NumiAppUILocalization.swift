import Foundation
import NumiCore

public enum NumiAppUILocalization {
    public static func registerBundle() {
        NumiLocalized.register(bundle: .module)
    }
}
