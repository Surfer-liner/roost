import Foundation

public enum LayoutMatch {
  case sameDisplays
  case differentDisplays
}

public struct LayoutChoice {
  public let layout: Layout
  public let match: LayoutMatch
}

public final class LayoutStore {
  private let fileURL: URL

  public convenience init() {
    self.init(fileURL: LayoutStore.defaultFileURL())
  }

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func layout(for fingerprint: String) -> Layout? {
    loadLayouts()[fingerprint]
  }

  public func bestLayout(for displays: [DisplaySnapshot]) -> LayoutChoice? {
    let newestFirst = loadLayouts().values.sorted { $0.savedAt > $1.savedAt }
    let fingerprint = DisplayFingerprint.fingerprint(of: displays)
    if let same = newestFirst.first(where: { $0.displayFingerprint == fingerprint }) {
      return LayoutChoice(layout: same, match: .sameDisplays)
    }
    guard let newest = newestFirst.first else { return nil }
    return LayoutChoice(layout: newest, match: .differentDisplays)
  }

  public func allLayouts() -> [Layout] {
    loadLayouts().values.sorted { $0.savedAt > $1.savedAt }
  }

  @discardableResult
  public func save(_ layout: Layout) -> Bool {
    var layouts = loadLayouts()
    layouts[layout.displayFingerprint] = layout
    return Self.write(layouts, to: fileURL)
  }

  private func loadLayouts() -> [String: Layout] {
    let (layouts, upgradedSomething) = Self.upgradeLegacyEntries(Self.readLayouts(at: fileURL))
    if upgradedSomething {
      Self.write(layouts, to: fileURL)
    }
    return layouts
  }

  static func upgradeLegacyEntries(_ stored: [String: Layout]) -> (layouts: [String: Layout], upgradedSomething: Bool) {
    var layouts: [String: Layout] = [:]
    var upgradedSomething = false
    for (key, layout) in stored {
      if !layout.displays.isEmpty {
        keepNewer(layout, in: &layouts)
        continue
      }
      let displays = DisplayGeometry.legacyDisplays(fromFingerprint: key)
      guard !displays.isEmpty else {
        layouts[key] = layout
        continue
      }
      let windows = layout.windows.map { window in
        window.onDisplay(DisplayGeometry.display(containing: window.frame.rect, among: displays)?.key)
      }
      let upgraded = Layout(
        displayFingerprint: DisplayFingerprint.fingerprint(of: displays),
        savedAt: layout.savedAt,
        windows: windows,
        displays: displays
      )
      keepNewer(upgraded, in: &layouts)
      upgradedSomething = true
    }
    return (layouts, upgradedSomething)
  }

  private static func keepNewer(_ layout: Layout, in layouts: inout [String: Layout]) {
    if let existing = layouts[layout.displayFingerprint], existing.savedAt > layout.savedAt {
      return
    }
    layouts[layout.displayFingerprint] = layout
  }

  @discardableResult
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
