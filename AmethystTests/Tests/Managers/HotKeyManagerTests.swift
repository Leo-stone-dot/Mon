//
//  HotKeyManagerTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/18/17.
//  Copyright © 2017 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class HotKeyManagerTests: QuickSpec {
    override func spec() {
        describe("hotKeyNameToDefaultsKey") {
            it("has the right number of screens") {
                let keyMapping = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey()
                let screenCommands = keyMapping.filter { $0[1].hasPrefix(CommandKey.focusScreenPrefix.rawValue) }
                expect(screenCommands.count).to(equal(7))
            }
        }

        describe("HotKeyMigrationPolicy") {
            it("applies the default shortcut on first migration") {
                expect(HotKeyMigrationPolicy.shouldApplyDefaultShortcut(
                    isMigrated: false,
                    hasExistingShortcut: false,
                    override: false
                )).to(beTrue())
            }

            it("does not reapply a migrated shortcut") {
                expect(HotKeyMigrationPolicy.shouldApplyDefaultShortcut(
                    isMigrated: true,
                    hasExistingShortcut: false,
                    override: false
                )).to(beFalse())
            }

            it("reapplies a migrated shortcut when overridden") {
                expect(HotKeyMigrationPolicy.shouldApplyDefaultShortcut(
                    isMigrated: true,
                    hasExistingShortcut: false,
                    override: true
                )).to(beTrue())
            }

            it("never overwrites an existing shortcut") {
                expect(HotKeyMigrationPolicy.shouldApplyDefaultShortcut(
                    isMigrated: false,
                    hasExistingShortcut: true,
                    override: false
                )).to(beFalse())
                expect(HotKeyMigrationPolicy.shouldApplyDefaultShortcut(
                    isMigrated: false,
                    hasExistingShortcut: true,
                    override: true
                )).to(beFalse())
            }
        }
    }
}
