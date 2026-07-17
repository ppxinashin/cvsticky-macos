import Carbon
import Foundation

@MainActor
final class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in manager.action?() }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
    }

    func register(_ configuration: HotKeyConfiguration, action: @escaping () -> Void) {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        self.action = action
        let signature = OSType(0x43565354) // CVST
        let identifier = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
