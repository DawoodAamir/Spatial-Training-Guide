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
    app.buttons["Open 3D model"].tap()
  }
}
