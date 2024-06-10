//  Created by Axel Ancona Esselmann on 5/31/24.
//

import Foundation
import XProjParser

struct SpmFileManager {

    enum Error: Swift.Error {
        case invalidSpmFile
        case couldNotOpenFile(String)
        case fileDoesNotExist(String)
        case invalidUserInput
        case notMicroSpmfileCompatible
    }

    private let output = Output.shared
    private let fileManager: FileManagerProtocol
    private let remoteManager: RemoteDepenencyManager

    init(fileManager: FileManagerProtocol) {
        self.fileManager = fileManager
        self.remoteManager = RemoteDepenencyManager(fileManager: fileManager)
    }

    func spmFile(in spmfile: String?) throws -> JsonSpmFile {
        if let spmfile = spmfile {
            output.send("Using spmfile \"\(spmfile)\"", .verbose)
        }
        let spmFileDir = spmfile ?? spmfileDir()
        guard fileManager.fileExists(atPath: spmFileDir) else {
            throw Error.fileDoesNotExist(spmFileDir)
        }
        guard let spmFileData = fileManager.contents(atPath: spmFileDir) else {
            throw Error.couldNotOpenFile(spmFileDir)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(JsonSpmFile.self, from: spmFileData)
        } catch {
            guard let string = String(data: spmFileData, encoding: .utf8) else {
                throw Error.invalidSpmFile
            }
            let dependencyNames = string
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            for dependencyName in dependencyNames {
                if dependencyName.contains(/[^a-zA-Z0-9]/) {
                    throw Error.invalidSpmFile
                }
            }
            let project = try Project(fileManager: fileManager)
            let root = try project.root()
            let targets = try project.targets(in: root)
                .filter {
                    !$0.name.hasSuffix("Tests")
                }
            guard targets.count == 1, let target = targets.first else {
                throw Error.invalidSpmFile
            }
            return JsonSpmFile(targets: [
                JsonSpmTarget(id: UUID(), name: target.name, dependencies: dependencyNames)
            ])
        }

    }

    func targets(in spmfile: String?) async throws -> [String: Target] {
        let spmFileJson = try spmFile(in: spmfile)

        let dependencyNamesUsedByTargets: Set<String> = spmFileJson.targets.reduce(into: []) {
            $0 = $0.union(Set($1.dependencies))
        }
        let resolvedDependencyNames = Set((spmFileJson.dependencies ?? []).map { $0.name })
        let uresolvedDependencyNames = dependencyNamesUsedByTargets.subtracting(resolvedDependencyNames)

        var dependencies: [String: JsonSpmDependency] = (spmFileJson.dependencies ?? [])
            .reduce(into: [:]) {
                $0[$1.name] = $1
            }

        if !uresolvedDependencyNames.isEmpty {
            let configManager = ConfigManager(fileManager: fileManager)
            var dependenciesFile = try configManager.dependenciesFile()
            let globalDependencies: [String: JsonSpmDependency] = dependenciesFile
                .dependencies.reduce(into: [:]) {
                    $0[$1.name] = $1
                }
            output.send("Unresolved dependencies", .verbose)
            let sorted = uresolvedDependencyNames.sorted()
            for dependencyName in sorted {
                output.send("\t\(dependencyName)", .verbose)
            }
            output.send("Resolving global dependencies", .verbose)
            for dependencyName in sorted {
                if let resolvedDependency = globalDependencies[dependencyName] {
                    dependencies[dependencyName] = resolvedDependency
                    output.send("\t\(dependencyName) resolved", .verbose)
                } else {
                    let new: JsonSpmDependency
                    if let resolved = try await remoteManager.resolve(name: dependencyName) {
                        new = resolved
                    } else {
                        output.send("Could not resolve dependency \(dependencyName)")
                        output.send("Either:")
                        output.send("\t - Enter the url for the repository")
                        output.send("\t\t(Optional: For none github repositories or to specify a speciffic version append a")
                        output.send("\t\t release tag name to the repository url separated by a space.)")
                        output.send("\t - Enter the github user/organization that should be used to resolve dependencies")
                        guard let line = readLine() else {
                            throw Error.invalidUserInput
                        }
                        new = try await remoteManager.resolve(
                            input: line,
                            name: dependencyName
                        )
                    }
                    dependencies[dependencyName] = new
                    output.send("\t\(dependencyName) resolved", .verbose)
                    dependenciesFile.dependencies = (dependenciesFile.dependencies + [new])
                        .sorted { $0.name < $1.name }
                    try configManager.save(dependenciesFile)
                }
            }
        }

        let targetIds: [String: UUID] = spmFileJson.targets.reduce(into: [:]) {
            $0[$1.name] = $1.id
        }

        return spmFileJson.targets
            .reduce(into: [String: Target]()) {
                let depencencies = $1.dependencies.compactMap { dependencyName in
                    dependencies[dependencyName]
                }
                $0[$1.name] = Target(id: targetIds[$1.name], dependencies: depencencies)
            }
    }

