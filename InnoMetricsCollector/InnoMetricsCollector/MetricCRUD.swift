//
//  MetricCRUD.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 24.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import Cocoa

class MetricCRUD {
    public static func createMetric(app: NSRunningApplication, pid: pid_t, context: NSManagedObjectContext, session: Session, isIdle: Int16 = 0, callback: @escaping (Metric?) -> Void) {
        
        if app.bundleIdentifier == nil && app.localizedName == nil && app.executableURL?.absoluteURL != nil { return }
        if app.bundleIdentifier == "ru.innometrics.InnoMetricsCollector" { return }
        
        var returnVal: Metric?
        
        let foregroundWindowBundleId = app.bundleIdentifier
        let foregroundWindowLaunchDate = NSDate()
        
        let metric = NSEntityDescription.insertNewObject(forEntityName: "Metric", into: context) as! Metric
        metric.bundleIdentifier = foregroundWindowBundleId
        metric.appName = app.localizedName
        metric.bundleURL = app.executableURL?.absoluteString
        metric.timestampStart = foregroundWindowLaunchDate
        metric.session = session
        metric.isIdle = isIdle
        metric.pid = String(app.processIdentifier)
        
        if (foregroundWindowBundleId != nil && CollectorHelper.browserIds.contains(foregroundWindowBundleId!)) {
            let foregroundWindowTabUrl = BrowserInfoUtils.activeTabURL(bundleIdentifier: foregroundWindowBundleId!)
            
            if (foregroundWindowTabUrl != nil) {
                metric.tabUrl = foregroundWindowTabUrl!
            }
            
            let foregroundWindowTabTitle = BrowserInfoUtils.activeTabTitle(bundleIdentifier: foregroundWindowBundleId!)
            
            if (foregroundWindowTabTitle != nil) {
                metric.tabName = foregroundWindowTabTitle!
            }
        }
        
        context.perform {
            do {
                try context.save()
                returnVal = metric
            } catch {
                print("in createMetric: can't save context\nerror: \(error)")
            }
            
            callback(returnVal)
        }
    }
    
    public static func setEndTimeOfPrevMetric(m: Metric, context: NSManagedObjectContext, callback: @escaping (Metric?) -> Void) {
        
        if (m.bundleIdentifier == nil) { return }
        
        if (m.timestampEnd == nil) {
            let metric = m
            let endTime = NSDate()
            metric.timestampEnd = endTime
            metric.duration = (metric.timestampEnd?.timeIntervalSinceReferenceDate)! - (metric.timestampStart?.timeIntervalSinceReferenceDate)!
            
            context.perform {
                do {
                    try context.save()
                    // print("end of", metric.appName!)
                } catch {
                    print("in setEndOfPrevMetric: can't set time")
                }
                
                callback(metric)
            }
        }
    }
    
    public static func markAsIdle(app: Metric, context: NSManagedObjectContext, callback: @escaping (Metric?) -> Void) {
        var returnVal: Metric?
        
        if app.bundleIdentifier == nil { return }
        
        let foregroundWindowLaunchDate = NSDate()
        
        let metric = NSEntityDescription.insertNewObject(forEntityName: "Metric", into: context) as! Metric
        metric.bundleIdentifier = app.bundleIdentifier
        metric.appName = app.appName
        metric.bundleURL = app.bundleURL
        metric.timestampStart = foregroundWindowLaunchDate
        metric.session = app.session
        metric.isIdle = 1
        
        if (app.bundleIdentifier != nil && CollectorHelper.browserIds.contains(app.bundleIdentifier!)) {
            if (app.tabUrl != nil) {
                metric.tabUrl = app.tabUrl!
            }
            
            if (app.tabName != nil) {
                metric.tabName = app.tabName!
            }
        }
        
        context.perform {
            do {
                try context.save()
                returnVal = metric
            } catch {
                print("in markAsIdle: can't save context\nerror: \(error)")
            }
            
            callback(returnVal)
        }
    }
}
