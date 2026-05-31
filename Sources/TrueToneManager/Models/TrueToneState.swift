enum TrueToneState {
    case enabled
    case disabled
    case unknown

    var boolValue: Bool? {
        switch self {
        case .enabled: return true
        case .disabled: return false
        case .unknown: return nil
        }
    }

    init(bool: Bool?) {
        switch bool {
        case .some(true): self = .enabled
        case .some(false): self = .disabled
        case .none: self = .unknown
        }
    }
}
