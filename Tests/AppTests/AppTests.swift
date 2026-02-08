import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

@testable import ToDoApp

/// Integration tests for the application bootstrapping and routing.
final class AppTests: XCTestCase {
    
    /// Minimal argument set for building the application in tests.
    struct TestArguments: AppArguments {
        /// Loopback hostname used for binding in tests.
        let hostname = "127.0.0.1"
        /// Ephemeral port selection for tests.
        let port = 0
        /// Verbose logging for test diagnostics.
        let logLevel: Logger.Level? = .trace
        /// Configuration file used for tests.
        var configurationFile: String?
    }

    /// Verifies the application boots and serves the health endpoint.
    func testApp() async throws {
        // Resolve the path of the configuration file in the resource bunde
        var args = TestArguments()
        guard let configFile = Bundle.module.path(forResource: "volatile-config", ofType: "json") else {
            fatalError("volatile-config.json not found in test bundle")
        }
        args.configurationFile = configFile
        
        // Run the test
        let app: some ApplicationProtocol = try await buildApplication(args)
        try await app.test(.router) { client in
            let headers = HTTPFields()
            try await client.execute(uri: "/", method: .get, headers: headers) { response in
                XCTAssertEqual(response.body, ByteBuffer(string: "todo-server v1.0!"))
            }
        }
    }
    
    
}
