import Foundation

public enum UpdateManifestError: Error, CustomStringConvertible {
    case invalidLine(String)

    public var description: String {
        switch self {
        case let .invalidLine(line):
            "Invalid updater manifest line: \(line)"
        }
    }
}

public struct UpdateManifestEntry: Equatable, Sendable {
    public let windowsPath: String
    public let byteCount: Int
    public let md5: String

    public var relativePath: String {
        windowsPath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public init(windowsPath: String, byteCount: Int, md5: String) {
        self.windowsPath = windowsPath
        self.byteCount = byteCount
        self.md5 = md5.lowercased()
    }

    public init(line: String) throws {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count == 3, let byteCount = Int(parts[1]) else {
            throw UpdateManifestError.invalidLine(line)
        }
        self.init(windowsPath: String(parts[0]), byteCount: byteCount, md5: String(parts[2]))
    }
}

public struct UpdateManifest: Equatable, Sendable {
    public let entries: [UpdateManifestEntry]

    public var totalByteCount: Int {
        entries.reduce(0) { $0 + $1.byteCount }
    }

    public init(entries: [UpdateManifestEntry]) {
        self.entries = entries
    }

    public init(text: String) throws {
        let entries = try text
            .split(whereSeparator: \.isNewline)
            .map { try UpdateManifestEntry(line: String($0)) }
        self.init(entries: entries)
    }
}
