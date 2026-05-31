import Foundation

protocol TrueToneControllerDelegate: AnyObject {
    func trueToneStateDidChange(enabled: Bool)
}

protocol TrueToneSystemClient {
    func getBlueLightStatus(_ completion: @escaping (Bool) -> Void)
    func setBlueLightEnabled(_ enabled: Bool)
    func isSupported() -> Bool
}

class TrueToneController {
    weak var delegate: TrueToneControllerDelegate?
    private let systemClient: TrueToneSystemClient
    private var cachedState: TrueToneState = .unknown

    init(systemClient: TrueToneSystemClient) {
        self.systemClient = systemClient
    }

    convenience init?() {
        guard let native = CBBlueLightClientNative() else {
            return nil
        }
        self.init(systemClient: native)
    }

    func getCurrentState() throws -> Bool {
        guard systemClient.isSupported() else {
            throw TrueToneControllerError.unsupportedHardware
        }

        var result: Bool = false
        var finished = false

        let queue = DispatchQueue(label: "com.truetonemanager.corebrightness")
        queue.async {
            self.systemClient.getBlueLightStatus { enabled in
                result = enabled
                finished = true
            }
        }

        let deadline = Date().addingTimeInterval(3.0)
        while !finished && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            if finished { break }
        }

        if finished {
            cachedState = TrueToneState(bool: result)
            return result
        }

        return cachedState.boolValue ?? false
    }

    func setTrueTone(enabled: Bool) throws {
        guard systemClient.isSupported() else {
            throw TrueToneControllerError.unsupportedHardware
        }

        let currentState = try getCurrentState()
        if currentState == enabled {
            return
        }

        systemClient.setBlueLightEnabled(enabled)

        let actualState = try getCurrentState()
        guard actualState == enabled else {
            throw TrueToneControllerError.stateVerificationFailed
        }

        cachedState = TrueToneState(bool: enabled)

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.trueToneStateDidChange(enabled: enabled)
        }
    }

    func isSupported() -> Bool {
        return systemClient.isSupported()
    }
}

final class CBBlueLightClientNative: TrueToneSystemClient {
    private let blueLightClient: NSObject?
    private let adaptationClient: NSObject?
    private var frameworkHandle: UnsafeMutableRawPointer?

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW) else {
            return nil
        }
        frameworkHandle = handle

        if let cls = objc_lookUpClass("CBBlueLightClient") as? NSObject.Type {
            blueLightClient = cls.init()
        } else {
            blueLightClient = nil
        }

        if let cls = objc_lookUpClass("CBAdaptationClient") as? NSObject.Type {
            adaptationClient = cls.init()
        } else {
            adaptationClient = nil
        }
    }

    deinit {
        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }

    func isSupported() -> Bool {
        return adaptationClient != nil || blueLightClient != nil
    }

    func getBlueLightStatus(_ completion: @escaping (Bool) -> Void) {
        if let client = adaptationClient {
            let sel = NSSelectorFromString("getEnabled")
            if client.responds(to: sel) {
                let imp = client.method(for: sel)
                typealias Func = @convention(c) (AnyObject, Selector) -> ObjCBool
                let enabled = unsafeBitCast(imp, to: Func.self)(client, sel)
                completion(enabled.boolValue)
                return
            }
        }

        if let client = blueLightClient {
            let selector = NSSelectorFromString("getBlueLightStatus:")
            if client.responds(to: selector) {
                let block: @convention(block) (UInt64, ObjCBool, ObjCBool) -> Void = { _, enabled, _ in
                    completion(enabled.boolValue)
                }
                let imp = client.method(for: selector)
                typealias Func = @convention(c) (AnyObject, Selector, @convention(block) (UInt64, ObjCBool, ObjCBool) -> Void) -> Void
                unsafeBitCast(imp, to: Func.self)(client, selector, block)
                return
            }
        }

        completion(false)
    }

    func setBlueLightEnabled(_ enabled: Bool) {
        if let client = adaptationClient {
            let sel = NSSelectorFromString("setEnabled:")
            if client.responds(to: sel) {
                let imp = client.method(for: sel)
                typealias Func = @convention(c) (AnyObject, Selector, ObjCBool) -> Void
                unsafeBitCast(imp, to: Func.self)(client, sel, ObjCBool(enabled))
                return
            }
        }

        if let client = blueLightClient {
            let selector = NSSelectorFromString("setBlueLightEnabled:")
            if client.responds(to: selector) {
                let imp = client.method(for: selector)
                typealias Func = @convention(c) (AnyObject, Selector, ObjCBool) -> Void
                unsafeBitCast(imp, to: Func.self)(client, selector, ObjCBool(enabled))
            }
        }
    }
}
