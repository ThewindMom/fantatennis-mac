import Foundation

public enum EndpointState: String, Equatable, Sendable {
    case available
    case privateListing
    case missing
    case serverError
    case unexpected
}

public struct EndpointProbe: Equatable, Sendable {
    public let url: URL
    public let statusCode: Int
    public let state: EndpointState

    public init(url: URL, statusCode: Int) {
        self.url = url
        self.statusCode = statusCode
        self.state = Self.classify(statusCode: statusCode)
    }

    public static func classify(statusCode: Int) -> EndpointState {
        switch statusCode {
        case 200 ..< 300:
            .available
        case 403:
            .privateListing
        case 404:
            .missing
        case 500 ..< 600:
            .serverError
        default:
            .unexpected
        }
    }
}
