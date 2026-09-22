import CoreGraphics

public enum Geometry {
  public static func isSettled(_ observed: CGRect, at target: CGRect, positionTolerance: Double = 8, sizeTolerance: Double = 24) -> Bool {
    let widthSlack = max(sizeTolerance, target.width * 0.12)
    let heightSlack = max(sizeTolerance, target.height * 0.12)
    return abs(observed.origin.x - target.origin.x) <= positionTolerance &&
      abs(observed.origin.y - target.origin.y) <= positionTolerance &&
      abs(observed.width - target.width) <= widthSlack &&
      abs(observed.height - target.height) <= heightSlack
  }

  public static func hasNotMoved(_ observed: CGRect, since previous: CGRect) -> Bool {
    abs(observed.origin.x - previous.origin.x) <= 2 &&
      abs(observed.origin.y - previous.origin.y) <= 2 &&
      abs(observed.width - previous.width) <= 2 &&
      abs(observed.height - previous.height) <= 2
  }
}
