# AI Agent Instructions (swift-todo-server)

This repository is a Swift 6 Hummingbird server for a Todo API. Follow the project conventions below whenever you read, change, or extend the code.

## Primary goals

- Use Swift best practices and structured concurrency.
- Prefer `async`/`await`, actors, and `Sendable` types for shared state.
- Document all Swift code with SwiftDoc comments, including private attributes and functions.
- Preserve the existing architecture, naming, and patterns unless the user explicitly asks to refactor.
- Prefer the latest, modern Swift-native libraries and APIs. Avoid deprecated or legacy Objective-C-based libraries when a Swift-native alternative exists.
- Favor modern Swift tooling with structured concurrency support (`async`/`await`), and avoid APIs that require legacy concurrency models when a Swift-native async alternative is available.

## Codebase summary (from analysis)

- Entry point: `AppCommand` in `Sources/App/App.swift` builds the application via `buildApplication(_:)`.
- Composition: `buildRouter(_:)` wires controllers and middleware (`BasicAuthenticator` for `/user`, `JWTAuthenticator` for `/todos` and `/auth`).
- Repository pattern: `TodoRepository` with in-memory and Firestore implementations; user auth data lives in `UserMemoryRepository`.
- Pagination: repository-level `PagedResult` with `RepositoryPagedResult`, page tokens in `PageToken` types, and controller-level `ControllerPagedResult`.
- Configuration: `GlobalConfiguration` uses an actor-backed store for log level and a shared logger; configuration is loaded from JSON with overrides via CLI/env.
- Firestore: custom HTTP client and typed request/response models; pagination uses Firestore `startAt` cursors encoded into opaque tokens.

## Concurrency and safety

- Keep async APIs `Sendable` when crossing task boundaries.
- Use actors for shared mutable state (follow `ConfigurationStore`, in-memory repositories).
- Avoid synchronous blocking in request handlers; keep I/O async.
- Mark Hummingbird route handlers `@Sendable` and preserve signature shape.

## Documentation rules

- Add SwiftDoc comments for new types, public methods, and non-trivial internal helpers.
- Keep docs consistent with existing style: purpose, parameters, returns, throws, and notable behavior.
- Update API examples in doc comments when behavior changes.

## Architectural constraints

- Keep the route layout: `/user` for Basic Auth login; `/todos` for JWT-protected CRUD; `/auth` for token verification.
- Repository implementations must remain swappable via `TodoRepositoryFactory` and `AppRepositoryType`.
- If you add a new configuration option, update:
  - `AppArguments`
  - `AppCommand`
  - `ConfigurationManager`
  - Tests that use `TestArguments`
  - `buildApplication(_:)` if needed

## Error handling and logging

- Use `HTTPError` for request-level errors and keep errors typed when possible.
- Prefer the shared `GlobalConfiguration` logger; avoid ad-hoc logging unless necessary.

## API and contract updates

- If you change routes, request/response shapes, or auth behavior, update `openapi.yaml` to match.
- Keep `README.md` aligned with any significant behavior or configuration changes.

## Testing

- Run `swift test` for behavioral changes when feasible.
- Add or update tests in `Tests/AppTests` for new endpoints or repository behavior.

## Files to know

- App startup: `/Users/diego/Development/swift-todo-server/Sources/App/App.swift`
- App wiring: `/Users/diego/Development/swift-todo-server/Sources/App/App+build.swift`
- Controllers: `/Users/diego/Development/swift-todo-server/Sources/App/Controller`
- Repositories: `/Users/diego/Development/swift-todo-server/Sources/App/Repository`
- Models: `/Users/diego/Development/swift-todo-server/Sources/App/Model`
- Firestore client: `/Users/diego/Development/swift-todo-server/Sources/App/Client/Firestore`
- OpenAPI spec: `/Users/diego/Development/swift-todo-server/openapi.yaml`
