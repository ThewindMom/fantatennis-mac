import Foundation

public enum WindowsRuntimeKind: String, Sendable {
    case crossover = "CrossOver"
    case wine = "Wine"
}

public struct WindowsRuntime: Equatable, Sendable {
    public let kind: WindowsRuntimeKind
    public let executablePath: String
    public let bottleName: String?

    public init(kind: WindowsRuntimeKind, executablePath: String, bottleName: String?) {
        self.kind = kind
        self.executablePath = executablePath
        self.bottleName = bottleName
    }

    public var displayName: String {
        kind.rawValue
    }
}
