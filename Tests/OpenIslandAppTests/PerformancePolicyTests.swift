import Foundation
import Testing
@testable import OpenIslandApp

struct PerformancePolicyTests {
    @Test
    func idleUnifiedBarsDoesNotRequireAnimationTimeline() {
        #expect(UnifiedBars.Mode.idle.timelineInterval == nil)
    }

    @Test
    func activeUnifiedBarsDoNotRequireAnimationTimeline() {
        #expect(UnifiedBars.Mode.running.timelineInterval == nil)
        #expect(UnifiedBars.Mode.waiting.timelineInterval == nil)
    }

    @Test
    func activeUnifiedBarsUseCoreAnimationLayerAnimation() {
        #expect(!UnifiedBars.Mode.idle.usesLayerAnimation)
        #expect(UnifiedBars.Mode.running.usesLayerAnimation)
        #expect(UnifiedBars.Mode.waiting.usesLayerAnimation)
    }

    @MainActor
    @Test
    func monitoringPollIntervalBacksOffOutsideStartupResolution() {
        #expect(ProcessMonitoringCoordinator.monitoringPollInterval(
            isResolvingInitialLiveSessions: true,
            hasTrackedLiveSessions: false
        ) == 2)
        #expect(ProcessMonitoringCoordinator.monitoringPollInterval(
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: true
        ) == 60)
        #expect(ProcessMonitoringCoordinator.monitoringPollInterval(
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: false
        ) == 300)
    }

    @MainActor
    @Test
    func codexDesktopMaintenanceKeepsShortWakeCadenceOnlyWhileCodexAppRuns() {
        #expect(ProcessMonitoringCoordinator.monitoringWakeInterval(
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: false,
            isCodexAppRunning: true
        ) == 2)
        #expect(ProcessMonitoringCoordinator.monitoringWakeInterval(
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: true,
            isCodexAppRunning: true
        ) == 2)
    }

    @MainActor
    @Test
    func monitoringWakeBacksOffToPollCadenceWhileCodexAppIsNotRunning() {
        #expect(ProcessMonitoringCoordinator.monitoringWakeInterval(
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: false,
            isCodexAppRunning: false
        ) == 300)
        #expect(ProcessMonitoringCoordinator.monitoringWakeInterval(
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: true,
            isCodexAppRunning: false
        ) == 60)
        #expect(ProcessMonitoringCoordinator.monitoringWakeInterval(
            isResolvingInitialLiveSessions: true,
            hasTrackedLiveSessions: false,
            isCodexAppRunning: false
        ) == 2)
    }

    @MainActor
    @Test
    func trackedSessionTransitionForcesFullReconcileBeforeIdleDeadline() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let idleDeadline = now.addingTimeInterval(300)

        #expect(!ProcessMonitoringCoordinator.shouldPerformFullMonitorReconcile(
            now: now,
            nextFullReconcileAt: idleDeadline,
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: false,
            hadTrackedLiveSessions: false
        ))
        #expect(ProcessMonitoringCoordinator.shouldPerformFullMonitorReconcile(
            now: now,
            nextFullReconcileAt: idleDeadline,
            isResolvingInitialLiveSessions: false,
            hasTrackedLiveSessions: true,
            hadTrackedLiveSessions: false
        ))
    }

    @MainActor
    @Test
    func registryPersistenceSkipsWhenRecordsAreUnchanged() {
        #expect(SessionDiscoveryCoordinator.shouldPersistRecords(["a"], lastSaved: nil))
        #expect(SessionDiscoveryCoordinator.shouldPersistRecords(["a"], lastSaved: ["b"]))
        #expect(!SessionDiscoveryCoordinator.shouldPersistRecords(["a"], lastSaved: ["a"]))
        #expect(SessionDiscoveryCoordinator.shouldPersistRecords([String](), lastSaved: nil))
        #expect(!SessionDiscoveryCoordinator.shouldPersistRecords([String](), lastSaved: []))
    }

    @MainActor
    @Test
    func registryPersistenceDebounceCoalescesEventBursts() {
        #expect(SessionDiscoveryCoordinator.persistenceDebounceMilliseconds >= 1_000)
    }

    @Test
    func jetBrainsWindowTitleMatchesProjectBasename() {
        // Typical IntelliJ titles: "project – file.swift", "project [module]", bare "project".
        #expect(TerminalJumpService.jetBrainsWindowTitleMatches(
            title: "open-vibe-island – TerminalJumpService.swift", projectBasename: "open-vibe-island"))
        #expect(TerminalJumpService.jetBrainsWindowTitleMatches(
            title: "onepiece", projectBasename: "onepiece"))
        #expect(TerminalJumpService.jetBrainsWindowTitleMatches(
            title: "onepiece [back]", projectBasename: "onepiece"))
        // Prefix of a longer project name must NOT match.
        #expect(!TerminalJumpService.jetBrainsWindowTitleMatches(
            title: "onepiece-v2 – Main.kt", projectBasename: "onepiece"))
        #expect(!TerminalJumpService.jetBrainsWindowTitleMatches(
            title: "Welcome to IntelliJ IDEA", projectBasename: "onepiece"))
        #expect(!TerminalJumpService.jetBrainsWindowTitleMatches(
            title: "", projectBasename: "onepiece"))
    }

    @Test
    func jetBrainsProjectRootResolvesSessionCwdToOpenedProject() {
        let opened = ["/U/j/src/onepiece", "/U/j/src/FNB-DCT-MIDDLEWARE"]
        let recent = opened + ["/U/j/src/onepiece-middleware", "/U/j/src/planner"]

        // cwd inside an opened project resolves to that project root.
        #expect(TerminalJumpService.jetBrainsBestProjectRoot(
            for: "/U/j/src/onepiece/specs/001-wfj/contracts", opened: opened, recent: recent
        ) == "/U/j/src/onepiece")
        // cwd exactly at the project root.
        #expect(TerminalJumpService.jetBrainsBestProjectRoot(
            for: "/U/j/src/onepiece", opened: opened, recent: recent
        ) == "/U/j/src/onepiece")
        // "onepiece-middleware" must not be trapped by the "onepiece" prefix.
        #expect(TerminalJumpService.jetBrainsBestProjectRoot(
            for: "/U/j/src/onepiece-middleware/sub", opened: opened, recent: recent
        ) == "/U/j/src/onepiece-middleware")
        // Unknown cwd: no resolution.
        #expect(TerminalJumpService.jetBrainsBestProjectRoot(
            for: "/tmp/elsewhere", opened: opened, recent: recent
        ) == nil)
    }

    @Test
    func jetBrainsRecentProjectsXMLParsesOpenedAndRecentEntries() {
        let xml = """
        <application>
          <component name="RecentProjectsManager">
            <option name="additionalInfo">
              <map>
                <entry key="$USER_HOME$/src/alpha">
                  <value><RecentProjectMetaInfo frameTitle="alpha"></RecentProjectMetaInfo></value>
                </entry>
                <entry key="$USER_HOME$/src/beta">
                  <value><RecentProjectMetaInfo opened="true" frameTitle="beta"></RecentProjectMetaInfo></value>
                </entry>
              </map>
            </option>
          </component>
        </application>
        """
        let parsed = TerminalJumpService.jetBrainsProjects(fromRecentProjectsXML: xml, homeDirectory: "/Users/x")
        #expect(parsed.opened == ["/Users/x/src/beta"])
        #expect(parsed.recent.sorted() == ["/Users/x/src/alpha", "/Users/x/src/beta"])
    }

    @Test
    func inactiveSessionDotDoesNotRequireAnimationTimeline() {
        #expect(IslandSessionStateIndicator.animatedDot.timelineInterval(
            presence: .inactive,
            isActionable: false
        ) == nil)
        #expect(IslandSessionStateIndicator.animatedDot.timelineInterval(
            presence: .active,
            isActionable: false
        ) == nil)
        #expect(IslandSessionStateIndicator.animatedDot.timelineInterval(
            presence: .running,
            isActionable: false
        ) == 1.0 / 15.0)
        #expect(IslandSessionStateIndicator.animatedDot.timelineInterval(
            presence: .inactive,
            isActionable: true
        ) == 1.0 / 15.0)
    }
}
