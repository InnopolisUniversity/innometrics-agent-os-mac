//
//  CollectorHelper.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 13.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import Cocoa

class CollectorHelper {
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
}
