import Foundation

/// Pagination token for in-memory todo repository paging.
///
/// `MemoryTodoPageToken` encodes and decodes pagination state as an offset integer for use with `TodoMemoryRepository`. The token is serialized as a base64-encoded string of the integer offset.
struct MemoryTodoPageToken: PageToken {
    /// The cursor value representing the offset in the results.
    typealias Cursor = Int
    /// The encoded token type (base64-encoded `String`).
    typealias Token = String

    /// The offset representing the pagination state.
    let cursor: Int

    /// Constructs a token from the integer offset.
    /// - Parameter cursor: The offset into the results.
    init(cursor: Int) {
        self.cursor = cursor
    }

    /// Attempts to decode an offset from the encoded token.
    /// - Parameter pageToken: Base64-encoded string of the integer offset.
    /// - Returns: An instance if decoding succeeds, or `nil` if invalid.
    init?(pageToken: String) {
        guard let decodedData = Data(base64Encoded: pageToken),
              let offsetString = String(data: decodedData, encoding: .utf8),
              let decodedOffset = Int(offsetString)
        else {
            return nil
        }
        cursor = decodedOffset
    }

    /// The base64-encoded string representation of the offset, suitable for use as a pagination token.
    var pageToken: String? {
        if let encodedToken = String(cursor).data(using: .utf8)?.base64EncodedString() {
            return encodedToken
        } else {
            return nil
        }
    }
}

