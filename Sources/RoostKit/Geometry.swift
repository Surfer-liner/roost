import CoreGraphics

public enum Geometry {
  public static func isSettled(_ observed: CGRect, at target: CGRect, positionTolerance: Double = 8, sizeTolerance: Double = 24) -> Bool {
    abs(observed.origin.x - target.origin.x) <= positionTolerance &&
      abs(observed.origin.y - target.origin.y) <= positionTolerance &&
      abs(observed.width - target.width) <= sizeTolerance &&
      abs(observed.height - target.height) <= sizeTolerance
  }
}
