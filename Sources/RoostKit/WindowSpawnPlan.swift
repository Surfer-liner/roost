public struct WindowSpawnPlan {
  public let neededWindows: Int
  public let currentWindows: Int
  public let attemptsSoFar: Int
  public let passesSinceLastAttempt: Int
  public let minPassesBetweenAttempts: Int
  public let maxAttempts: Int

  public init(
    neededWindows: Int,
    currentWindows: Int,
    attemptsSoFar: Int,
    passesSinceLastAttempt: Int,
    minPassesBetweenAttempts: Int,
    maxAttempts: Int
  ) {
    self.neededWindows = neededWindows
    self.currentWindows = currentWindows
    self.attemptsSoFar = attemptsSoFar
    self.passesSinceLastAttempt = passesSinceLastAttempt
    self.minPassesBetweenAttempts = minPassesBetweenAttempts
    self.maxAttempts = maxAttempts
  }

  public var isMissingWindows: Bool {
    currentWindows < neededWindows
  }

  public var hasAttemptsLeft: Bool {
    attemptsSoFar < maxAttempts
  }

  public var shouldSpawnOne: Bool {
    isMissingWindows && hasAttemptsLeft && passesSinceLastAttempt >= minPassesBetweenAttempts
  }
}
