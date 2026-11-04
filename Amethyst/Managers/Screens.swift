//
//  Screens.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

extension WindowManager {
    class Screens: Codable {
        enum CodingKeys: String, CodingKey {
            case screenManagersCache
        }

        private(set) var screenManagers: [ScreenManager<WindowManager<Application>>] = []
        private var screenManagersCache: [String: ScreenManager<WindowManager<Application>>] = [:]

        init() {}

        func updateSpaces(screenTopologyClient: ScreenTopologyClient<Application.Window.Screen>) {
            guard let screenDescriptions = screenTopologyClient.screenDescriptions() else {
                return
            }

            if screenTopologyClient.screensHaveSeparateSpaces() {
                for screenDictionary in screenDescriptions {
                    guard let screenID = screenDictionary["Display Identifier"].string else {
                        log.error("Could not identify screen with info: \(screenDictionary)")
                        continue
                    }

                    guard let screenManager = screenManagersCache[screenID] else {
                        log.error("Screen with identifier not managed: \(screenID)")
                        continue
                    }

                    guard let space = CGSpacesInfo<Window>.space(fromScreenDescription: screenDictionary) else {
                        log.warning("Could not decode current Space for screen: \(screenID)")
                        continue
                    }

                    guard screenManager.space != space else {
                        continue
                    }

                    screenManager.updateSpace(to: space)
                }
            } else {
                guard let firstDescription = screenDescriptions.first else {
                    log.warning("No screen descriptions available during space update")
                    return
                }
                for screenManager in screenManagers {
                    guard let space = CGSpacesInfo<Window>.space(fromScreenDescription: firstDescription) else {
                        log.warning("Could not decode current shared Space")
                        continue
                    }

                    guard screenManager.space != space else {
                        continue
                    }

                    screenManager.updateSpace(to: space)
                }
            }
        }

        func focusedScreenManager() -> ScreenManager<WindowManager<Application>>? {
            guard let focusedWindow = Window.currentlyFocused() else {
                return nil
            }
            return screenManagers.first { $0.screen?.screenID() == focusedWindow.screen()?.screenID() }
        }

        func updateScreens(
            windowManager: WindowManager,
            screenTopologyClient: ScreenTopologyClient<Application.Window.Screen>
        ) {
            var screenManagers: [ScreenManager<WindowManager<Application>>] = []

            for screen in screenTopologyClient.availableScreens() {
                guard let screenID = screen.screenID() else {
                    continue
                }

                let screenManager = screenManagersCache[screenID] ?? ScreenManager<WindowManager<Application>>(
                    screen: screen,
                    delegate: windowManager,
                    userConfiguration: UserConfiguration.shared,
                    spaceClient: windowManager.spaceClient
                )
                screenManager.delegate = windowManager
                screenManager.updateScreen(to: screen)

                screenManagersCache[screenID] = screenManager

                screenManagers.append(screenManager)
            }

            // Window managers are sorted by screen position along the x-axis.
            // See `ScreenManager`'s `Comparable` conformance
            self.screenManagers = screenManagers.sorted()

            updateSpaces(screenTopologyClient: screenTopologyClient)
            markAllScreensForReflow()
        }

        func distributeEventToScreen(_ screen: Screen, change: Change<Window>) {
            screenManagers
                .filter { $0.screen?.screenID() == screen.screenID() }
                .forEach { screenManager in
                    screenManager.distributeEvent(change)
                }
        }

        func distributeEventToAllScreens(change: Change<Window>) {
            for screenManager in screenManagers {
                screenManager.distributeEvent(change)
            }
        }

        func markScreenForReflow(_ screen: Screen) {
            screenManagers
                .filter { $0.screen?.screenID() == screen.screenID() }
                .forEach { screenManager in
                    screenManager.setNeedsReflow()
                }
        }

        func markAllScreensForReflow() {
            for screenManager in screenManagers {
                screenManager.setNeedsReflow()
            }
        }
    }
}
