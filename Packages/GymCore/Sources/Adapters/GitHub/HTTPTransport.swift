import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Lo mínimo de HTTP que usan los adaptadores: inyectable para probarlos sin red.
public protocol HTTPTransport: Sendable {
    /// El cuerpo y el código de estado. Lanza solo si no hubo respuesta (sin red, timeout…).
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
