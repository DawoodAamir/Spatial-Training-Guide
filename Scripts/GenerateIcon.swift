import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(
  "Resources/Assets.xcassets/AppIcon.solidimagestack")
let info: [String: Any] = ["author": "xcode", "version": 1]
func json(_ value: [String: Any], _ url: URL) throws {
  try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(
    to: url)
}
let names = ["Front", "Back"]
try json(
  ["info": info, "layers": names.map { ["filename": "\($0).solidimagestacklayer"] }],
  output.appendingPathComponent("Contents.json"))
for name in names {
  let layer = output.appendingPathComponent("\(name).solidimagestacklayer")
  let images = layer.appendingPathComponent("Content.imageset")
  try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
  try json(["info": info], layer.appendingPathComponent("Contents.json"))
  try json(
    ["info": info, "images": [["idiom": "universal", "filename": "Layer.png", "scale": "1x"]]],
    images.appendingPathComponent("Contents.json"))
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let scale = NSAffineTransform()
  scale.scale(by: 0.5)
  scale.concat()
  if name == "Back" {
    NSColor(calibratedRed: 0.19, green: 0.22, blue: 0.30, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
  } else {
    NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.48, alpha: 1).setFill()
    for rect in [NSRect(x: 280, y: 250, width: 464, height: 80), NSRect(x: 460, y: 385, width: 104, height: 180), NSRect(x: 250, y: 620, width: 524, height: 70), NSRect(x: 452, y: 744, width: 120, height: 45)] {
      NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()
    }

  }
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: images.appendingPathComponent("Layer.png"))
}
