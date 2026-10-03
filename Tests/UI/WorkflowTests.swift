import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testCheckpointAndRelaunch() throws {
    let app = XCUIApplication()
    app.launchEnvironment["TRAINING_TEST_STORE"] = UUID().uuidString
    app.launch()
    XCTAssertTrue(app.buttons["part-base"].waitForExistence(timeout: 30), app.debugDescription)
    app.buttons["part-base"].tap()
    app.buttons["answer-0"].tap()
    app.buttons["Check checkpoint"].tap()
    XCTAssertTrue(
      app.staticTexts["Step 2 · Fit the column"].waitForExistence(timeout: 10), app.debugDescription
    )
    app.terminate()
    app.launch()
    XCTAssertTrue(
      app.staticTexts["Step 2 · Fit the column"].waitForExistence(timeout: 15), app.debugDescription
    )
    app.buttons["part-column"].tap()
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Guided assembly"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    try captureScene("Workspace")
    app.buttons["Open 3D model"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["assemblyControls"].waitForExistence(timeout: 15),
      app.debugDescription)
    let volume = XCTAttachment(screenshot: app.screenshot())
    volume.name = "Exploded assembly"
    volume.lifetime = .keepAlways
    add(volume)
    try captureScene("Volume")
  }
  private func captureScene(_ name: String) throws {
    let folder = URL.documentsDirectory
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(name.utf8).write(
      to: folder.appendingPathComponent("scene-request.txt"), options: .atomic)
    for _ in 0..<60 {
      if (try? String(
        contentsOf: folder.appendingPathComponent("scene-response.txt"), encoding: .utf8)) == name
      {
        return
      }
      Thread.sleep(forTimeInterval: 1)
    }
    XCTFail("Simulator did not acknowledge scene capture: " + name)
  }
}
