//
//  ScreensInfo.swift
//  Mon
//
//  Created by Ian Ynda-Hummel on 3/9/23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser
import Cocoa
import Silica

extension AMScreen {
    func debugDescription() -> String {
        return """
        \tScreenID: \(screenID() ?? "<unknown>")
        \tScreen Frame: \(frame())
        \tFrame Including Dock and Menu: \(frameIncludingDockAndMenu())
        \tFrame Without Dock or Menu: \(frameWithoutDockOrMenu())
        """
    }
}

struct Screens: ParsableCommand {
    mutating func run() throws {
        let screens = AMScreen.availableScreens
        print("Screens: \(screens.count)")
        for screen in screens {
            print(screen.debugDescription())
            print("")
        }
    }
}
