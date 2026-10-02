import Foundation
import Testing

@testable import TrainingCore

@Test func checkpointsRequirePartAndKnowledgeInOrder() throws {
  var progress = TrainingProgress()
  #expect(throws: TrainingError.self) {
    try progress.completing(step: 1, selected: .column, choice: 1)
  }
  #expect(throws: TrainingError.self) {
    try progress.completing(step: 0, selected: .cap, choice: 0)
  }
  #expect(throws: TrainingError.self) {
    try progress.completing(step: 0, selected: .base, choice: 2)
  }
  for step in TrainingStep.all {
    progress = try progress.completing(
      step: step.id, selected: step.part, choice: step.correctChoice)
  }
  #expect(progress.completedSteps == 4)
  #expect(throws: TrainingError.self) {
    try progress.completing(step: 4, selected: .cap, choice: 1)
  }
}
@Test func progressPersistsAndRejectsStaleWrites() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let url = root.appendingPathComponent("Progress.json")
  let store = TrainingStore(url: url)
  let initial = TrainingProgress()
  let next = try initial.completing(step: 0, selected: .base, choice: 0)
  try await store.save(next, revision: 2)
  try await store.save(initial, revision: 1)
  #expect(try await TrainingStore(url: url).load() == next)
  try await store.save(initial, revision: 3)
  #expect(try await store.load().completedSteps == 0)
}
@Test func unsupportedProgressIsNotOverwrittenDuringRead() async throws {
  let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
  defer { try? FileManager.default.removeItem(at: url) }
  var invalid = TrainingProgress()
  invalid.completedSteps = 5
  let bytes = try JSONEncoder().encode(invalid)
  try bytes.write(to: url)
  do {
    _ = try await TrainingStore(url: url).load()
    Issue.record("Invalid progress was accepted")
  } catch TrainingError.invalidProgress {} catch { throw error }
  #expect(try Data(contentsOf: url) == bytes)
}
