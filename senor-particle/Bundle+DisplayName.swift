import Foundation

extension Bundle {
    /// User-facing app name from `CFBundleDisplayName`, falling back to `CFBundleName`.
    var displayName: String {
        return self.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? self.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
    }
}
