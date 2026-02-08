/// A type-safe wrapper for Firestore's polymorphic value representation.
///
/// Firestore stores values using a special JSON format where the type information
/// is embedded in the field name (e.g., `stringValue`, `integerValue`, `booleanValue`).
/// This enum provides a Swift-friendly representation that handles Firestore's
/// serialization quirks transparently.
///
/// ## Firestore Value Format
///
/// Firestore represents values like this in JSON:
/// ```json
/// { "stringValue": "hello" }
/// { "integerValue": "42" }
/// { "booleanValue": true }
/// ```
///
/// Note that `integerValue` is stored as a string in JSON, not a number. This
/// is handled transparently by the encoding and decoding logic.
///
/// ## Usage
///
/// ```swift
/// let value = FirestoreValue.string("hello")
/// let json = try JSONEncoder().encode(value)
/// // Results in: {"stringValue":"hello"}
///
/// let decoded = try JSONDecoder().decode(FirestoreValue.self, from: json)
/// if case let .string(s) = decoded { print(s) }  // Prints: hello
/// ```
enum FirestoreValue: Codable, Sendable {
    /// A string value.
    ///
    /// Maps to Firestore's JSON `{ "stringValue": <String> }`.
    case string(String)

    /// An integer value.
    ///
    /// Maps to Firestore's JSON `{ "integerValue": "<Int>" }`, where the integer
    /// is encoded as a string in JSON.
    case integer(Int)

    /// A boolean value.
    ///
    /// Maps to Firestore's JSON `{ "booleanValue": <Bool> }`.
    case boolean(Bool)

    /// Coding keys corresponding to Firestore's polymorphic value fields.
    ///
    /// This enum is used internally to map Swift enum cases to Firestore's JSON keys:
    /// - `stringValue` for string values
    /// - `integerValue` for integer values (stored as strings in JSON)
    /// - `booleanValue` for boolean values
    private enum CodingKeys: String, CodingKey {
        case stringValue
        case integerValue
        case booleanValue
    }

    /// Creates a new `FirestoreValue` by decoding from the given decoder.
    ///
    /// Firestore uses a type-discriminated format where each value type is represented
    /// by a unique key in the JSON object. This initializer examines the available keys
    /// and constructs the corresponding enum case.
    ///
    /// Special considerations:
    /// - Integer values are encoded as strings (e.g., `"42"`) and are converted to `Int`.
    /// - Only one value type key should be present; the priority order checked is:
    ///   `stringValue`, then `integerValue`, then `booleanValue`.
    /// - If no known Firestore value keys are found, decoding fails with a descriptive error.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the data format is invalid, the integer string cannot be parsed,
    ///           or no supported Firestore value type is found.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringValue = try container.decodeIfPresent(String.self, forKey: .stringValue) {
            self = .string(stringValue)
        } else if let integerString = try container.decodeIfPresent(String.self, forKey: .integerValue) {
            // Firestore encodes integerValue as a string in JSON
            guard let intValue = Int(integerString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .integerValue,
                    in: container,
                    debugDescription: "Cannot parse integerValue '\(integerString)' as Int"
                )
            }
            self = .integer(intValue)
        } else if let boolValue = try container.decodeIfPresent(Bool.self, forKey: .booleanValue) {
            self = .boolean(boolValue)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Unsupported Firestore value type")
            )
        }
    }

    /// Encodes this `FirestoreValue` into Firestore's JSON format.
    ///
    /// Converts the Swift enum case into the Firestore polymorphic JSON representation:
    /// - `.string` encodes as `{ "stringValue": <String> }`
    /// - `.integer` encodes as `{ "integerValue": "<Int>" }` where the integer is converted to a string
    /// - `.boolean` encodes as `{ "booleanValue": <Bool> }`
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: Any encoding errors thrown by the underlying encoder.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode(value, forKey: .stringValue)

        case .integer(let value):
            // Firestore wants integerValue as a string in JSON
            try container.encode(String(value), forKey: .integerValue)

        case .boolean(let value):
            try container.encode(value, forKey: .booleanValue)
        }
    }
}
