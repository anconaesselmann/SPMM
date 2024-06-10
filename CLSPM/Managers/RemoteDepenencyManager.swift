//  Created by Axel Ancona Esselmann on 6/5/24.
//

import Foundation

class RemoteDepenencyManager {

    private let fileManager: FileManagerProtocol
    private let output = Output.shared

    enum Error: Swift.Error {
        case noReleaseVersionFound
        case invalidUrl
        case invalidInput
    }

    private enum Input {
        case dependency(url: String, version: String)
        case githubOrg(url: String, name: String)
    }

    var orgs: [String] {
        get {
            do {
                let config = try ConfigManager(fileManager: fileManager).configFile(global: true)
                return config.orgs ?? []
            } catch {
                print(error)
                return []
            }
        }
        set {
            let manager = ConfigManager(fileManager: fileManager)
            do {
                var config = try manager.configFile(global: true)
                config.orgs = newValue.sorted()
                try manager.save(config, global: true)
            } catch {
                print(error)
            }
        }
    }

    init(fileManager: FileManagerProtocol) {
        self.fileManager = fileManager
    }

    func resolve(name: String) async throws -> JsonSpmDependency? {
        guard !orgs.isEmpty else {
            return nil
        }
        if !orgs.isEmpty {
            output.send("Resolving using orgs \(orgs.joined(separator: ", "))", .verbose)
        }
        for org in orgs {
            do {
                let version = try await fetchVersion(for: org, dependencyName: name)
                let orgUrl = "https://github.com/\(org)"
                let url = "\(orgUrl)/\(name)"
                output.send("Found depenency at \(orgUrl):", .verbose)
                output.send("\tUrl: \(url)", .verbose)
                output.send("\tversion: \(version)", .verbose)
                return JsonSpmDependency(
                    id: UUID(),
                    name: name,
                    url: url,
                    version: version,
                    localPath: nil
                )
            } catch {
                continue
            }
        }
        return nil
    }

    func resolve(
        input line: String,
        name: String
    ) async throws -> JsonSpmDependency {
        let input = try await parseUserInput(line, name: name)
        switch input {
        case .dependency(url: let url, version: let version):
            output.send("Found depenency:", .verbose)
            output.send("\tUrl: \(url)", .verbose)
            output.send("\tversion: \(version)", .verbose)
            return JsonSpmDependency(
                id: UUID(),
                name: name,
                url: url,
                version: version,
                localPath: nil
            )
        case .githubOrg(url: let url, name: let name):
            return try await resolve(input: url + "/\(name)", name: name)
        }
    }

    private func parseUserInput(_ line: String, name: String) async throws -> Input {
        let line = line.trimmingCharacters(in: .whitespaces)
        let components = line.split(separator: " ")
        if components.count == 2 {
            let url = String(components[0])
            let version = String(components[1])
            return .dependency(url: url, version: version)
        } else if
            let result = try /github\.com[\/|:](?<org>[^\/]+)\/(?<dependency>[^\/\s\.]+)/
                .firstMatch(in: line)
        {
            let org = String(result.output.org)
            let dependency = String(result.output.dependency)
            let version = try await fetchVersion(
                for: org,
                dependencyName: dependency
            )
            return .dependency(url: "https://github.com/\(org)/\(dependency)", version: version)
        } else if
            let result = try /github\.com[\/|:](?<org>[^\/\s]+)/
                .firstMatch(in: line)
        {
            let org = String(result.output.org)
            orgs.append(org)
            return .githubOrg(url: "https://github.com/\(org)", name: name)
        } else if
            let result = try /^\s*(?<org>[a-zA-A0-9\-]+)\s*$/
                .firstMatch(in: line)
        {
            let org = String(result.output.org)
            orgs.append(org)
            return .githubOrg(url: "https://github.com/\(org)", name: name)
        } else {
            throw Error.invalidInput
        }
    }

    private func fetchVersion(for org: String, dependencyName: String) async throws -> String {
        guard let releasesUrl = URL(string: "https://api.github.com/repos/\(org)/\(dependencyName)/releases") else {
            throw Error.invalidUrl
        }

        let (data, _) = try await URLSession.shared.data(from: releasesUrl)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let releases = try decoder.decode([GithubRelease].self, from: data)
            .filter { $0.draft == false && $0.prerelease == false}
        guard let latestVersion = releases.first?.tagName else {
            throw Error.noReleaseVersionFound
        }
        return latestVersion
    }
}