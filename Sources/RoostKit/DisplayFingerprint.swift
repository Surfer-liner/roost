public enum DisplayFingerprint {
  public static func current() -> String {
    fingerprint(of: DisplayGeometry.currentDisplays())
  }

  static func fingerprint(of displays: [DisplaySnapshot]) -> String {
    displays.map { $0.key }.sorted().joined(separator: " + ")
  }
}
