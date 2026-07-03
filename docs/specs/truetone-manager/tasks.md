# Implementation Plan: TrueTone Manager

## Overview

This implementation plan breaks down the TrueTone Manager macOS menu bar application into discrete coding tasks. The application is built with Swift and AppKit, using a layered architecture with five core components: Application Monitor, TrueTone Controller, Preference Store, TrueTone Manager (coordinator), and Menu Bar Interface.

The implementation follows a bottom-up approach, building foundational components first (data models, storage, system integrations) before assembling them into the coordinator and UI layers. Property-based tests validate universal correctness properties defined in the design, while unit tests cover specific examples and edge cases.

## Tasks

- [x] 1. Set up project structure and core data models
  - Create Xcode project with Swift 5.9+ targeting macOS 13+
  - Set up project directory structure (Sources/, Tests/, Resources/)
  - Define `AppPreference` struct with Codable conformance
  - Define `PreferenceCollection` struct for JSON persistence
  - Define `TrueToneState` enum with bool conversion
  - Define error types: `ApplicationMonitorError`, `TrueToneControllerError`, `PreferenceStoreError`
  - Configure Swift Package Manager dependencies (SwiftCheck for property-based testing)
  - Set up test targets: PropertyTests, UnitTests, IntegrationTests
  - _Requirements: 3.1, 10.6_

- [ ] 2. Implement Preference Store component
  - [x] 2.1 Create PreferenceStore class with in-memory cache
    - Implement `PreferenceStore` class with dictionary-based in-memory cache
    - Implement `loadPreferences()` to read JSON from `~/Library/Application Support/TrueToneManager/preferences.json`
    - Implement `savePreferences()` with atomic file writes
    - Implement `getPreference(for:)` with O(1) lookup from cache
    - Implement `getAllPreferences()` returning all cached preferences
    - Implement `setPreference(_:)` with immediate persistence
    - Implement `removePreference(for:)` with immediate persistence
    - Add validation to reject empty bundle identifiers
    - Handle corrupted JSON by renaming file and starting fresh
    - Use async file I/O to avoid blocking main thread
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 3.7, 3.9, 10.3, 10.4, 10.6_

  - [x]* 2.2 Write property test for preference upsert (Property 6)
    - **Property 6: Preference Upsert**
    - **Validates: Requirements 3.1, 3.2, 3.4**
    - Test that adding any valid AppPreference persists it and subsequent queries return matching data
    - Test that adding a preference with existing bundle identifier replaces the old preference
    - Use SwiftCheck with custom AppPreference generator
    - Minimum 100 iterations

  - [x]* 2.3 Write property test for preference deletion (Property 7)
    - **Property 7: Preference Deletion**
    - **Validates: Requirements 3.3**
    - Test that removing any existing preference results in subsequent queries returning null
    - Use SwiftCheck with custom AppPreference generator
    - Minimum 100 iterations

  - [x]* 2.4 Write property test for preference persistence round-trip (Property 25)
    - **Property 25: Preference Persistence Round-Trip**
    - **Validates: Requirements 10.7**
    - Test that saving then loading any valid preference collection preserves bundle identifiers and TrueTone states
    - Use SwiftCheck with custom preference collection generator
    - Minimum 100 iterations

  - [ ]* 2.5 Write unit tests for PreferenceStore edge cases
    - Test empty bundle identifier rejection
    - Test corrupted JSON file handling (rename and start fresh)
    - Test file I/O error handling
    - Test empty preference collection initialization
    - Test performance: lookup <50ms, load <500ms
    - _Requirements: 3.5, 3.8, 3.9, 3.10, 10.5_

