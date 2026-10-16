import AppKit
import Carbon.HIToolbox

/// System-wide ⌥⌘B that starts or stops a session. Carbon `RegisterEventHotKey` needs no
/// Accessibility permission (an `NSEvent` global monitor would). Copied from mac-calendar.
@MainActor
final class HotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    /// The C callback cannot capture, so it calls through this (one hotkey per app).
    private static var current: (() -> Void)?

    var action: (() -> Void)? {
        didSet { Self.current = action }
    }

    var isEnabled = false {
        didSet { if isEnabled != oldValue { isEnabled ? register() : unregister() } }
    }

    private func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.current?() }
            return noErr
        }, 1, &spec, nil, &handler)
        RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(cmdKey | optionKey),
                            EventHotKeyID(signature: OSType(0x4D42_5245), id: 1),  // "MBRE"
                            GetApplicationEventTarget(), 0, &hotKey)
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}
