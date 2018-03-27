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
    
    private var totalIdleTimeValue: Int = 0
    private var topApps = [(String, Int)]()
    
    private var usersLastActionTime: Date = NSDate() as Date!
    private let idleTimeout: Int = 5
    
    // Return, if user exceeded idle timeout and for how long and in which app
    func userMadeAction() -> (Bool, Double, String?) {
        let currentTime = NSDate()
        let timeSinceLastAction = (Int) (currentTime.timeIntervalSinceReferenceDate - usersLastActionTime.timeIntervalSinceReferenceDate)
        let timeoutExceeded = timeSinceLastAction > idleTimeout
        usersLastActionTime = currentTime as Date!
        
        var currentAppName: String? = nil
        if (timeoutExceeded) {
            currentAppName = updateIdleView(newIdleTime: timeSinceLastAction)
        }
        return (timeoutExceeded, Double(timeSinceLastAction), currentAppName)
    }
    
    func updateIdleView(newIdleTime: Int) -> String {
        var currentAppName = ""
        let currentApp = NSWorkspace.shared().frontmostApplication
        if (currentApp != nil && currentApp?.localizedName != nil) {
            currentAppName = (currentApp?.localizedName!)!
        }
        
        // Add current idle time to total and update list of top-3
        totalIdleTimeValue += newIdleTime
        insertToTopApps(appName: currentAppName, idleTime: newIdleTime)
        
        // Update UI
        DispatchQueue.main.async {
            self.totalIdleTime.stringValue = self.stringFromSeconds(time: self.totalIdleTimeValue)
            self.topOneIdleApp.stringValue = self.topApps[0].0 + " with " +
                self.stringFromSeconds(time: self.topApps[0].1)
            if (self.topApps.indices.contains(1)) {
                self.topTwoIdleApp.stringValue = self.topApps[1].0 + " with " +
                    self.stringFromSeconds(time: self.topApps[1].1)
            }
            if (self.topApps.indices.contains(2)) {
                self.topThreeIdleApp.stringValue = self.topApps[2].0 + " with " +
                    self.stringFromSeconds(time: self.topApps[2].1)
            }
        }
        
        return currentAppName
    }
    
    // Insert a new app-time pair to a top apps map and sort it
    private func insertToTopApps(appName: String, idleTime: Int) {
        if let entry = topApps.first(where: { $0.0 == appName }) {
            // If there is already such app, take it out and insert again with changed
            // idle time value (immutability, yeah!)
            topApps = topApps.filter({ $0.0 != appName }) + [(appName, entry.1 + idleTime)]
        }
        else {
            // If no such app found, just insert it
            topApps.append((appName, idleTime))
        }
        // Resort the list of apps
        topApps = topApps.sorted(by: { $0.1 > $1.1 } )
    }
    
    // Convert seconds into pretty 00:00:00 time string
    private func stringFromSeconds(time: Int) -> String {
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        
        return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
    }
}