- [ ] 3. Implement TrueTone Controller component
  - [x] 3.1 Create TrueToneController class with CoreBrightness integration
    - Implement `TrueToneController` class
    - Link against CoreBrightness private framework (`/System/Library/PrivateFrameworks/CoreBrightness.framework`)
    - Implement `getCurrentState()` using `CBBlueLightClient.getBlueLightStatus()`
    - Implement `setTrueTone(enabled:)` using `CBBlueLightClient.setBlueLightEnabled(_:)`
    - Implement `isSupported()` to check TrueTone hardware capability
    - Cache current TrueTone state to avoid unnecessary system calls
    - Verify state after changes by re-querying system
    - Map system error codes to `TrueToneControllerError` types
    - Add fallback to IOKit if CoreBrightness unavailable
    - _Requirements: 2.1, 2.2, 2.5, 2.10_

  - [x]* 3.2 Write property test for TrueTone state transitions (Property 3)
    - **Property 3: TrueTone State Transitions**
    - **Validates: Requirements 2.1, 2.2, 2.6**
    - Test that requesting any TrueTone state when current state differs results in successful transition
    - Use SwiftCheck with bool generator for enabled/disabled states
    - Mock CoreBrightness API for testing
    - Minimum 100 iterations

  - [x]* 3.3 Write property test for TrueTone control idempotence (Property 4)
    - **Property 4: TrueTone Control Idempotence**
    - **Validates: Requirements 2.3, 2.4**
    - Test that requesting any TrueTone state when already in that state returns success without modification
    - Verify f(x) = f(f(x)) property
    - Use SwiftCheck with bool generator
    - Minimum 100 iterations

  - [ ]* 3.4 Write property test for system error propagation (Property 5)
    - **Property 5: System Error Propagation**
    - **Validates: Requirements 2.9**
    - Test that any system API error includes underlying error details in returned error message
    - Use SwiftCheck with error generator
    - Mock CoreBrightness to return various error codes
    - Minimum 100 iterations

  - [ ]* 3.5 Write unit tests for TrueToneController error handling
    - Test permission denied error with actionable message
    - Test unsupported hardware error detection
    - Test state verification after changes
    - Test performance: state change <200ms
    - Test initialization queries current state
    - _Requirements: 2.7, 2.8, 2.9, 2.10_

- [ ] 4. Implement Application Monitor component
  - [x] 4.1 Create ApplicationMonitor class with NSWorkspace integration
    - Implement `ApplicationMonitor` class with delegate pattern
    - Subscribe to `NSWorkspace.didActivateApplicationNotification` in `start()`
    - Extract `bundleIdentifier` and `localizedName` from `NSRunningApplication`
    - Implement 100ms debounce timer to prevent rapid-fire notifications
    - Cache last reported bundle identifier to avoid duplicates
    - Implement `getCurrentApplication()` querying `NSWorkspace.shared.frontmostApplication`
    - Call `getCurrentApplication()` on startup to detect initial app
    - Implement `stop()` to unsubscribe from notifications
    - Handle missing bundle identifiers by notifying delegate with error
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x]* 4.2 Write property test for application change notification correctness (Property 1)
    - **Property 1: Application Change Notification Correctness**
    - **Validates: Requirements 1.2**
    - Test that any application change event with valid bundle identifier notifies manager with correct bundle identifier
    - Use SwiftCheck with bundle identifier generator
    - Mock NSWorkspace notifications
    - Minimum 100 iterations

  - [ ]* 4.3 Write property test for application monitoring error handling (Property 2)
    - **Property 2: Application Monitoring Error Handling**
    - **Validates: Requirements 1.6**
    - Test that any application change event where system API fails attempts to extract bundle identifier or notifies with error
    - Use SwiftCheck with error scenario generator
    - Mock NSWorkspace API failures
    - Minimum 100 iterations

  - [ ]* 4.4 Write unit tests for ApplicationMonitor edge cases
    - Test debounce timer prevents rapid notifications
    - Test duplicate notification suppression
    - Test startup detection within 100ms
    - Test notification timing <500ms
    - Test workspace unavailable error handling
    - _Requirements: 1.1, 1.4, 1.5, 1.6_

- [x] 5. Checkpoint - Core components complete
  - Ensure all tests pass for PreferenceStore, TrueToneController, and ApplicationMonitor
  - Verify each component works independently with mocked dependencies
  - Ask the user if questions arise

