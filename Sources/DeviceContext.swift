import Foundation

enum ThermalLevel: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    init(from systemState: ProcessInfo.ThermalState) {
        switch systemState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

struct DeviceSnapshot: Codable, Sendable {
    let timestamp: Date
    let thermalLevel: ThermalLevel
    let availableMemoryMB: Double
    let deviceModel: String
    let osVersion: String
}

enum DeviceContext {
    static func captureSnapshot() -> DeviceSnapshot {
        DeviceSnapshot(
            timestamp: Date(),
            thermalLevel: ThermalLevel(from: ProcessInfo.processInfo.thermalState),
            availableMemoryMB: availableMemoryMB,
            deviceModel: machineIdentifier,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    static var availableMemoryMB: Double {
        Double(os_proc_available_memory()) / 1_048_576.0
    }

    static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    static var marketingName: String {
        switch machineIdentifier {
        case "iPhone17,2": return "iPhone 16 Pro Max"
        default: return machineIdentifier
        }
    }
}