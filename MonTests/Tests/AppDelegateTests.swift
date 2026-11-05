//
//  AppDelegateTests.swift
//  MonTests
//
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Mon
import ApplicationServices
import Nimble
import Quick
import ServiceManagement
import Silica

class AppDelegateTests: QuickSpec {
    override func spec() {
        describe("Start at Login presentation") {
            it("shows enabled registration") {
                let presentation = LoginItemPresentation(status: .enabled)

                expect(presentation.title).to(equal("Start Mon on Login"))
                expect(presentation.state).to(equal(.on))
                expect(presentation.isEnabled).to(beTrue())
            }

            it("keeps unregistered state actionable") {
                let presentation = LoginItemPresentation(status: .notRegistered)

                expect(presentation.state).to(equal(.off))
                expect(presentation.isEnabled).to(beTrue())
            }

            it("surfaces approval as an actionable mixed state") {
                let presentation = LoginItemPresentation(status: .requiresApproval)

                expect(presentation.title).to(contain("Approve"))
                expect(presentation.state).to(equal(.mixed))
                expect(presentation.isEnabled).to(beTrue())
                expect(presentation.guidance).to(contain("Login Items"))
                expect(presentation.guidance).to(contain("Mon"))
                expect(presentation.guidance).toNot(contain("Amethyst"))
            }

            it("guides the user to add a missing service manually") {
                let presentation = LoginItemPresentation(status: .notFound)

                expect(presentation.title).to(contain("Add in System Settings"))
                expect(presentation.state).to(equal(.off))
                expect(presentation.isEnabled).to(beTrue())
                expect(presentation.needsManualAction).to(beTrue())
                expect(presentation.guidance).to(contain("Login Items"))
            }
        }

        describe("Displays preferences pane") {
            it("persists new desktop defaults without changing a current desktop") {
                var persisted: [DisplayDefaults] = []
                let handler = DisplayDefaultsChangeHandler { defaults in
                    persisted.append(defaults)
                }

                handler.handle(tilingEnabled: true, layoutKey: "wide")

                expect(persisted).to(equal([DisplayDefaults(tilingEnabled: true, layoutKey: "wide")]))
            }

            it("keeps existing desktop controls connected to their manager actions") { @MainActor in
                var selectedLayouts: [String] = []
                var tilingStates: [Bool] = []
                let handler = SpaceConfigurationHandler(
                    setLayout: { selectedLayouts.append($0) },
                    setTilingEnabled: { tilingStates.append($0) }
                )
                let popup = NSPopUpButton()
                popup.addItem(withTitle: "Wide")
                popup.lastItem?.representedObject = "wide"
                let checkbox = NSButton(checkboxWithTitle: "Tiling", target: nil, action: nil)
                handler.checkbox = checkbox

                popup.selectItem(at: 0)
                handler.layoutChanged(popup)

                expect(selectedLayouts).to(equal(["wide"]))
                expect(checkbox.state).to(equal(.on))

                checkbox.state = .off
                handler.tilingChanged(checkbox)
                expect(tilingStates).to(equal([false]))
            }
        }

        describe("login item migration notice") {
            var defaults: UserDefaults!
            let suiteName = "com.amethyst.tests.login-item-migration-notice"
            let notice = LoginItemMigrationNotice(defaultsKey: "did-show-notice")

            beforeEach {
                defaults = UserDefaults(suiteName: suiteName)!
                defaults.removePersistentDomain(forName: suiteName)
            }

            afterEach {
                defaults.removePersistentDomain(forName: suiteName)
                defaults = nil
            }

            it("presents once on first launch") {
                expect(notice.shouldPresent(in: defaults)).to(beTrue())

                notice.markPresented(in: defaults)

                expect(notice.shouldPresent(in: defaults)).to(beFalse())
            }

            it("stays dismissed after subsequent launches") {
                notice.markPresented(in: defaults)

                expect(notice.shouldPresent(in: defaults)).to(beFalse())
                expect(notice.shouldPresent(in: defaults)).to(beFalse())
            }
        }

        describe("runtime status presentation") {
            it("shows nothing when Accessibility and Space commands are available") {
                let titles = RuntimeStatusPresentation.degradedStatusTitles(
                    accessibilityTrusted: true,
                    spaceAvailability: .available
                )

                expect(titles).to(beEmpty())
            }

            it("shows Accessibility guidance when permission is missing") {
                let titles = RuntimeStatusPresentation.degradedStatusTitles(
                    accessibilityTrusted: false,
                    spaceAvailability: .available
                )

                expect(titles).to(equal(["Accessibility permission is required for window management"]))
            }

            it("shows Space disabled reason when Space information is unavailable") {
                let titles = RuntimeStatusPresentation.degradedStatusTitles(
                    accessibilityTrusted: true,
                    spaceAvailability: .disabled(.spaceInformationUnavailable)
                )

                expect(titles.count).to(equal(1))
                expect(titles.first).to(contain("Space commands disabled"))
            }

            it("shows both degradation reasons together") {
                let titles = RuntimeStatusPresentation.degradedStatusTitles(
                    accessibilityTrusted: false,
                    spaceAvailability: .disabled(.currentSpaceNotFound)
                )

                expect(titles.count).to(equal(2))
                expect(titles.first).to(contain("Accessibility permission"))
                expect(titles.last).to(contain("Space commands disabled"))
            }

            it("shows layout restore fallback with otherwise healthy runtime") {
                let titles = RuntimeStatusPresentation.degradedStatusTitles(
                    accessibilityTrusted: true,
                    spaceAvailability: .available,
                    layoutStateRestoreFailed: true
                )

                expect(titles).to(equal([LayoutStateRestorePresentation.failureTitle]))
            }

            it("shows Secure Input guidance without disabling ordinary tiling") {
                let titles = RuntimeStatusPresentation.degradedStatusTitles(
                    accessibilityTrusted: true,
                    spaceAvailability: .available,
                    secureInputEnabled: true
                )

                expect(titles).to(equal([SecureInputPresentation.statusTitle]))
            }
        }

        describe("Accessibility diagnostics") {
            it("reads trust without requesting a system prompt") {
                var promptRequests: [Bool] = []
                let client = AccessibilityClient { shouldPrompt in
                    promptRequests.append(shouldPrompt)
                    return true
                }

                expect(DebugInfo.isProcessTrusted(accessibilityClient: client)).to(beTrue())
                expect(promptRequests).to(equal([false]))
            }
        }

        describe("Separate Spaces diagnostics") {
            it("initializes AppKit before reading the system state") {
                var didInitializeAppKit = false

                let separateSpacesEnabled = DebugInfo.separateSpacesAreEnabled(
                    appKitInitializer: { didInitializeAppKit = true },
                    separateSpacesProvider: { didInitializeAppKit }
                )

                expect(separateSpacesEnabled).to(beTrue())
            }
        }

        describe("layout state restore presentation") {
            it("explains the default-layout fallback") {
                expect(LayoutStateRestorePresentation.failureTitle)
                    .to(equal("Saved layout state could not be restored; using default layouts"))
            }
        }

        describe("current Space tiling presentation") {
            it("hides the action when no current Space is available") {
                let presentation = CurrentSpaceTilingPresentation(isTilingEnabled: nil)

                expect(presentation.title).to(beEmpty())
                expect(presentation.isEnabled).to(beFalse())
                expect(presentation.isVisible).to(beFalse())
            }

            it("offers to disable tiling for the current display and Space") {
                let presentation = CurrentSpaceTilingPresentation(isTilingEnabled: true)

                expect(presentation.title).to(equal("Disable Tiling for This Display & Space"))
                expect(presentation.isEnabled).to(beTrue())
                expect(presentation.isVisible).to(beTrue())
            }

            it("offers to enable tiling for a disabled current display and Space") {
                let presentation = CurrentSpaceTilingPresentation(isTilingEnabled: false)

                expect(presentation.title).to(equal("Enable Tiling for This Display & Space"))
                expect(presentation.isEnabled).to(beTrue())
                expect(presentation.isVisible).to(beTrue())
            }
        }

        describe("versioned state") {
            struct Fixture: Codable, Equatable {
                let value: String
            }

            var defaults: UserDefaults!
            let suiteName = "com.amethyst.tests.versioned-state"
            let persistence = VersionedStatePersistence(stateKey: "state", backupKey: "backup")

            beforeEach {
                defaults = UserDefaults(suiteName: suiteName)!
                defaults.removePersistentDomain(forName: suiteName)
            }

            afterEach {
                defaults.removePersistentDomain(forName: suiteName)
                defaults = nil
            }

            it("reads legacy unversioned state") {
                let legacyData = try JSONEncoder().encode(Fixture(value: "legacy"))

                expect { try VersionedStateCodec.decode(Fixture.self, from: legacyData) }
                    .to(equal(Fixture(value: "legacy")))
            }

            it("round trips the current envelope") {
                let fixture = Fixture(value: "current")
                let data = try VersionedStateCodec.encode(fixture)

                expect { try VersionedStateCodec.decode(Fixture.self, from: data) }.to(equal(fixture))
            }

            it("migrates a version 1 envelope") {
                let data = Data(#"{"version":1,"state":{"value":"legacy"}}"#.utf8)

                expect { try VersionedStateCodec.decode(Fixture.self, from: data) }
                    .to(equal(Fixture(value: "legacy")))
            }

            it("rejects a future envelope before decoding its state") {
                final class DecodeProbe {
                    static var count = 0
                }
                struct SideEffectState: Codable {
                    init(from decoder: Decoder) throws {
                        DecodeProbe.count += 1
                    }
                    func encode(to encoder: Encoder) throws {}
                }
                DecodeProbe.count = 0
                let data = Data(#"{"version":3,"state":{}}"#.utf8)

                expect { try VersionedStateCodec.decode(SideEffectState.self, from: data) }
                    .to(throwError(VersionedStateCodec.DecodeError.unsupportedVersion(3)))
                expect(DecodeProbe.count).to(equal(0))
            }

            it("rejects corrupt state") {
                let data = Data("not-json".utf8)

                expect { try VersionedStateCodec.decode(Fixture.self, from: data) }.to(throwError())
            }

            it("restores saved state through the persistence helper") {
                try persistence.save(Fixture(value: "saved"), to: defaults)

                expect { try persistence.restore(Fixture.self, from: defaults) }.to(equal(Fixture(value: "saved")))
            }

            it("backs up previous state before first versioned overwrite") {
                let legacyData = try JSONEncoder().encode(Fixture(value: "legacy"))
                defaults.set(legacyData, forKey: persistence.stateKey)

                try persistence.save(Fixture(value: "current"), to: defaults)

                expect(defaults.data(forKey: persistence.backupKey)).to(equal(legacyData))
                expect { try persistence.restore(Fixture.self, from: defaults) }.to(equal(Fixture(value: "current")))
            }

            it("does not overwrite an existing backup") {
                let originalBackup = try JSONEncoder().encode(Fixture(value: "backup"))
                let previousState = try JSONEncoder().encode(Fixture(value: "previous"))
                defaults.set(originalBackup, forKey: persistence.backupKey)
                defaults.set(previousState, forKey: persistence.stateKey)

                try persistence.save(Fixture(value: "current"), to: defaults)

                expect(defaults.data(forKey: persistence.backupKey)).to(equal(originalBackup))
                expect { try persistence.restore(Fixture.self, from: defaults) }.to(equal(Fixture(value: "current")))
            }

            it("resets saved and backup state") {
                try persistence.save(Fixture(value: "current"), to: defaults)
                defaults.set(Data("backup".utf8), forKey: persistence.backupKey)

                persistence.reset(in: defaults)

                expect(defaults.data(forKey: persistence.stateKey)).to(beNil())
                expect(defaults.data(forKey: persistence.backupKey)).to(beNil())
            }

            it("returns nil when no state was saved") {
                expect { try persistence.restore(Fixture.self, from: defaults) }.to(beNil())
            }

            it("surfaces corrupt persisted state instead of silently falling back") {
                defaults.set(Data("not-json".utf8), forKey: persistence.stateKey)

                expect { try persistence.restore(Fixture.self, from: defaults) }.to(throwError())
            }

            it("surfaces a future envelope version") {
                defaults.set(Data(#"{"version":3,"state":{"value":"future"}}"#.utf8), forKey: persistence.stateKey)

                expect { try persistence.restore(Fixture.self, from: defaults) }
                    .to(throwError(VersionedStateCodec.DecodeError.unsupportedVersion(3)))
            }
            it("preserves corrupt state and backup for explicit user recovery") {
                let corruptState = Data("not-json".utf8)
                let backup = try JSONEncoder().encode(Fixture(value: "last-known-good"))
                defaults.set(corruptState, forKey: persistence.stateKey)
                defaults.set(backup, forKey: persistence.backupKey)

                expect { try persistence.restore(Fixture.self, from: defaults) }.to(throwError())
                expect(defaults.data(forKey: persistence.stateKey)).to(equal(corruptState))
                expect(defaults.data(forKey: persistence.backupKey)).to(equal(backup))
            }
        }

        describe("AX observation retry policy") {
            it("retries transient AX observer errors before the cap") {
                let cannotComplete = ApplicationObservationError.observationFailed(error: AXError.cannotComplete.rawValue)
                let invalidElement = ApplicationObservationError.observationFailed(error: AXError.invalidUIElement.rawValue)

                expect(AXObservationRetryPolicy.shouldRetry(cannotComplete, attempt: 0)).to(beTrue())
                expect(AXObservationRetryPolicy.shouldRetry(invalidElement, attempt: 5)).to(beTrue())
            }

            it("stops retrying transient AX observer errors at the cap") {
                let cannotComplete = ApplicationObservationError.observationFailed(error: AXError.cannotComplete.rawValue)

                expect(AXObservationRetryPolicy.shouldRetry(cannotComplete, attempt: 6)).to(beFalse())
            }

            it("does not retry non-transient AX observer errors") {
                let unsupported = ApplicationObservationError.observationFailed(error: AXError.notificationUnsupported.rawValue)

                expect(AXObservationRetryPolicy.shouldRetry(unsupported, attempt: 0)).to(beFalse())
            }

            it("uses bounded quadratic backoff") {
                expect(AXObservationRetryPolicy.delayMilliseconds(forAttempt: 0)).to(equal(0))
                expect(AXObservationRetryPolicy.delayMilliseconds(forAttempt: 3)).to(equal(900))
            }
        }
    }
}