    func packagesToRemove(in targets: [String: Target]) throws -> [(packageName: String, relativePath: String?, targetName: String)] {
        targets.flatMap { (targetName, target) in
            target.dependencies.map {
                (
                    packageName: $0.name,
                    relativePath: $0.localPath,
                    targetName: targetName
                )
            }
        }
    }

    func packagesToAdd(in targets: [String: Target]) throws -> [(dependency: XProjDependency, isLocal: Bool, targetName: String)] {
        try targets.flatMap { (targetName, target) in
            try target.dependencies.map { value -> (dependency: XProjDependency, isLocal: Bool, targetName: String) in
                let targetId = target.id
                let dependencyId = value.id ?? UUID()
                let start = targetId.uuidString.startIndex
                let center = targetId.uuidString.index(start, offsetBy: 8)
                let end = targetId.uuidString.endIndex
                let id = UUID(uuidString: String(targetId.uuidString[start..<center]) + String(dependencyId.uuidString[center..<end])) ?? UUID()
                if let url = value.url, let version = value.version, let localPath = value.localPath {
                    return (
                        dependency: XProjDependency(
                            id: id,
                            name: value.name,
                            url: url,
                            version: version,
                            localPath: localPath
                        ),
                        isLocal: value.useLocal ?? false,
                        targetName: targetName
                    )
                } else if let url = value.url, let version = value.version {
                    return (
                        dependency: XProjDependency(
                            id: id,
                            name: value.name,
                            url: url,
                            version: version
                        ),
                        isLocal: value.useLocal ?? false,
                        targetName: targetName
                    )
                } else if let localPath = value.localPath {
                    return (
                        dependency: XProjDependency(
                            id: id,
                            name: value.name,
                            localPath: localPath
                        ),
                        isLocal: true,
                        targetName: targetName
                    )
                } else if let useLocal = value.useLocal, useLocal == true {
                    return (
                        dependency: XProjDependency(
                            id: id,
                            name: value.name
                        ),
                        isLocal: true,
                        targetName: targetName
                    )
                } else if value.useLocal == nil, value.url == nil, value.version == nil {
                    return (
                        dependency: XProjDependency(
                            id: id,
                            name: value.name
                        ),
                        isLocal: true,
                        targetName: targetName
                    )
                } else {
                    output.send("Dependency with missing entries:")
                    output.send(value.name)
                    output.send("URL: \(value.url ?? "none")")
                    output.send("Version: \(value.version ?? "none")")
                    output.send("Local: \(value.localPath ?? "none")")
                    throw Error.invalidSpmFile
                }
            }
        }
    }

    func save(_ jsonFile: JsonSpmFile, to spmfile: String?, isCsv: Bool) throws {
        let dir = spmfile ?? spmfileDir()
        output.send("Saving spmfile:", .verbose)
        output.send("\t\(dir)", .verbose)
        let url = URL(fileURLWithPath: dir)
        if isCsv {
            guard jsonFile.microCompatible else {
                output.send("Incompatible targets", .verbose)
                throw Error.notMicroSpmfileCompatible
            }
            guard let target = jsonFile.targets
                .first(where: { !$0.name.hasSuffix("Tests")} )
            else {
                output.send("No none-test targets", .verbose)
                throw Error.notMicroSpmfileCompatible
            }
            guard let data = target.dependencies.joined(separator: ", ").data(using: .utf8) else {
                output.send("Could not save micro spmfile", .verbose)
                throw Error.notMicroSpmfileCompatible
            }
            try data
                .write(to: url)
        } else {
            try Self.encoder.encode(jsonFile)
                .write(to: url)
        }
    }

    var hasSpmFile: Bool {
        fileManager.fileExists(atPath: spmfileDir())
    }

    func removeSpmFile() throws {
        let url = URL(fileURLWithPath: spmfileDir())
        try fileManager.removeItem(at: url)
    }

    private func spmfileDir() -> String {
        let currentPath = fileManager.currentDirectoryPath
        return "\(currentPath)/spmfile"
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return encoder
    }
}