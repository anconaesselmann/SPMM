//  Created by Axel Ancona Esselmann on 5/30/24.
//

import Foundation
import ArgumentParser
import XProjParser

struct Install: ParsableCommand {

    public static let configuration = CommandConfiguration(abstract: "Generate a blog post banner from the given input")

    func run() throws {
        let currentPath = FileManager.default.currentDirectoryPath
        guard let projectName = currentPath.split(separator: "/").last else {
            return
        }

        let spmFileDir = "\(currentPath)/spmfile"

        guard let spmFileData = FileManager.default.contents(atPath: spmFileDir) else {
            throw Error.couldNotOpenFile(spmFileDir)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let spmFileJson = try decoder.decode(JsonSpmFile.self, from: spmFileData)

        let projFileDir = "\(currentPath)/\(projectName).xcodeproj/project.pbxproj"
        print("Project file: \(projFileDir)")
        guard let projData = FileManager.default.contents(atPath: projFileDir) else {
            throw Error.couldNotOpenFile(projFileDir)
        }
        guard let projContent = String(data: projData, encoding: .utf8) else {
            throw Error.couldNotReadFile(projFileDir)
        }
        let dependencies = spmFileJson.dependencies.reduce(into: [String: JsonSpmDependency]()) {
            $0[$1.name] = $1
        }
        let targets = spmFileJson.targets
            .reduce(into: [String: [JsonSpmDependency]]()) {
                let depencencies = $1.dependencies.compactMap { dependencyName in
                    dependencies[dependencyName]
                }
                $0[$1.name] = depencencies
            }
        let remove: [(packageName: String, relativePath: String?, targetName: String)] = targets.flatMap { (target, values) in
            values.map {
                (
                    packageName: $0.name,
                    relativePath: $0.localPath,
                    targetName: target
                )
            }
        }
        let add: [(dependency: XProjDependency, isLocal: Bool, targetName: String)] = try targets.flatMap { (target, values) in
            try values.map { value -> (dependency: XProjDependency, isLocal: Bool, targetName: String) in
                if let url = value.url, let version = value.version, let localPath = value.localPath {
                    return (
                        dependency: XProjDependency(
                            name: value.name,
                            url: url,
                            version: version,
                            localPath: localPath
                        ),
                        isLocal: value.useLocal ?? false,
                        targetName: target
                    )
                } else if let url = value.url, let version = value.version {
                    return (
                        dependency: XProjDependency(
                            name: value.name,
                            url: url,
                            version: version
                        ),
                        isLocal: value.useLocal ?? false,
                        targetName: target
                    )
                } else if let localPath = value.localPath {
                    return (
                        dependency: XProjDependency(
                            name: value.name,
                            localPath: localPath
                        ),
                        isLocal: value.useLocal ?? false,
                        targetName: target
                    )
                } else {
                    throw Error.invalidSpmFile
                }
            }
        }
        let removedContent = try XProjParser()
            .parse(content: projContent)
            .root()
            .removePackages(in: projContent, remove)
        let addedContent = try XProjParser()
            .parse(content: removedContent)
            .root()
            .addPackages(in: removedContent, add)
        let url = URL(fileURLWithPath: projFileDir)
        try addedContent.write(to: url, atomically: true, encoding: .utf8)
        let result = shell("xcodebuild -resolvePackageDependencies")
        print(result)
    }
}
