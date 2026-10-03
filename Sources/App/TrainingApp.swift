import RealityKit
import SwiftUI

@main struct SpatialTrainingGuideApp: App {
  @State private var model = TrainingModel()
  var body: some SwiftUI.Scene {
    WindowGroup { TrainingWorkspace(model: model).frame(minWidth: 860, minHeight: 650) }
      .defaultSize(width: 1000, height: 760)
    WindowGroup(id: "assembly") { AssemblyScene(model: model) }
      .windowStyle(.volumetric).defaultSize(width: 0.9, height: 1, depth: 0.9, in: .meters)
  }
}
struct TrainingWorkspace: View {
  @Bindable var model: TrainingModel
  @Environment(\.openWindow) private var openWindow
  @State private var confirmingRestart = false
  var body: some View {
    NavigationSplitView {
      List {
        Section("Assembly sequence") {
          ForEach(TrainingStep.all) { step in
            Label(
              step.title,
              systemImage: step.id < model.progress.completedSteps
                ? "checkmark.circle.fill"
                : step.id == model.progress.completedSteps ? "circle.inset.filled" : "circle"
            )
            .foregroundStyle(step.id <= model.progress.completedSteps ? .primary : .secondary)
          }
        }
        Section("Parts") {
          ForEach(AssemblyPart.allCases, id: \.self) { part in
            Button {
              model.selected = part
              model.feedback = nil
            } label: {
              HStack {
                Text(part.title)
                Spacer()
                if model.selected == part { Image(systemName: "checkmark") }
              }
            }.accessibilityIdentifier("part-" + part.rawValue)
          }
        }
      }.navigationTitle("Training Guide").navigationSplitViewColumnWidth(250)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            VStack(alignment: .leading, spacing: 6) {
              Text("Desk stand assembly").font(.largeTitle.bold())
              Text("An original four-part practice model").foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open 3D model", systemImage: "cube.transparent") { openWindow(id: "assembly") }
          }
          ProgressView(value: Double(model.progress.completedSteps), total: 4) {
            Text("\(model.progress.completedSteps) of 4 checkpoints completed")
          }.accessibilityIdentifier("trainingProgress")
          HStack {
            Toggle("Exploded view", isOn: $model.exploded).toggleStyle(.button)
            Slider(value: $model.rotation, in: -180...180) { Text("Model rotation") }
            Button("Reset view") {
              model.rotation = -25
              model.exploded = true
            }
          }
          AssemblyDiagram(selected: model.selected, exploded: model.exploded)
            .frame(height: 220).frame(maxWidth: .infinity).background(
              .thinMaterial, in: RoundedRectangle(cornerRadius: 20))
          if let selected = model.selected {
            GroupBox(selected.title) {
              Text(selected.explanation).frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          if let step = model.step {
            VStack(alignment: .leading, spacing: 16) {
              Text("Step \(step.id + 1) · \(step.title)").font(.title2.bold())
                .accessibilityIdentifier("currentStep")
              Text(step.instruction)
              Text(step.question).font(.headline)
              ForEach(step.choices.indices, id: \.self) { index in
                Button {
                  model.choice = index
                  model.feedback = nil
                } label: {
                  HStack {
                    Image(systemName: model.choice == index ? "checkmark.circle.fill" : "circle")
                    Text(step.choices[index])
                    Spacer()
                  }.padding(5)
                }.accessibilityIdentifier("answer-\(index)")
              }
              if let feedback = model.feedback {
                Label(feedback, systemImage: "info.circle").foregroundStyle(.orange)
              }
              Button("Check checkpoint") { Task { await model.check() } }
                .buttonStyle(.borderedProminent).disabled(model.saving || model.choice == nil)
            }
          } else {
            ContentUnavailableView(
              "Practice complete", systemImage: "checkmark.seal",
              description: Text(
                "You identified all four parts and completed the knowledge checks. This records in-app practice, not a certification or inspection of a physical assembly."
              ))
          }
          Text(
            "Select parts with gaze and pinch in the 3D volume, or use the Parts list. The diagram is a simplified cross-section; the volume shows the complete geometry."
          ).font(.footnote).foregroundStyle(.secondary)
          Button("Restart practice") { confirmingRestart = true }.disabled(model.saving)
        }.padding(28)
      }.navigationTitle("Desk stand")
    }.task { await model.load() }
      .confirmationDialog("Restart all four checkpoints?", isPresented: $confirmingRestart) {
        Button("Restart practice") { Task { await model.restart() } }
      } message: {
        Text("The current practice progress will be reset. The model and lesson remain available.")
      }
      .alert(
        "Unable to save progress",
        isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
      ) {
        Button("OK") { model.error = nil }
      } message: {
        Text(model.error ?? "")
      }
  }
}
struct AssemblyDiagram: View {
  let selected: AssemblyPart?
  let exploded: Bool
  var body: some View {
    VStack(spacing: exploded ? 12 : 0) {
      shape(.cap, width: 35, height: 18)
      shape(.tray, width: 200, height: 22)
      shape(.column, width: 30, height: 90)
      shape(.base, width: 160, height: 28)
    }.accessibilityElement(children: .ignore).accessibilityLabel(
      exploded ? "Exploded stand diagram: cap, tray, column, base" : "Assembled stand diagram")
  }
  func shape(_ part: AssemblyPart, width: CGFloat, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 5).fill(
      selected == part ? Color.orange : Color.teal.opacity(0.7)
    )
    .frame(width: width, height: height)
    .overlay {
      Text(part.title).font(.caption2).foregroundStyle(.white).fixedSize().offset(x: width / 2 + 40)
    }
  }
}
struct AssemblyScene: View {
  let model: TrainingModel
  @State private var root = Entity()
  @State private var parts: [AssemblyPart: Entity] = [:]
  var body: some View {
    RealityView { content in
      content.add(root)
      for part in AssemblyPart.allCases {
        let entity = makePart(part)
        parts[part] = entity
        root.addChild(entity)
      }
      updateParts()
    } update: { _ in
      updateParts()
    }
    .gesture(
      SpatialTapGesture().targetedToAnyEntity().onEnded { value in
        var current: Entity? = value.entity
        while let entity = current {
          if let part = AssemblyPart(rawValue: entity.name) {
            model.selected = part
            model.feedback = nil
            break
          }
          current = entity.parent
        }
      }
    )
    .ornament(attachmentAnchor: .scene(.bottom)) {
      HStack {
        Text(model.selected?.title ?? "Select a part").font(.headline)
        Toggle(
          "Exploded view", isOn: Binding(get: { model.exploded }, set: { model.exploded = $0 })
        ).toggleStyle(.button)
      }.padding().glassBackgroundEffect().accessibilityIdentifier("assemblyControls")
    }
  }
  @MainActor func updateParts() {
    root.orientation = simd_quatf(angle: Float(model.rotation) * .pi / 180, axis: [0, 1, 0])
    for (part, entity) in parts {
      let index = AssemblyPart.allCases.firstIndex(of: part) ?? 0
      let height: Float =
        switch part {
        case .base: 0
        case .column: 0.15
        case .tray: 0.30
        case .cap: 0.34
        }
      entity.position.y = height - 0.3 + (model.exploded ? Float(index) * 0.10 : 0)
      let color =
        model.selected == part
        ? UIColor.systemOrange : UIColor(red: 0.28, green: 0.49, blue: 0.48, alpha: 1)
      for child in entity.children {
        if let mesh = child as? ModelEntity {
          mesh.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
        }
      }
    }
  }
  @MainActor func makePart(_ part: AssemblyPart) -> Entity {
    let group = Entity()
    group.name = part.rawValue
    func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>) {
      let mesh = ModelEntity(
        mesh: .generateBox(size: size, cornerRadius: 0.008), materials: [SimpleMaterial()])
      mesh.position = position
      group.addChild(mesh)
    }
    switch part {
    case .base:
      box([0.28, 0.04, 0.22], [0, 0, 0])
      for x: Float in [-0.035, 0.035] { box([0.018, 0.03, 0.08], [x, 0.035, 0]) }
    case .column: box([0.045, 0.25, 0.045], [0, 0, 0])
    case .tray:
      for x: Float in [-0.10125, 0.10125] { box([0.1575, 0.025, 0.28], [x, 0, 0]) }
      for z: Float in [-0.08125, 0.08125] { box([0.045, 0.025, 0.1175], [0, 0, z]) }
      for x: Float in [-0.175, 0.175] { box([0.012, 0.03, 0.28], [x, 0.025, 0]) }
      for z: Float in [-0.135, 0.135] { box([0.36, 0.03, 0.012], [0, 0.025, z]) }
    case .cap: box([0.07, 0.035, 0.07], [0, 0, 0])
    }
    group.generateCollisionShapes(recursive: true)
    group.components.set(InputTargetComponent())
    group.components.set(HoverEffectComponent())
    return group
  }
}
