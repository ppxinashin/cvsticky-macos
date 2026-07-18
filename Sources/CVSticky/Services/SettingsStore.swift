import AppKit
import Foundation
import Security

@MainActor
final class SettingsStore: NSObject, ObservableObject {
    @Published var appearance: AppearanceMode { didSet { persistAndApply() } }
    @Published var followsSystemAccent: Bool { didSet { persist() } }
    @Published var accentHex: String { didSet { persist() } }
    @Published var hotKey: HotKeyConfiguration { didSet { persist() } }
    @Published var ai: AIConfiguration { didSet { persist() } }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        let localDecoder = JSONDecoder()
        appearance = AppearanceMode(rawValue: defaults.string(forKey: "appearance") ?? "system") ?? .system
        followsSystemAccent = defaults.bool(forKey: "followsSystemAccent")
        accentHex = defaults.string(forKey: "accentHex") ?? "#0A84FF"
        hotKey = defaults.data(forKey: "hotKey")
            .flatMap { try? localDecoder.decode(HotKeyConfiguration.self, from: $0) }
            ?? HotKeyConfiguration()
        var savedAI = defaults.data(forKey: "aiConfiguration")
            .flatMap { try? localDecoder.decode(AIConfiguration.self, from: $0) }
            ?? AIConfiguration()
        savedAI.apiKey = KeychainStore.read(service: "CVSticky", account: "ai_api_key") ?? ""
        ai = savedAI
        super.init()
        applyAppearance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemColorsDidChange),
            name: NSColor.systemColorsDidChangeNotification,
            object: nil
        )
    }

    func updateAI(_ configuration: AIConfiguration) {
        ai = configuration
        if configuration.apiKey.isEmpty {
            KeychainStore.delete(service: "CVSticky", account: "ai_api_key")
        } else {
            KeychainStore.save(configuration.apiKey, service: "CVSticky", account: "ai_api_key")
        }
    }

    var accentColor: NSColor {
        followsSystemAccent ? .controlAccentColor : (NSColor(hex: accentHex) ?? .controlAccentColor)
    }

    var effectiveAccentHex: String {
        accentColor.hexString ?? accentHex
    }

    @objc private func systemColorsDidChange() {
        guard followsSystemAccent else { return }
        objectWillChange.send()
    }

    private func persistAndApply() {
        persist()
        applyAppearance()
    }

    private func persist() {
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(followsSystemAccent, forKey: "followsSystemAccent")
        defaults.set(accentHex, forKey: "accentHex")
        defaults.set(try? encoder.encode(hotKey), forKey: "hotKey")
        var safeAI = ai
        safeAI.apiKey = ""
        defaults.set(try? encoder.encode(safeAI), forKey: "aiConfiguration")
    }

    private func applyAppearance() {
        switch appearance {
        case .system: NSApplication.shared.appearance = nil
        case .light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum KeychainStore {
    static func save(_ value: String, service: String, account: String) {
        delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = UInt64(clean, radix: 16) else { return nil }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }
}