- [ ] 6. Implement TrueTone Manager coordinator
  - [x] 6.1 Create TrueToneManager singleton class
    - Implement `TrueToneManager` as singleton with `shared` instance
    - Initialize with `ApplicationMonitor`, `TrueToneController`, and `PreferenceStore` instances
    - Implement `start()` to initialize all components and load preferences
    - Implement `stop()` to clean up and save preferences
    - Implement delegate methods for `ApplicationMonitorDelegate`
    - Implement `handleApplicationChange(bundleIdentifier:)` business logic
    - Query preference store for bundle identifier
    - If preference exists and differs from current state, request state change
    - Verify state change succeeded by re-querying controller
    - If no preference exists, maintain current state
    - Implement single retry with 1-second delay on failure
    - Implement `setPreferenceForCurrentApp(enabled:)` for quick toggle
    - Implement `removePreferenceForCurrentApp()` for preference removal
    - Add properties: `currentApplication`, `currentTrueToneState`
    - Log all state transitions using os_log
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.10_

  - [x]* 6.2 Write property test for automatic TrueTone adjustment (Property 9)
    - **Property 9: Automatic TrueTone Adjustment**
    - **Validates: Requirements 4.1, 4.2**
    - Test that any application change with existing preference applies the specified TrueTone state
    - Use SwiftCheck with AppPreference and bundle identifier generators
    - Mock all component dependencies
    - Minimum 100 iterations

  - [x]* 6.3 Write property test for no-change optimization (Property 10)
    - **Property 10: No-Change Optimization**
    - **Validates: Requirements 4.3**
    - Test that any application change where preference matches current state does not request state change
    - Use SwiftCheck with matching state generator
    - Verify controller's setTrueTone is not called
    - Minimum 100 iterations

  - [x]* 6.4 Write property test for maintain state without preference (Property 11)
    - **Property 11: Maintain State Without Preference**
    - **Validates: Requirements 4.4**
    - Test that any application change without preference maintains current TrueTone state
    - Use SwiftCheck with bundle identifier generator
    - Verify no state change requests
    - Minimum 100 iterations

  - [ ]* 6.5 Write property test for storage failure handling (Property 12)
    - **Property 12: Storage Failure Handling**
    - **Validates: Requirements 4.7**
    - Test that any preference store failure maintains current state and logs error
    - Use SwiftCheck with error scenario generator
    - Mock PreferenceStore to fail
    - Minimum 100 iterations

  - [ ]* 6.6 Write property test for state recording before changes (Property 13)
    - **Property 13: State Recording Before Changes**
    - **Validates: Requirements 4.10**
    - Test that any application change triggering adjustment records current state before changes
    - Use SwiftCheck with state transition generator
    - Verify logging captures pre-change state
    - Minimum 100 iterations

  - [ ]* 6.7 Write unit tests for TrueToneManager coordination logic
    - Test retry logic (single retry after 1 second)
    - Test state verification after changes
    - Test error notification deduplication (Property 24)
    - Test timing: adjustment complete within 500ms
    - Test initialization loads preferences and queries current app
    - _Requirements: 4.5, 4.6, 4.8, 4.9, 9.4_

