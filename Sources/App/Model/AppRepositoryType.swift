import ArgumentParser

/// The type of repository backend to use for storing todos.
///
/// This enum defines the available persistence strategies for the application.
/// Each type has different performance, deployment, and cost characteristics.
///
/// ## Repository Types
///
/// - **volatile**: In-memory storage with no persistence
/// - **persistent**: Google Cloud Firestore (production-ready)
/// - **emulated**: Local Firestore emulator for development
///
/// - SeeAlso: ``TodoRepositoryFactory``, ``ConfigurationManager``
public enum AppRepositoryType: String, CaseIterable, ExpressibleByArgument {
    /// In-memory repository with no persistence.
    ///
    /// Use Cases:
    /// - Development and testing
    /// - Demos and prototypes
    /// - Unit tests
    /// - CI/CD pipelines where data doesn't need to survive restarts
    ///
    /// Characteristics:
    /// - All data is lost when the application stops
    /// - Fastest performance (no I/O)
    /// - No external dependencies required
    /// - No configuration needed
    case volatile

    /// Google Cloud Firestore production repository.
    ///
    /// Use Cases:
    /// - Production environments on GCP
    /// - When you need persistent, scalable storage
    /// - Cloud Run, App Engine, Compute Engine deployments
    ///
    /// Prerequisites:
    /// - Valid Google Cloud project
    /// - Service account with Firestore permissions
    /// - Running on GCP infrastructure (for Metadata Service authentication)
    /// - `PROJECT_ID` configured
    ///
    /// Characteristics:
    /// - Fully managed, serverless database
    /// - Automatic scaling and high availability
    /// - Pay-per-operation pricing
    /// - OAuth2 authentication via Metadata Service
    case persistent

    /// Local Firestore emulator for development.
    ///
    /// Use Cases:
    /// - Local development without GCP infrastructure
    /// - Integration testing with persistent semantics
    /// - Pre-production validation
    ///
    /// Setup:
    /// ```bash
    /// gcloud beta emulators firestore start
    /// ```
    ///
    /// Characteristics:
    /// - Runs locally on your machine
    /// - No authentication required
    /// - Free and fast
    /// - Data persists across restarts (in the emulator)
    /// - Allows testing without GCP account
    case emulated

    /// All available repository type values for validation.
    ///
    /// Used by the argument parser and for help text generation.
    public static var allValueStrings: [String] {
        allCases.map { $0.rawValue }
    }

    /// Initializes a repository type from a string argument.
    ///
    /// This initializer is called by `ArgumentParser` when parsing command-line
    /// arguments. It accepts the repository type as a string (e.g., "volatile",
    /// "persistent", "emulated") and converts it to the corresponding enum case.
    ///
    /// - Parameter argument: The repository type string (case-insensitive)
    ///
    /// - Returns: The corresponding `AppRepositoryType` case, or `nil` if the
    ///   argument is not recognized. Prints an error message if `nil` is returned.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// AppRepositoryType(argument: "volatile")  // Returns .volatile
    /// AppRepositoryType(argument: "Persistent") // Returns .persistent
    /// AppRepositoryType(argument: "emulated")   // Returns .emulated
    /// AppRepositoryType(argument: "invalid")    // Returns nil, prints error
    /// ```
    public init?(argument: String) {
        switch argument.lowercased() {
        case "volatile":
            self = .volatile
        case "persistent":
            self = .persistent
        case "emulated":
            self = .emulated
        default:
            print(
                "Invalid repository type '\(argument)'. Expected one of: \(AppRepositoryType.allValueStrings.joined(separator: ", "))."
            )
            return nil
        }
    }
}

