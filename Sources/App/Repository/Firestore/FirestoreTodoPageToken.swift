import Foundation

/// Pagination token for Firestore-based todo repository paging.
///
/// `FirestoreTodoPageToken` encodes and decodes a Firestore query cursor
/// ("order" and Firestore document name) as a base64-encoded JSON string.
/// Used by `TodoFirestoreRepository` for cursor-based pagination in Firestore queries.
struct FirestoreTodoPageToken: PageToken {
    /// Cursor representing Firestore pagination state: order and document name.
    struct QueryCursor: Codable {
        /// The integer sort order of the last item on the current page.
        let order: Int
        /// The full Firestore document name of the last item on the current page.
        let documentName: String
    }

    /// The decoded cursor value for this token.
    typealias Cursor = QueryCursor
    /// The encoded token type (base64-encoded JSON `String`).
    typealias Token = String

    /// The Firestore query cursor used for pagination.
    let cursor: QueryCursor

    /// Constructs a token from the Firestore query cursor.
    /// - Parameter cursor: The cursor containing the order and document name.
    init(cursor: QueryCursor) {
        self.cursor = cursor
    }

    /// Attempts to decode a cursor from the encoded token.
    /// - Parameter pageToken: Base64-encoded JSON string representing the cursor.
    /// - Returns: An instance if decoding succeeds, or `nil` if invalid.
    init?(pageToken: String) {
        guard let decodedData = Data(base64Encoded: pageToken),
              let decodedCursor = try? JSONDecoder().decode(Cursor.self, from: decodedData)
        else {
            return nil
        }
        cursor = decodedCursor
    }

    /// The base64-encoded JSON string representing the Firestore cursor, suitable for use as a pagination token.
    var pageToken: String? {
        guard let pageToken = try? JSONEncoder().encode(cursor).base64EncodedString()
        else {
            return nil
        }
        return pageToken
    }
}