- [ ] 7. Implement Menu Bar Interface - Status Item and Main Menu
  - [x] 7.1 Create MenuBarInterface class with NSStatusItem
    - Implement `MenuBarInterface` class
    - Create status item with `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)`
    - Set status item icon to SF Symbol "sun.max"
    - Create `NSMenu` with dynamic menu items
    - Implement `setup()` to initialize status item and menu
    - Implement `updateMenu()` to refresh menu items based on current state
    - Display current application name (truncate to 27 chars + "..." if >30 chars)
    - Display current TrueTone state as "TrueTone: On" or "TrueTone: Off"
    - Implement dynamic menu item logic based on preference existence and TrueTone state
    - Show "Always Enable for [App]" when no preference and TrueTone off
    - Show "Always Disable for [App]" when no preference and TrueTone on
    - Show "Remove Preference for [App]" when preference exists
    - Add "Preferences..." menu item
    - Add "Launch at Login" toggle menu item with checkmark
    - Add "Quit TrueTone Manager" menu item
    - Implement menu item actions calling TrueToneManager methods
    - Disable menu items during async operations
    - Implement `showNotification(title:message:type:)` using NSUserNotification
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 7.1, 7.2, 7.3_

  - [ ]* 7.2 Write property test for application name display (Property 14)
    - **Property 14: Application Name Display**
    - **Validates: Requirements 5.3**
    - Test that any foreground application with display name shows that name in menu
    - Use SwiftCheck with application name generator
    - Minimum 100 iterations

  - [ ]* 7.3 Write property test for name truncation (Property 15)
    - **Property 15: Name Truncation**
    - **Validates: Requirements 5.4**
    - Test that any application name exceeding 30 characters truncates to exactly 27 + "..."
    - Use SwiftCheck with long string generator
    - Minimum 100 iterations

  - [ ]* 7.4 Write property test for menu item logic (Property 16)
    - **Property 16: Menu Item Logic Based on State**
    - **Validates: Requirements 5.6, 5.7, 5.8**
    - Test that any combination of (has preference, TrueTone state) displays correct menu item
    - Use SwiftCheck with state combination generator
    - Minimum 100 iterations

  - [ ]* 7.5 Write property test for quick toggle preference creation (Property 22)
    - **Property 22: Quick Toggle Preference Creation**
    - **Validates: Requirements 7.4, 7.5**
    - Test that any current app without preference creates preference with selected state when toggled
    - Use SwiftCheck with bundle identifier and state generators
    - Minimum 100 iterations

  - [ ]* 7.6 Write property test for quick toggle error handling (Property 23)
    - **Property 23: Quick Toggle Error Handling**
    - **Validates: Requirements 7.7**
    - Test that any quick toggle where persistence fails displays error and does not change TrueTone state
    - Use SwiftCheck with error scenario generator
    - Minimum 100 iterations

  - [ ]* 7.7 Write unit tests for MenuBarInterface main menu
    - Test menu display timing <200ms
    - Test menu item enable/disable during operations
    - Test quit menu item functionality
    - Test visual feedback timing <500ms
    - Test notification auto-dismiss after 10 seconds
    - _Requirements: 5.2, 5.10, 7.6, 9.5, 9.6_

- [ ] 8. Implement Preferences Window
  - [x] 8.1 Create PreferencesWindowController with NSTableView
    - Implement `PreferencesWindowController` class
    - Create window with NSTableView for preference list
    - Configure table view with two columns: Application Name, TrueTone State
    - Add NSSwitch controls for toggling TrueTone state
    - Add Remove buttons with destructive style
    - Implement "Add Running Application" button
    - Implement `showAddApplicationSheet()` displaying running apps from NSWorkspace
    - Filter out system apps and apps without bundle identifiers
    - Implement `reloadData()` to refresh table view
    - Connect toggle actions to PreferenceStore.setPreference
    - Connect remove actions to PreferenceStore.removePreference
    - Display "No preferences configured" when empty
    - Update display within 200ms after modifications
    - Implement real-time updates via PreferenceStoreDelegate
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.10_

  - [ ]* 8.2 Write property test for preference list display (Property 17)
    - **Property 17: Preference List Display**
    - **Validates: Requirements 6.2, 6.3**
    - Test that any collection of preferences displays all with correct names and states
    - Use SwiftCheck with preference collection generator
    - Minimum 100 iterations

  - [ ]* 8.3 Write property test for preference toggle (Property 18)
    - **Property 18: Preference Toggle**
    - **Validates: Requirements 6.4**
    - Test that any displayed preference toggles state and persists change
    - Use SwiftCheck with AppPreference generator
    - Minimum 100 iterations

  - [ ]* 8.4 Write property test for preference removal from UI (Property 19)
    - **Property 19: Preference Removal from UI**
    - **Validates: Requirements 6.5**
    - Test that any displayed preference removes from store when remove button clicked
    - Use SwiftCheck with AppPreference generator
    - Minimum 100 iterations

  - [ ]* 8.5 Write property test for preference addition from UI (Property 20)
    - **Property 20: Preference Addition from UI**
    - **Validates: Requirements 6.7**
    - Test that any running application selected from add list persists preference
    - Use SwiftCheck with bundle identifier and state generators
    - Minimum 100 iterations

  - [ ]* 8.6 Write property test for UI error handling (Property 21)
    - **Property 21: UI Error Handling**
    - **Validates: Requirements 6.9**
    - Test that any preference modification failure displays error message
    - Use SwiftCheck with error scenario generator
    - Minimum 100 iterations

  - [ ]* 8.7 Write unit tests for PreferencesWindowController
    - Test window display timing <500ms
    - Test table view update timing <200ms
    - Test empty state message display
    - Test running apps list filtering (exclude system apps)
    - Test error message display on persistence failure
    - _Requirements: 6.1, 6.8, 6.9, 6.10_

