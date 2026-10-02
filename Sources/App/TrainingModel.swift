import Foundation
import Observation

@MainActor @Observable final class TrainingModel {
  private(set) var progress = TrainingProgress()
  var selected: AssemblyPart?
  var choice: Int?
  var exploded = true
  var rotation: Double = -25
  var error: String?
  var feedback: String?
  var saving = false
  var loaded = false
  var step: TrainingStep? {
    TrainingStep.all.indices.contains(progress.completedSteps)
      ? TrainingStep.all[progress.completedSteps] : nil
  }
  private var revision: UInt64 = 0
  private let store: TrainingStore
  init() {
    var root = URL.applicationSupportDirectory.appendingPathComponent("SpatialTrainingGuide")
    #if DEBUG
      if let id = ProcessInfo.processInfo.environment["TRAINING_TEST_STORE"],
        UUID(uuidString: id) != nil
      {
        root.appendPathComponent("Tests/" + id)
      }
    #endif
    store = TrainingStore(url: root.appendingPathComponent("Progress.json"))
  }
  func load() async {
    guard !loaded else { return }
    loaded = true
    do { progress = try await store.load() } catch { self.error = error.localizedDescription }
  }
  func check() async {
    guard !saving else { return }
    do {
      let next = try progress.completing(
        step: progress.completedSteps, selected: selected, choice: choice)
      saving = true
      defer { saving = false }
      revision += 1
      try await store.save(next, revision: revision)
      progress = next
      choice = nil
      selected = nil
      feedback = nil
      if next.completedSteps == TrainingStep.all.count { exploded = false }
    } catch TrainingError.incorrectAnswer {
      feedback = TrainingError.incorrectAnswer.localizedDescription
    } catch TrainingError.selectPart {
      feedback = TrainingError.selectPart.localizedDescription
    } catch { self.error = error.localizedDescription }
  }
  func restart() async {
    guard !saving else { return }
    saving = true
    defer { saving = false }
    do {
      revision += 1
      let next = TrainingProgress()
      try await store.save(next, revision: revision)
      progress = next
      choice = nil
      selected = nil
      feedback = nil
      exploded = true
    } catch { self.error = error.localizedDescription }
  }
}
