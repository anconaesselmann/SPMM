//  Created by Axel Ancona Esselmann on 6/6/24.
//

import XCTest

final class INIT_JSPM_T1_XPROJ_G_Tests: XCTestCase {

    var sut: Init!
    var myApp: MyApp!

    var fileManager: TempFileManager!

    override func setUpWithError() throws {
        fileManager = try TempFileManager(current: "MyApp")
        myApp = MyApp(fileManager)
        Output.test_setup()
        sut = Init().setup_testing()
        sut.verbose = true
        sut.globalDependencies = true
    }

    override func tearDownWithError() throws {
//        print(try Output.text())
        sut = nil
        try fileManager.cleanup()
    }

    // MARK: - INIT-JSPM-T1-XPROJ-GD1
    func testSpmFileWithOneCachedDependencyExample() throws {
        try myApp.moveProjectFile("d\(1)")
        try myApp.moveLocalConfigFile()
        try myApp.moveDependenciesFile()

        let dependencies = ["LoadableView"]

        try sut.run(fileManager: fileManager)

        try XCTAssertEqual(
            fileManager.spmFileDir,
            myApp.application(with: dependencies, globalDependencies: true),
            encoder: SpmFileManager.encoder
        )
    }

    // MARK: - INIT-JSPM-T1-XPROJ-GD2
    func testSpmFileWithTwoCachedDependencyExample() throws {
        try myApp.moveProjectFile("d\(2)")
        try myApp.moveLocalConfigFile()
        try myApp.moveDependenciesFile()

        let dependencies = ["LoadableView", "DebugSwiftUI"]

        try sut.run(fileManager: fileManager)

        try XCTAssertEqual(
            fileManager.spmFileDir,
            myApp.application(with: dependencies, globalDependencies: true),
            encoder: SpmFileManager.encoder
        )
    }
}