- [x] 9. Checkpoint - UI components complete
  - Ensure all tests pass for MenuBarInterface and PreferencesWindowController
  - Verify menu bar icon appears and menu displays correctly
  - Test preferences window opens and displays data
  - Ask the user if questions arise

- [ ] 10. Implement Launch at Login functionality
  - [x] 10.1 Add launch at login support using SMAppService
    - Implement launch at login toggle in MenuBarInterface
    - Use `SMAppService` API for macOS 13+ (preferred)
    - Add fallback to `SMLoginItemSetEnabled` for macOS 12 and earlier
    - Implement registration: `SMAppService.mainApp.register()`
    - Implement unregistration: `SMAppService.mainApp.unregister()`
    - Query current state: `SMAppService.mainApp.status`
    - Update menu checkmark within 1 second of toggle
    - Handle registration failures with error notification
    - Maintain unchanged state on failure
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [ ]* 10.2 Write unit tests for launch at login
    - Test registration success updates checkmark
    - Test unregistration removes checkmark
    - Test registration failure displays error and maintains state
    - Test checkmark update timing <1 second
    - Test state persistence across app restarts
    - _Requirements: 8.1, 8.2, 8.5, 8.6, 8.7_

- [ ] 11. Implement error handling and notifications
  - [x] 11.1 Add comprehensive error handling and user notifications
    - Implement error notification system using NSUserNotification
    - Create notification templates for permission errors, hardware errors, storage errors
    - Implement error deduplication: track shown errors per session
    - Implement auto-dismiss after 10 seconds
    - Add user-dismissible notification actions
    - Implement logging using os_log with appropriate log levels
    - Log errors with timestamp, component, and error details
    - Implement retry logic for application monitoring failures (5s, 10s, 20s exponential backoff)
    - Ensure graceful degradation: continue running even if TrueTone control fails
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [ ]* 11.2 Write property test for error notification deduplication (Property 24)
    - **Property 24: Error Notification Deduplication**
    - **Validates: Requirements 9.4**
    - Test that any error type produces at most one notification per session
    - Use SwiftCheck with error type generator
    - Minimum 100 iterations

  - [ ]* 11.3 Write unit tests for error handling
    - Test permission error notification content and actionable guidance
    - Test hardware error notification content
    - Test storage error notification content
    - Test notification display timing <1 second
    - Test auto-dismiss after 10 seconds
    - Test application monitoring retry with exponential backoff
    - _Requirements: 9.1, 9.2, 9.3, 9.5, 9.6_

- [ ] 12. Implement state persistence and recovery
  - [x] 12.1 Add application lifecycle management
    - Implement `applicationWillTerminate` to save preferences
    - Handle save failures by logging error and notifying user
    - Allow application to quit even if save fails
    - Implement `applicationDidFinishLaunching` to load preferences
    - Handle missing preference file by initializing empty collection
    - Handle corrupted preference file by creating new empty file and logging error
    - Ensure preference directory exists: `~/Library/Application Support/TrueToneManager/`
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 12.2 Write unit tests for state persistence
    - Test preferences save on quit
    - Test save failure logs error and notifies user
    - Test application quits even if save fails
    - Test preferences load on launch
    - Test missing file initializes empty collection
    - Test corrupted file creates new empty file
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 13. Checkpoint - Error handling and persistence complete
  - Ensure all tests pass for error handling and state persistence
  - Test application lifecycle: launch, run, quit, relaunch
  - Verify preferences persist across restarts
  - Verify error notifications display correctly
  - Ask the user if questions arise

- [ ] 14. Create custom generators for property-based testing
  - [x] 14.1 Implement SwiftCheck generators
    - Create `BundleIdentifierGenerator.swift` with valid bundle identifier generator
    - Create `AppPreferenceGenerator.swift` with AppPreference generator
    - Create `TrueToneStateGenerator.swift` with state generator
    - Create preference collection generator for arrays of AppPreference
    - Create error scenario generators for testing failure paths
    - Create state combination generators for menu item logic testing
    - Ensure generators produce valid domain values
    - _Requirements: All (testing infrastructure)_

