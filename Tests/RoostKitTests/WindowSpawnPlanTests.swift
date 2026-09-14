import Testing
@testable import RoostKit

@Suite struct WindowSpawnPlanTests {
  private func plan(needed: Int, have: Int, attempts: Int = 0, sinceLast: Int = 99, gap: Int = 3, maxAttempts: Int = 5) -> WindowSpawnPlan {
    WindowSpawnPlan(
      neededWindows: needed,
      currentWindows: have,
      attemptsSoFar: attempts,
      passesSinceLastAttempt: sinceLast,
      minPassesBetweenAttempts: gap,
      maxAttempts: maxAttempts
    )
  }

  @Test func spawnsWhenAWindowIsMissing() {
    #expect(plan(needed: 3, have: 1).shouldSpawnOne)
  }

  @Test func staysQuietWhenEveryWindowIsPresent() {
    #expect(!plan(needed: 2, have: 2).shouldSpawnOne)
  }

  @Test func staysQuietWhenThereAreMoreWindowsThanSaved() {
    #expect(!plan(needed: 1, have: 3).shouldSpawnOne)
  }

  @Test func waitsBetweenAttemptsSoNewWindowsHaveTimeToAppear() {
    #expect(!plan(needed: 3, have: 1, sinceLast: 1, gap: 3).shouldSpawnOne)
    #expect(plan(needed: 3, have: 1, sinceLast: 3, gap: 3).shouldSpawnOne)
  }

  @Test func givesUpAfterTooManyFruitlessAttempts() {
    #expect(!plan(needed: 3, have: 1, attempts: 5, maxAttempts: 5).shouldSpawnOne)
  }
}
