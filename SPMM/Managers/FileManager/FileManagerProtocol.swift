//  Created by Axel Ancona Esselmann on 6/7/24.
//

import Foundation

protocol FileManagerProtocol {
    var homeDirectoryForCurrentUser: URL { get }

    var currentDirectoryPath: String { get }

    var currentDirectory: URL { get }

    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey : Any]?
    ) throws

    func fileExists(atPath path: String) -> Bool

    @discardableResult
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool

    func contents(atPath path: String) -> Data?

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool

    func removeItem(at url: URL) throws
}

extension FileManagerProtocol {
    var currentDirectory: URL {
        URL(fileURLWithPath: currentDirectoryPath)
    }

    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool
    ) throws {
        try createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: nil)
    }

    @discardableResult
    func createFile(atPath path: String, contents data: Data?) -> Bool {
        createFile(atPath: path, contents: data, attributes: nil)
    }
}
