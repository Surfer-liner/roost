import Foundation

public final class LayoutStore {
  private let fileURL: URL
  private var layoutsByFingerprint: [String: Layout]

  public convenience init() {
    self.init(fileURL: LayoutStore.defaultFileURL())
  }

  init(fileURL: URL) {
    self.fileURL = fileURL
    layoutsByFingerprint = Self.readLayouts(at: fileURL)
  }

  public func layout(for fingerprint: String) -> Layout? {
    layoutsByFingerprint[fingerprint]
  }

  public func save(_ layout: Layout) {
    layoutsByFingerprint[layout.displayFingerprint] = layout
    persist()
  }

  private func persist() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(layoutsByFingerprint) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }

  private static func defaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let roostFolder = appSupport.appendingPathComponent("Roost", isDirectory: true)
    try? FileManager.default.createDirectory(at: roostFolder, withIntermediateDirectories: true)
    return roostFolder.appendingPathComponent("layouts.json")
  }

  private static func readLayouts(at url: URL) -> [String: Layout] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard
      let data = try? Data(contentsOf: url),
      let layouts = try? decoder.decode([String: Layout].self, from: data)
    else { return [:] }
    return layouts
  }
}
