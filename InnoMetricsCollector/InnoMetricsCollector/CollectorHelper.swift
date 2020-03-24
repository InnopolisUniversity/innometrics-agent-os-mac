//
//  CollectorHelper.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 13.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import Cocoa
import ServiceManagement

class CollectorHelper {
    public static let browserIds: [String] = ["org.chromium.Chromium", "com.google.Chrome.canary", "com.google.Chrome", "com.apple.Safari", "com.operasoftware.Opera", "ru.yandex.desktop.yandex-browser", "org.mozilla.firefoxdeveloperedition"]
    
    public static let possibleUserMovements: NSEvent.EventTypeMask = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .smartMagnify, .swipe]
    
    public static func updateUIAuthorized(logInMenuItem: NSMenuItem,
                                          currentWorkingSessionMenuItem: NSMenuItem,
                                          metricsCollectorMenuItem: NSMenuItem,
                                          currentWorkingSessionView: NSView, collectorView: NSView) {
        
        logInMenuItem.isHidden = true
        logInMenuItem.isEnabled = false
        
        currentWorkingSessionMenuItem.isHidden = false
        currentWorkingSessionMenuItem.isEnabled = true
        
        metricsCollectorMenuItem.isHidden = false
        metricsCollectorMenuItem.isEnabled = true
        
        currentWorkingSessionMenuItem.view = currentWorkingSessionView
        metricsCollectorMenuItem.view = collectorView
    }
    
    public static func updateUIUnuthorized(logInMenuItem: NSMenuItem,
                                          currentWorkingSessionMenuItem: NSMenuItem,
                                          metricsCollectorMenuItem: NSMenuItem,
                                          currentWorkingSessionView: NSView, collectorView: NSView) {
        
        logInMenuItem.isHidden = false
        logInMenuItem.isEnabled = true
        
        currentWorkingSessionMenuItem.isHidden = true
        currentWorkingSessionMenuItem.isEnabled = false
        
        metricsCollectorMenuItem.isHidden = true
        metricsCollectorMenuItem.isEnabled = false
    }
    
    public static func setUpLaunchAtLogin() {
        let appBundleIdentifier = "ru.innometrics.InnoMetricsCollectorHelper"
        if SMLoginItemSetEnabled(appBundleIdentifier as CFString, true) {
            NSLog("Successfully add login item.")
        } else {
            NSLog("Failed to add login item.")
        }
    }
    
    public static func setImage(statusItem: NSStatusItem, named: String) {
        let icon = NSImage(named: named)
        icon?.isTemplate = true
        statusItem.image = icon
    }
    
    public static func getFrontmostApp() -> NSRunningApplication? {
        if let app = NSWorkspace.shared.frontmostApplication  {
            return app
        }
        return nil
    }
}
