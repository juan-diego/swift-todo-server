import Foundation

/// Firestore document for a todo in the `todos` collection.
struct FirestoreTodoDocument: Codable, Sendable {
    /// Firestore document fields for a todo.
    struct Fields: Codable, Sendable {
        /// The todo identifier as a Firestore string value.
        var id: FirestoreValue
        /// The owner's user ID as a Firestore string value.
        var ownerId: FirestoreValue
        /// The todo title as a Firestore string value.
        var title: FirestoreValue
        /// The todo URL as a Firestore string value.
        var url: FirestoreValue
        /// Optional ordering value as a Firestore integer value.
        var order: FirestoreValue?
        /// Optional completion status as a Firestore boolean value.
        var completed: FirestoreValue?
    }

    /// Full document name: `projects/{projectId}/databases/(default)/documents/todos/{documentId}`.
    var name: String?

    /// Actual fields stored in the document.
    var fields: Fields

    /// Timestamps are not strictly needed for your Todo domain, but available if you want them.
    var createTime: String?
    var updateTime: String?
}

/// Convenience list response alias for todo documents.
typealias FirestoreTodoListResponse = FirestoreListResponse<FirestoreTodoDocument>


// MARK: - Encoding

extension FirestoreTodoDocument {
    /// Initializes a Firestore document from a ``Todo`` model.
    ///
    /// - Parameters:
    ///   - todo: The todo to encode.
    ///   - ownerId: The owning user's ID.
    init(from todo: Todo, withOwnerId ownerId: String) {
        self.name = nil        // Firestore will set this in responses
        self.createTime = nil  // Firestore-populated
        self.updateTime = nil  // Firestore-populated

        self.fields = Fields(
            id: .string(todo.id.uuidString),
            ownerId: .string(ownerId),
            title: .string(todo.title),
            url: .string(todo.url),
            order: todo.order.map(FirestoreValue.integer),
            completed: todo.completed.map(FirestoreValue.boolean)
        )
    }
}

// MARK: - Decoding

/// Errors that can occur while decoding Firestore todo documents.
enum FirestoreTodoDecodingError: Error {
    /// A required field was missing from the Firestore document.
    case missingRequiredField(String)
    /// The document contained an invalid UUID string.
    case invalidUUID(String)
    /// The document contained a field with an unexpected Firestore value type.
    case unexpectedType(String)
}

extension Todo {
    /// Initializes a ``Todo`` from a Firestore todo document.
    ///
    /// - Parameter firestoreDocument: The Firestore document to decode.
    /// - Throws: ``FirestoreTodoDecodingError`` if the document is invalid.
    init(from firestoreDocument: FirestoreTodoDocument) throws {
        let fields = firestoreDocument.fields

        // id
        guard case let .string(idString) = fields.id else {
            throw FirestoreTodoDecodingError.unexpectedType("id must be stringValue")
        }
        guard let uuid = UUID(uuidString: idString) else {
            throw FirestoreTodoDecodingError.invalidUUID(idString)
        }

        // title
        guard case let .string(titleString) = fields.title else {
            throw FirestoreTodoDecodingError.unexpectedType("title must be stringValue")
        }

        // url
        guard case let .string(urlString) = fields.url else {
            throw FirestoreTodoDecodingError.unexpectedType("url must be stringValue")
        }

        // order (optional)
        let orderValue: Int?
        if let orderField = fields.order {
            switch orderField {
            case .integer(let intValue):
                orderValue = intValue
            default:
                throw FirestoreTodoDecodingError.unexpectedType("order must be integerValue if present")
            }
        } else {
            orderValue = nil
        }

        // completed (optional)
        let completedValue: Bool?
        if let completedField = fields.completed {
            switch completedField {
            case .boolean(let boolValue):
                completedValue = boolValue
            default:
                throw FirestoreTodoDecodingError.unexpectedType("completed must be booleanValue if present")
            }
        } else {
            completedValue = nil
        }

        self.init(
            id: uuid,
            title: titleString,
            order: orderValue,
            url: urlString,
            completed: completedValue
        )
    }
}
