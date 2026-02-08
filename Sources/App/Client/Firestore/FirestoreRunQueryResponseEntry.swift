/// An element of a Firestore `runQuery` API response, representing either a returned document,
/// a cursor, or transaction metadata as part of the query results.
///
/// This struct decodes a single entry in the response array from the Firestore `runQuery` method.
/// Each entry may contain one of the following:
/// - A Firestore document matching the query criteria.
/// - A read timestamp indicating when the document was read.
/// - A transaction identifier used to continue the query within a transaction context.
struct FirestoreRunQueryResponseEntry: Decodable, Sendable {
    /// A Firestore document returned from the query.
    /// Present when the query yields a matching document.
    let document: FirestoreTodoDocument?
    
    /// The timestamp at which the document was read.
    /// May be present to indicate the snapshot time associated with the document.
    let readTime: String?
    
    /// The transaction identifier string.
    /// Present when the response is part of an ongoing transaction to resume or continue the query.
    let transaction: String?

    /// Maps the JSON keys received from Firestore's `runQuery` response to the corresponding Swift properties.
    /// This ensures proper decoding of the response data into this struct's fields.
    enum CodingKeys: String, CodingKey {
        case document
        case readTime
        case transaction
    }
}
