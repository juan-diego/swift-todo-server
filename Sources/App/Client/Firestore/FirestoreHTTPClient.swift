import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking // For URLSession on non-Apple platforms
#endif

/// Matches the Firestore error JSON payload returned in error responses.
///
/// Firestore error responses typically have the form:
/// ```json
/// {
///   "error": {
///     "code": 404,
///     "message": "Document not found",
///     "status": "NOT_FOUND"
///   }
/// }
/// ```
struct FirestoreErrorResponse: Decodable, Sendable {
    /// The Firestore error details contained in the response.
    struct ErrorBody: Decodable, Sendable {
        /// Numeric HTTP status code corresponding to the error.
        let code: Int?
        /// Human-readable error message describing the failure.
        let message: String?
        /// Error status string, e.g. "NOT_FOUND", "PERMISSION_DENIED".
        let status: String?
    }

    /// The top-level error object returned by Firestore.
    let error: ErrorBody?
}

/// Represents errors that can occur when interacting with Firestore over HTTP.
///
/// These errors cover malformed requests, authorization failures,
/// HTTP status errors, JSON encoding/decoding problems, and underlying network errors.
enum FirestoreHTTPError: Error, Sendable {
    /// The URL constructed for the request was invalid.
    case invalidURL
    /// The request was unauthorized due to missing or invalid credentials.
    ///
    /// - Parameter message: Optional detailed error message from Firestore.
    case unauthorized(message: String?)
    /// The requested resource was not found.
    ///
    /// - Parameter message: Optional detailed error message from Firestore.
    case notFound(message: String?)
    /// A server-side error occurred with an unexpected HTTP status code.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by the server.
    ///   - message: Optional detailed error message from Firestore.
    case serverError(statusCode: Int, message: String?)
    /// An error occurred encoding the request body JSON.
    ///
    /// - Parameter encodingError: The underlying Swift `EncodingError`.
    case encodingError(EncodingError)
    /// An error occurred decoding the response body JSON.
    ///
    /// - Parameter decodingError: The underlying Swift `DecodingError`.
    case decodingError(DecodingError)
    /// A network-level error occurred during the HTTP request.
    ///
    /// - Parameter underlying: The underlying error from URLSession or the network stack.
    case networkError(underlying: Error)
}

/// A Firestore REST API HTTP client.
///
/// This client handles constructing request URLs, setting headers including
/// OAuth2 bearer tokens, sending HTTP requests, and decoding JSON responses.
/// It supports both requests with and without JSON bodies, handles error
/// decoding according to Firestore's error format, and wraps errors in
/// `FirestoreHTTPError` for better error handling.
///
/// The client is designed to be used safely with Swift concurrency (`Sendable`).
struct FirestoreHTTPClient: Sendable {
    /// Firestore configuration including API root and timeouts.
    let config: FirestoreConfig
    /// Provider for OAuth2 access tokens.
    let tokenProvider: AccessTokenProvider
    /// URL session used to perform HTTP requests.
    let urlSession: URLSession

    /// Initializes a new Firestore HTTP client.
    ///
    /// - Parameters:
    ///   - config: Configuration including base API URL and timeout.
    ///   - tokenProvider: Provides OAuth2 tokens for authorization.
    ///   - urlSession: The URLSession instance to use. Defaults to `.shared`.
    init(config: FirestoreConfig,
         tokenProvider: AccessTokenProvider,
         urlSession: URLSession = .shared) {
        self.config = config
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
    }

    /// Sends an HTTP request without a JSON body (e.g. GET, DELETE).
    ///
    /// - Parameters:
    ///   - method: The HTTP method to use, such as `"GET"` or `"DELETE"`.
    ///   - path: The Firestore REST API path, relative to the base URL.
    ///   - queryItems: Optional URL query parameters.
    ///
    /// - Returns: The decoded response body of type `ResponseBody`.
    ///
    /// - Throws: `FirestoreHTTPError` on HTTP errors, encoding/decoding failures, or network issues.
    func send<ResponseBody: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> ResponseBody {
        let url = try buildURL(path: path, queryItems: queryItems)
        return try await execute(method: method, url: url, bodyData: nil)
    }

