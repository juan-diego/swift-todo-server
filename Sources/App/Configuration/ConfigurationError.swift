/// Errors that can occur during configuration loading and validation.
///
/// This enum defines the possible error conditions when the application attempts to load
/// or access required configuration settings.
enum ConfigurationError: Error {
    /// Indicates a required configuration value is missing.
    ///
    /// - Parameter reason: A descriptive explanation of the missing configuration.
    case missedConfiguration(_ reason: String)
    
    /// Indicates a configuration value is invalid or cannot be parsed.
    ///
    /// - Parameters:
    ///   - reason: A description of the validation failure.
    ///   - error: The underlying error, if available.
    case invalidConfiguration(_ reason: String, error: Error? = nil)
    
    /// Indicates that required Firestore repository configuration is missing.
    ///
    /// - Parameter reason: A descriptive message about the missing Firestore configuration.
    case missedFirestoreConfiguration(_ reason: String)
}
