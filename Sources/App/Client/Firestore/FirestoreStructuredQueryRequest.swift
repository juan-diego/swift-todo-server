/// A Swift model representing the request payload for Firestore's structured query REST API.
///
/// This struct encodes a structured query that can be sent to Firestore to perform
/// complex queries on collections. It mirrors the expected JSON structure required
/// by the Firestore backend.
///
/// See Firestore's REST API documentation for structured queries for more details.
struct FirestoreStructuredQueryRequest: Encodable {
    /// The main structured query object containing all query components.
    let structuredQuery: StructuredQuery

    /// Represents the structured query components as defined by Firestore.
    ///
    /// This struct contains the collections to query, filtering criteria,
    /// ordering, limiting, and cursor positioning for pagination.
    struct StructuredQuery: Encodable {
        /// Specifies the collections to query from.
        ///
        /// Each `From` element identifies a collection ID in Firestore.
        let from: [From]

        /// Defines the filter criteria for the query.
        ///
        /// Encodes as the key `"where"` in the Firestore REST API JSON.
        let whereClause: Where?

        /// Specifies the ordering rules for the query results.
        ///
        /// Each `OrderBy` item describes a field and direction (ASCENDING or DESCENDING).
        let orderBy: [OrderBy]

        /// Limits the number of results returned by the query.
        ///
        /// If `nil`, no limit is applied.
        let limit: Int?

        /// Defines a cursor to start the query at a specific position.
        ///
        /// Useful for pagination. Encoded as `"startAt"` in Firestore JSON.
        let startAt: StartAt?

        /// Maps the Swift property names to Firestore's expected JSON keys.
        ///
        /// - `whereClause` is encoded as `"where"`
        /// - `startAt` remains `"startAt"`
        enum CodingKeys: String, CodingKey {
            case from
            case whereClause = "where"
            case orderBy
            case limit
            case startAt
        }
    }

    /// Represents a collection to query from in Firestore.
    ///
    /// Encodes the Firestore collection ID for the `from` clause in a structured query.
    struct From: Encodable {
        /// The ID of the Firestore collection.
        let collectionId: String
    }

    /// Represents the filter condition in a Firestore query.
    ///
    /// Encapsulates a single `fieldFilter` which specifies the field, operator, and value to filter by.
    struct Where: Encodable {
        /// The filter criteria applied to a specific field.
        let fieldFilter: FieldFilter
    }

    /// Defines a filter applied to a specific field in Firestore.
    ///
    /// Contains the field to filter on, the operator, and the value to compare.
    struct FieldFilter: Encodable {
        /// The field to which the filter is applied.
        let field: Field

        /// The operation to apply (e.g., "EQUAL", "LESS_THAN", "GREATER_THAN").
        let op: String

        /// The value to compare the field against.
        let value: Value
    }

    /// Represents a field in a Firestore document.
    ///
    /// The field is identified by its path, which may include nested fields separated by dots.
    struct Field: Encodable {
        /// The dot-separated path to the field within a document.
        let fieldPath: String
    }

    /// Represents a Firestore value used in filters, ordering, and cursors.
    ///
    /// Supports multiple Firestore value types such as string, integer, boolean, and reference.
    struct Value: Encodable {
        /// A string value, encoded as Firestore `stringValue`.
        let stringValue: String?

        /// An integer value represented as a string, encoded as Firestore `integerValue`.
        ///
        /// Firestore expects integer values as strings in the REST API payload.
        let integerValue: String?

        /// A boolean value, encoded as Firestore `booleanValue`.
        let booleanValue: Bool?

        /// A reference value (document reference as string), encoded as Firestore `referenceValue`.
        let referenceValue: String?

        /// Creates a Firestore string value.
        ///
        /// - Parameter stringValue: The string to store.
        init(stringValue: String) {
            self.stringValue = stringValue
            self.integerValue = nil
            self.booleanValue = nil
            self.referenceValue = nil
        }

        /// Creates a Firestore integer value.
        ///
        /// - Parameter integerValue: The integer value represented as a string.
        /// Firestore requires integers to be sent as strings in its REST protocol.
        init(integerValue: String) {
            self.stringValue = nil
            self.integerValue = integerValue
            self.booleanValue = nil
            self.referenceValue = nil
        }

        /// Creates a Firestore boolean value.
        ///
        /// - Parameter booleanValue: The boolean value (true or false).
        init(booleanValue: Bool) {
            self.stringValue = nil
            self.integerValue = nil
            self.booleanValue = booleanValue
            self.referenceValue = nil
        }

        /// Creates a Firestore reference value.
        ///
        /// - Parameter referenceValue: The document reference string.
        /// This is typically in the form of `"projects/{project_id}/databases/(default)/documents/{document_path}"`.
        init(referenceValue: String) {
            self.stringValue = nil
            self.integerValue = nil
            self.booleanValue = nil
            self.referenceValue = referenceValue
        }
    }

    /// Defines the ordering of query results by a specific field.
    ///
    /// Specifies the field to order by and the direction (ASCENDING or DESCENDING).
    struct OrderBy: Encodable {
        /// The field to order the results by.
        let field: Field

        /// The direction of ordering: `"ASCENDING"` or `"DESCENDING"`.
        let direction: String
    }

    /// Represents a cursor position to start the query at a specific point.
    ///
    /// Used for paginating query results with a set of values and a boolean indicating
    /// if the position is before or after the specified values.
    struct StartAt: Encodable {
        /// The values defining the cursor position.
        let values: [Value]

        /// Whether the query results should include documents before this cursor.
        let before: Bool
    }
}
