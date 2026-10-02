import Foundation

public enum AssemblyPart: String, Codable, CaseIterable, Sendable {
  case base, column, tray, cap
  public var title: String { rawValue.capitalized }
  public var explanation: String {
    switch self {
    case .base: "The broad base supports the stand. Its recessed top receives the column."
    case .column:
      "The vertical column connects the base to the tray. Align it with the center socket."
    case .tray: "The tray sits on the column shoulder. Its raised edge faces upward."
    case .cap: "The top cap closes the tray's center opening and completes the sample assembly."
    }
  }
}
public struct TrainingStep: Identifiable, Sendable {
  public let id: Int
  public let title: String
  public let instruction: String
  public let part: AssemblyPart
  public let question: String
  public let choices: [String]
  public let correctChoice: Int
  public static let all: [TrainingStep] = [
    .init(
      id: 0, title: "Inspect the base",
      instruction:
        "Select the base in the model or parts list. Notice its broad footprint and central socket.",
      part: .base, question: "Which feature stabilizes the stand?",
      choices: ["The broad base", "The top cap", "The tray edge"], correctChoice: 0),
    .init(
      id: 1, title: "Fit the column",
      instruction:
        "Select the column. Use the exploded view to see how its lower end aligns with the base socket.",
      part: .column, question: "Where does the column belong?",
      choices: ["Against the tray rim", "In the center socket", "Beside the base"], correctChoice: 1
    ),
    .init(
      id: 2, title: "Seat the tray",
      instruction:
        "Select the tray. Check that the raised edge faces upward before confirming the checkpoint.",
      part: .tray, question: "Which way should the tray's raised edge face?",
      choices: ["Downward", "Sideways", "Upward"], correctChoice: 2),
    .init(
      id: 3, title: "Finish with the cap",
      instruction: "Select the cap. Return to the assembled view and inspect the completed stand.",
      part: .cap, question: "What does the cap close?",
      choices: ["The base underside", "The tray's center opening", "The outer tray rim"],
      correctChoice: 1),
  ]
}
public struct TrainingProgress: Codable, Equatable, Sendable {
  public var formatVersion = 1
  public var completedSteps = 0
  public var updated = Date()
  public init() {}
  public func validate() throws {
    guard formatVersion == 1, (0...TrainingStep.all.count).contains(completedSteps) else {
      throw TrainingError.invalidProgress
    }
  }
  public func completing(step: Int, selected: AssemblyPart?, choice: Int?) throws
    -> TrainingProgress
  {
    guard step == completedSteps, TrainingStep.all.indices.contains(step) else {
      throw TrainingError.outOfOrder
    }
    let expected = TrainingStep.all[step]
    guard selected == expected.part else { throw TrainingError.selectPart }
    guard choice == expected.correctChoice else { throw TrainingError.incorrectAnswer }
    var result = self
    result.completedSteps += 1
    result.updated = Date()
    return result
  }
}
public enum TrainingError: LocalizedError, Sendable {
  case invalidProgress, outOfOrder, selectPart, incorrectAnswer
  public var errorDescription: String? {
    switch self {
    case .invalidProgress: "The saved training record has an unsupported format."
    case .outOfOrder: "Complete the current checkpoint before advancing."
    case .selectPart: "Select the part described in this step before checking your answer."
    case .incorrectAnswer:
      "That answer does not match the model. Review the highlighted part and try again."
    }
  }
}
public actor TrainingStore {
  let url: URL
  private var revision: UInt64 = 0
  public init(url: URL) { self.url = url }
  public func load() throws -> TrainingProgress {
    guard FileManager.default.fileExists(atPath: url.path) else { return TrainingProgress() }
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) < 20_000 else {
      throw TrainingError.invalidProgress
    }
    let progress = try JSONDecoder().decode(TrainingProgress.self, from: Data(contentsOf: url))
    try progress.validate()
    return progress
  }
  public func save(_ progress: TrainingProgress, revision next: UInt64) throws {
    try progress.validate()
    guard next >= revision else { return }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(progress).write(to: url, options: .atomic)
    revision = next
  }
}
