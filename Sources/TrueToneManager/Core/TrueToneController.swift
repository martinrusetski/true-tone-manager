import CoreGraphics
import Foundation

protocol TrueToneControllerDelegate: AnyObject {
    func trueToneStateDidChange(enabled: Bool)
}

/// Abstraction over the system True Tone control surface.
///
/// `isSupported()` reports whether the hardware can ever do True Tone.
/// `isAvailable()` reports whether it can be controlled *right now* — this is
/// false when no True Tone-capable display is active (e.g. a MacBook running in
/// clamshell mode on a third-party external monitor).
protocol TrueToneSystemClient {
    func isSupported() -> Bool
    func isAvailable() -> Bool
    func getEnabled() -> Bool
    func setEnabled(_ enabled: Bool)
}

class TrueToneController {
    weak var delegate: TrueToneControllerDelegate?
    private let systemClient: TrueToneSystemClient
    private var cachedState: TrueToneState = .unknown

    init(systemClient: TrueToneSystemClient) {
        self.systemClient = systemClient
    }

    convenience init?() {
        guard let native = CBTrueToneClientNative() else {
            return nil
        }
        self.init(systemClient: native)
    }

    /// True Tone hardware exists on this machine.
    func isSupported() -> Bool {
        return systemClient.isSupported()
    }

    /// True Tone can be read/written right now (a capable display is active).
    func isAvailable() -> Bool {
        return systemClient.isSupported() && systemClient.isAvailable()
    }

    func getCurrentState() throws -> Bool {
        guard systemClient.isSupported() else {
            throw TrueToneControllerError.unsupportedHardware
        }

        let state = systemClient.getEnabled()
        cachedState = TrueToneState(bool: state)
        return state
    }

    func setTrueTone(enabled: Bool) throws {
        guard systemClient.isSupported() else {
            throw TrueToneControllerError.unsupportedHardware
        }
        guard systemClient.isAvailable() else {
            throw TrueToneControllerError.unavailable
        }

        if systemClient.getEnabled() == enabled {
            cachedState = TrueToneState(bool: enabled)
            return
        }

        systemClient.setEnabled(enabled)

        let actualState = systemClient.getEnabled()
        guard actualState == enabled else {
            throw TrueToneControllerError.stateVerificationFailed
        }

        cachedState = TrueToneState(bool: enabled)

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.trueToneStateDidChange(enabled: enabled)
        }
    }
}

/// Native implementation backed by the private `CBTrueToneClient` class in
/// CoreBrightness. `CBTrueToneClient` is the same global switch the
/// System Settings "True Tone" checkbox drives — it is not per-display.
///
/// Current-availability detection uses `DisplayServices`' ambient-light
/// compensation capability check (True Tone *is* ambient-light white-point
/// compensation) to tell whether any active display can actually do True Tone.
final class CBTrueToneClientNative: TrueToneSystemClient {
    private let client: NSObject
    private var coreBrightnessHandle: UnsafeMutableRawPointer?
    private var displayServicesHandle: UnsafeMutableRawPointer?

    private typealias HasAmbientLightCompensation = @convention(c) (UInt32) -> Bool
    private let hasAmbientLightCompensation: HasAmbientLightCompensation?

    init?() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_NOW
        ) else {
            return nil
        }
        coreBrightnessHandle = handle

        guard let cls = objc_lookUpClass("CBTrueToneClient") as? NSObject.Type else {
            return nil
        }
        client = cls.init()

        // DisplayServices is optional; if it is unavailable we fall back to
        // trusting CBTrueToneClient's own availability flag.
        if let ds = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        ) {
            displayServicesHandle = ds
            if let sym = dlsym(ds, "DisplayServicesHasAmbientLightCompensation") {
                hasAmbientLightCompensation = unsafeBitCast(sym, to: HasAmbientLightCompensation.self)
            } else {
                hasAmbientLightCompensation = nil
            }
        } else {
            hasAmbientLightCompensation = nil
        }
    }

    deinit {
        if let handle = displayServicesHandle {
            dlclose(handle)
        }
        if let handle = coreBrightnessHandle {
            dlclose(handle)
        }
    }

    func isSupported() -> Bool {
        return boolMethod("supported")
    }

    func isAvailable() -> Bool {
        guard boolMethod("available") else {
            return false
        }
        // If we can enumerate ambient-light capability, require at least one
        // active display that supports it. Otherwise trust `available`.
        guard let hasALC = hasAmbientLightCompensation else {
            return true
        }
        return anyActiveDisplay(satisfies: hasALC)
    }

    func getEnabled() -> Bool {
        return boolMethod("enabled")
    }

    func setEnabled(_ enabled: Bool) {
        let sel = NSSelectorFromString("setEnabled:")
        guard client.responds(to: sel) else { return }
        typealias Setter = @convention(c) (AnyObject, Selector, ObjCBool) -> Void
        let imp = client.method(for: sel)
        unsafeBitCast(imp, to: Setter.self)(client, sel, ObjCBool(enabled))
    }

    private func boolMethod(_ name: String) -> Bool {
        let sel = NSSelectorFromString(name)
        guard client.responds(to: sel) else { return false }
        typealias Getter = @convention(c) (AnyObject, Selector) -> ObjCBool
        let imp = client.method(for: sel)
        return unsafeBitCast(imp, to: Getter.self)(client, sel).boolValue
    }

    private func anyActiveDisplay(satisfies predicate: HasAmbientLightCompensation) -> Bool {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &displayIDs, &count) == .success else {
            return true
        }
        for index in 0..<Int(count) where predicate(displayIDs[index]) {
            return true
        }
        return false
    }
}
