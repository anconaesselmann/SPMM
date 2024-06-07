//  Created by Axel Ancona Esselmann on 6/6/24.
//

import XCTest

final class I_JSPM_T1_XPROJ_L_Tests: XCTestCase {

    var sut: Init!

    var fileManager: TempFileManager!

    override func setUpWithError() throws {
        fileManager = try TempFileManager(current: "MyApp")
        FileManager.default = fileManager
        Output.test_setup()
        sut = Init().setup_testing()
        sut.verbose = true
    }

    override func tearDownWithError() throws {
//        print(try Output.text())
        sut = nil
        try fileManager.cleanup()
    }

    // MARK: - I-JSPM-T1-XPROJ-LD1
    func testSpmFileWithOneCachedDependencyExample() throws {
        try MyApp.moveProjectFile(1)
        try MyApp.moveLocalConfigFile()
        try MyApp.moveDependenciesFile()

        let dependencies = ["LoadableView"]

        try sut.run()

        try XCTAssertEqual(
            fileManager.spmFileDir,
            MyApp.application(with: dependencies),
            encoder: SpmFileManager.encoder
        )
    }

    // MARK: - I-JSPM-T1-XPROJ-LD2
    func testSpmFileWithTwoCachedDependencyExample() throws {
        try MyApp.moveProjectFile(2)
        try MyApp.moveLocalConfigFile()
        try MyApp.moveDependenciesFile()

        let dependencies = ["LoadableView", "DebugSwiftUI"]

        try sut.run()

        try XCTAssertEqual(
            fileManager.spmFileDir,
            MyApp.application(with: dependencies),
            encoder: SpmFileManager.encoder
        )
    }
}
