//  Created by Axel Ancona Esselmann on 5/30/24.
//

import Foundation

struct JsonSpmTarget: Codable {
    let name: String
    let dependencies: [String]
}

struct JsonSpmDependency: Codable {
    let name: String
    let url: String?
    let version: String?
    let localPath: String?
    let useLocal: Bool?
}

struct JsonSpmFile: Codable {
    let targets: [JsonSpmTarget]
    let dependencies: [JsonSpmDependency]
}