    /// Sends an HTTP request with a JSON-encoded body (e.g. POST, PATCH).
    ///
    /// - Parameters:
    ///   - method: The HTTP method to use, such as `"POST"` or `"PATCH"`.
    ///   - path: The Firestore REST API path, relative to the base URL.
    ///   - queryItems: Optional URL query parameters.
    ///   - body: The request body to encode as JSON.
    ///
    /// - Returns: The decoded response body of type `ResponseBody`.
    ///
    /// - Throws: `FirestoreHTTPError` on encoding failures, HTTP errors,
    ///   decoding failures, or network errors.
    func send<RequestBody: Encodable, ResponseBody: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: RequestBody
    ) async throws -> ResponseBody {
        let url = try buildURL(path: path, queryItems: queryItems)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch (let encodeError as EncodingError) {
            throw FirestoreHTTPError.encodingError(encodeError)
        } catch {
            throw FirestoreHTTPError.networkError(underlying: error)
        }

        return try await execute(method: method, url: url, bodyData: bodyData)
    }

    /// Builds a full URL by appending the given path and query items to the base API root.
    ///
    /// - Parameters:
    ///   - path: The relative API path.
    ///   - queryItems: Optional URL query parameters.
    ///
    /// - Returns: A fully qualified URL for the Firestore REST API request.
    ///
    /// - Throws: `FirestoreHTTPError.invalidURL` if URL construction fails.
    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: config.apiRoot, resolvingAgainstBaseURL: false) else {
            throw FirestoreHTTPError.invalidURL
        }

        // Ensure exactly one slash between base and path
        if path.hasPrefix("/") {
            components.path += path
        } else {
            components.path += "/\(path)"
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw FirestoreHTTPError.invalidURL
        }

        return url
    }

    /// Executes the HTTP request and decodes the response body.
    ///
    /// - Parameters:
    ///   - method: The HTTP method (e.g., "GET", "POST").
    ///   - url: The target request URL.
    ///   - bodyData: Optional JSON-encoded request body data.
    ///
    /// - Returns: The decoded response body of type `ResponseBody`.
    ///
    /// - Throws: `FirestoreHTTPError` for HTTP errors, decoding failures,
    ///   or network errors.
    private func execute<ResponseBody: Decodable>(
        method: String,
        url: URL,
        bodyData: Data?
    ) async throws -> ResponseBody {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = config.timeoutInterval

        // Headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if bodyData != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Authorization: Bearer <token>
        if let token = try await tokenProvider.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = bodyData

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw FirestoreHTTPError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirestoreHTTPError.serverError(statusCode: -1, message: "Received a non-HTTP response.")
        }

        let statusCode = httpResponse.statusCode

        // Handle non-2xx statuses with error decoding
        guard (200...299).contains(statusCode) else {
            let message = getErrorResponses(data)?
                .compactMap(\.error?.message)
                .joined(separator: ". ")
                .appending(". ")

            switch statusCode {
            case 401, 403:
                throw FirestoreHTTPError.unauthorized(message: message)
            case 404:
                throw FirestoreHTTPError.notFound(message: message)
            default:
                throw FirestoreHTTPError.serverError(statusCode: statusCode, message: message)
            }
        }

        // Decode success body
        // For endpoints returning `{}`, you can use a dedicated EmptyResponse: Decodable type.
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        do {
            return try decoder.decode(ResponseBody.self, from: data)
        } catch let decodeError as DecodingError {
            throw FirestoreHTTPError.decodingError(decodeError)
        } catch {
            throw FirestoreHTTPError.networkError(underlying: error)
        }
    }
    
    /// Attempts to decode Firestore error response(s) from the provided JSON data.
    ///
    /// This helper tries both array and single-object decoding:
    /// - If the data is an array of error responses, it returns all decoded errors.
    /// - If the data is a single error response, it wraps it in an array.
    ///
    /// - Parameter data: The raw HTTP response data to parse as Firestore error response(s).
    /// - Returns: An array of decoded `FirestoreErrorResponse` objects if parsing succeeds;
    ///   otherwise returns `nil` if the data doesn't match expected error formats.
    private func getErrorResponses(_ data: Data) -> [FirestoreErrorResponse]? {
        if let errorResponses = try? JSONDecoder().decode([FirestoreErrorResponse].self, from: data) {
            return errorResponses
        } else if let errorResponse = try? JSONDecoder().decode(FirestoreErrorResponse.self, from: data) {
            return [errorResponse]
        }
        return nil
    }
}
