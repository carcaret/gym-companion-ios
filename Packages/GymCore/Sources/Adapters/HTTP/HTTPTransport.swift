import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Quien hace las peticiones HTTP. En la app, `URLSession`; en los tests, un servidor falso.
public protocol HTTPTransport: Sendable {
    /// El cuerpo y el código de la respuesta. Lanza si no hay respuesta (sin red...).
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

/// `URLSession` (en Linux, la de FoundationNetworking).
public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data ?? Data(), (response as? HTTPURLResponse)?.statusCode ?? 0))
                }
            }.resume()
        }
    }
}
