import Foundation

public final class LayoutStore {
  private let fileURL: URL

  public convenience init() {
    self.init(fileURL: LayoutStore.defaultFileURL())
  }

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func layout(for fingerprint: String) -> Layout? {
    Self.readLayouts(at: fileURL)[fingerprint]
  }

  @discardableResult
  public func save(_ layout: Layout) -> Bool {
    var layouts = Self.readLayouts(at: fileURL)
    layouts[layout.displayFingerprint] = layout
    return Self.write(layouts, to: fileURL)
  }

  private static func write(_ layouts: [String: Layout], to url: URL) -> Bool {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(layouts) else { return false }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      return false
    }
  }

  private static func defaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    let roostFolder = appSupport.appendingPathComponent("Roost", isDirectory: true)
    try? FileManager.default.createDirectory(at: roostFolder, withIntermediateDirectories: true)
    return roostFolder.appendingPathComponent("layouts.json")
  }

  private static func readLayouts(at url: URL) -> [String: Layout] {
    guard let data = try? Data(contentsOf: url) else { return [:] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let layouts = try? decoder.decode([String: Layout].self, from: data) {
      return layouts
    }
    return decodeEachEntryThatStillParses(data, using: decoder)
  }

  private static func decodeEachEntryThatStillParses(_ data: Data, using decoder: JSONDecoder) -> [String: Layout] {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    var surviving: [String: Layout] = [:]
    for (fingerprint, value) in object {
      guard
        let entryData = try? JSONSerialization.data(withJSONObject: value),
        let layout = try? decoder.decode(Layout.self, from: entryData)
      else { continue }
      surviving[fingerprint] = layout
    }
    return surviving
  }
}
