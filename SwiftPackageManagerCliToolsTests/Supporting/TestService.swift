//  Created by Axel Ancona Esselmann on 6/13/24.
//

import Foundation

struct TestService: ServiceProtocol {

    var version: [String: String] = [
        "LoadableView": "0.3.9",
        "DebugSwiftUI": "0.0.1"
    ]

    func fetchVersion(
        forOrg org: String,
        dependencyName: String
    ) async throws -> String {
        version[dependencyName] ?? "9.9.9"
    }
}