//  Created by Axel Ancona Esselmann on 6/4/24.
//

import Foundation

class ConfigManager {

    private let fileManager: FileManagerProtocol

    init(fileManager: FileManagerProtocol) {
        self.fileManager = fileManager
    }

    func swiftClpmDirUrl(global: Bool) throws -> URL {
        let base: URL
        if global {
            base = fileManager.homeDirectoryForCurrentUser
        } else {
            base = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        }
        let dir = base.appending(path: ".swiftclpm")
        if !directoryExistsAtPath(dir.path()) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: false)
        }
        return dir
    }

    func defaultsUrl(global isGlobal: Bool) throws -> URL {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        let clspmDir = try swiftClpmDirUrl(global: isGlobal)
        let defaultsDir = clspmDir.appending(path: "config")
        var config: ConfigFile
        if !fileManager.fileExists(atPath: defaultsDir.path()) {
            config = ConfigFile()
            let contents = try encoder.encode(config)
            fileManager.createFile(atPath: defaultsDir.path(), contents: contents)
        }
        return defaultsDir
    }

    func configFile(global isGlobal: Bool) throws -> ConfigFile {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let defaultsUrl = try defaultsUrl(global: isGlobal)

        if let data = fileManager.contents(atPath: defaultsUrl.path()) {
            return try decoder.decode(ConfigFile.self, from: data)
        } else {
            return ConfigFile()
        }
    }

    func combinedConfigFile() throws -> ConfigFile {
        let global = try configFile(global: true)
        let local = try configFile(global: false)
        return local.combined(with: global)
    }

    func save(_ config: ConfigFile, global isGlobal: Bool) throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]

        let data = try encoder.encode(config)
        let defaultsUrl = try defaultsUrl(global: isGlobal)
        try data.write(to: defaultsUrl)
    }

    func setLocalRoot(_ localRoot: String?, global isGlobal: Bool) throws {
        var config = try configFile(global: isGlobal)
        if var localRoot = localRoot, !localRoot.isEmpty {
            if localRoot.last != "/" {
                localRoot += "/"
            }
            config.localRoot = localRoot
        } else {
            config.localRoot = nil
        }
        try save(config, global: isGlobal)
    }

    func dependenciesUrl() throws -> URL {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        let clspmDir = try swiftClpmDirUrl(global: true)
        let defaultsDir = clspmDir.appending(path: "dependencies")
        var dependencies: DependenciesFile
        if !fileManager.fileExists(atPath: defaultsDir.path()) {
            dependencies = DependenciesFile()
            let contents = try encoder.encode(dependencies)
            fileManager.createFile(atPath: defaultsDir.path(), contents: contents)
        }
        return defaultsDir
    }

    func dependenciesFile() throws -> DependenciesFile {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let url = try dependenciesUrl()

        if let data = fileManager.contents(atPath: url.path()) {
            return try decoder.decode(DependenciesFile.self, from: data)
        } else {
            return DependenciesFile()
        }
    }

    func save(_ dependencies: DependenciesFile) throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]

        let data = try encoder.encode(dependencies)
        let url = try dependenciesUrl()
        try data.write(to: url)
    }

    func directoryExistsAtPath(_ path: String) -> Bool {
        var isDirectory : ObjCBool = true
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func packagesDir() throws -> String {
        let swiftClpmDir = try swiftClpmDirUrl(global: false)
        let dir = swiftClpmDir.appending(path: "DerivedData")
        if !directoryExistsAtPath(dir.path()) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: false)
        }
        return "\(dir)/packages"
    }
}