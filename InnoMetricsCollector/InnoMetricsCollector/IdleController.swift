//
//  IdleController.swift
//  InnoMetricsCollector
//
//  Created by Pavel Kotov on 09/03/2018.
//  Copyright © 2018 Pavel Kotov. All rights reserved.
//

import Cocoa

class IdleController: NSView {
    @IBOutlet weak var totalIdleTime: NSTextField!
    @IBOutlet weak var topOneIdleApp: NSTextField!
    @IBOutlet weak var topTwoIdleApp: NSTextField!
    @IBOutlet weak var topThreeIdleApp: NSTextField!
    
    private var totalIdleTimeValue: Int!
    private var topApps: [Int: (String, Int)]?
    
    private var usersLastActionTime: Date!
    private let idleTimeout: Int = 15
    
    // Return, if user exceeded idle timeout and for how long
    func userMadeAction() -> (Bool, Int) {
        let currentTime = NSDate()
        let timeSinceLastAction = (Int) (currentTime.timeIntervalSinceReferenceDate - (usersLastActionTime?.timeIntervalSinceReferenceDate)!)
        let timeoutExceeded = timeSinceLastAction > idleTimeout
        usersLastActionTime = currentTime as Date!
        
        if (timeoutExceeded) {
            updateIdleView(newIdleTime: timeSinceLastAction)
        }
        return (timeoutExceeded, timeSinceLastAction)
    }
    
    func updateIdleView(newIdleTime: Int) {
        var currentAppName = ""
        let currentApp = NSWorkspace.shared().frontmostApplication
        if (currentApp != nil && currentApp?.localizedName != nil) {
            currentAppName = (currentApp?.localizedName!)!
        }
        
        // Add current idle time to total and update list of top-3
        if (topApps == nil) {
            topApps = [1: (currentAppName, newIdleTime)]
            totalIdleTimeValue = newIdleTime
        }
        else {
            // Renew list of apps: find the one with such name, update its
            // idle time and then resort it according to place
            totalIdleTimeValue! += newIdleTime
        }
        
        totalIdleTime.stringValue = String(totalIdleTimeValue)
    }
}