- [ ] 15. Integration testing and end-to-end workflows
  - [x] 15.1 Write integration tests for complete workflows
    - Test end-to-end application switch workflow with preference
    - Test end-to-end quick toggle workflow
    - Test end-to-end preferences window workflow
    - Test application monitoring latency <500ms
    - Test TrueTone control latency <200ms
    - Test preference load time <500ms on startup
    - Test menu display time <200ms on click
    - Test launch at login registration and verification
    - Test notification display and dismissal
    - Mock system APIs: CoreBrightness, NSWorkspace, FileManager
    - Use dependency injection for mock swapping
    - _Requirements: 1.1, 2.5, 3.10, 5.2, 6.1_

  - [ ]* 15.2 Write performance tests
    - Test preference lookup <50ms
    - Test preference load <500ms
    - Test TrueTone state change <200ms
    - Test application change detection <500ms
    - Test menu display <200ms
    - Test preferences window display <500ms
    - _Requirements: 2.5, 3.6, 3.7, 4.5, 5.2, 6.1_

- [ ] 16. Final integration and polish
  - [x] 16.1 Wire all components together in AppDelegate
    - Create `AppDelegate` class conforming to NSApplicationDelegate
    - Initialize TrueToneManager.shared in applicationDidFinishLaunching
    - Initialize MenuBarInterface and connect to TrueToneManager
    - Call TrueToneManager.start() to begin monitoring
    - Implement applicationWillTerminate to call TrueToneManager.stop()
    - Set up Info.plist with required permissions (LSUIElement for menu bar app)
    - Configure app icon and bundle identifier
    - Test complete application flow from launch to quit
    - _Requirements: All_

  - [ ]* 16.2 Run full test suite
    - Execute all property tests (minimum 100 iterations each)
    - Execute all unit tests
    - Execute all integration tests
    - Verify all 25 correctness properties pass
    - Verify all 10 requirements are covered
    - Generate test coverage report
    - Ensure >80% code coverage

- [x] 17. Final checkpoint - Application complete
  - Ensure all tests pass
  - Verify application runs end-to-end
  - Test on real macOS hardware with TrueTone support
  - Verify all requirements are met
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at major milestones
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples, edge cases, and error conditions
- Integration tests validate system interactions and timing requirements
- The implementation uses Swift 5.9+ with AppKit for native macOS integration
- CoreBrightness private framework is used for TrueTone control (may require disabling library validation)
- SwiftCheck library is used for property-based testing with minimum 100 iterations per property
- All timing requirements are validated through integration and performance tests

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1"]
    },
    {
      "id": 1,
      "tasks": ["2.1", "14.1"]
    },
    {
      "id": 2,
      "tasks": ["2.2", "2.3", "2.4", "2.5", "3.1"]
    },
    {
      "id": 3,
      "tasks": ["3.2", "3.3", "3.4", "3.5", "4.1"]
    },
    {
      "id": 4,
      "tasks": ["4.2", "4.3", "4.4"]
    },
    {
      "id": 5,
      "tasks": ["6.1"]
    },
    {
      "id": 6,
      "tasks": ["6.2", "6.3", "6.4", "6.5", "6.6", "6.7"]
    },
    {
      "id": 7,
      "tasks": ["7.1"]
    },
    {
      "id": 8,
      "tasks": ["7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "8.1"]
    },
    {
      "id": 9,
      "tasks": ["8.2", "8.3", "8.4", "8.5", "8.6", "8.7"]
    },
    {
      "id": 10,
      "tasks": ["10.1", "11.1", "12.1"]
    },
    {
      "id": 11,
      "tasks": ["10.2", "11.2", "11.3", "12.2"]
    },
    {
      "id": 12,
      "tasks": ["15.1"]
    },
    {
      "id": 13,
      "tasks": ["15.2", "16.1"]
    },
    {
      "id": 14,
      "tasks": ["16.2"]
    }
  ]
}
```
