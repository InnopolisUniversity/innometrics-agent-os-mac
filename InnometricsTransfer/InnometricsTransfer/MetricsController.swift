//
//  NewMetricsController.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 05/02/2017.
//  Modified by Dragos Strugar in 2020
//  Copyright © 2020 Innopolis University.
//

import Cocoa
import Foundation

class MetricsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    var appFocusMetrics: [Metric] = []
    var idleMetrics: [IdleMetric] = []
    var mergedMetrics: [MergedMetric] = []
    var appFocusMeasurements: [EnergyMeasurement] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        // TODO: update later
        // appDelegate.logOutMenuItem.isEnabled = true
        
        ferchNewMetrics()
    }
    
    public func ferchNewMetrics() {
        appFocusMetrics = []
        idleMetrics = []
        appFocusMeasurements = []
        
        do {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            let context = appDelegate.managedObjectContext

            // Fetch the metrics
            let metricsFetch: NSFetchRequest<Metric> = Metric.fetchRequest()
            metricsFetch.sortDescriptors = [NSSortDescriptor(key: "timestampStart", ascending: false)]
            
            let idleMetricsFetch: NSFetchRequest<IdleMetric> = IdleMetric.fetchRequest()
            idleMetricsFetch.sortDescriptors = [NSSortDescriptor(key: "timestampStart", ascending: false)]
            
            let measurementsFetch: NSFetchRequest<EnergyMeasurement> = EnergyMeasurement.fetchRequest()
            
            appFocusMetrics = try context.fetch(metricsFetch)
            idleMetrics = try context.fetch(idleMetricsFetch)
            appFocusMeasurements = try context.fetch(measurementsFetch)
        } catch {
            print(error)
        }
        
        updateMergedMetrics()
    }
    
    // Merge all the metrics into one array
    private func updateMergedMetrics() {
        func dateIsEarlier(first: NSDate, second: NSDate) -> Bool {
            return first.compare(second as Date) == ComparisonResult.orderedDescending
        }
        
        mergedMetrics = []
        let totalCount = appFocusMetrics.count + idleMetrics.count - 2
        var appFocusPos = 0, idlePos = 0
        var appFocusIsFilled = appFocusMetrics.isEmpty, idleIsFilled = idleMetrics.isEmpty
        while ((appFocusPos + idlePos) < totalCount) {
            if((idleIsFilled) || (!appFocusIsFilled && dateIsEarlier(first: appFocusMetrics[appFocusPos].timestampStart!, second: idleMetrics[idlePos].timestampStart!))) {
                let metric = appFocusMetrics[appFocusPos]
                mergedMetrics.append(MergedMetric(_type: MergedMetric.MetricType.appFocus, _appName: metric.appName!, _duration: metric.duration, _start: metric.timestampStart!, _end: metric.timestampEnd!, _bundleId: metric.bundleIdentifier, _bundleURL: metric.bundleURL, _tabName: metric.tabName, _tabURL: metric.tabUrl))
                if (appFocusPos != appFocusMetrics.count - 1) {
                    appFocusPos += 1
                }
                else {
                    appFocusIsFilled = true
                }
            }
            else {
                let metric = idleMetrics[idlePos]
                mergedMetrics.append(MergedMetric(_type: MergedMetric.MetricType.idle, _appName: metric.appName!, _duration: metric.duration, _start: metric.timestampStart!, _end: metric.timestampEnd!, _bundleId: metric.bundleIdentifier, _bundleURL: metric.bundleURL, _tabName: metric.tabName, _tabURL: metric.tabUrl))
                if (idlePos != idleMetrics.count - 1) {
                    idlePos += 1
                }
                else {
                    idleIsFilled = true
                }
            }
        }
    }
    
    public func sendMetrics (completion: @escaping (_ response: Int) -> Void) {
        MetricsTransfer.sendMetrics(token: AuthorizationUtils.getAuthorizationToken()!, username: AuthorizationUtils.getUsername()!, focusAppMetrics: appFocusMetrics, idleMetrics: idleMetrics, measurements: appFocusMeasurements) { (response) in
            completion(response)
        }
    }
    
    private func stringFromTimeInterval(interval: TimeInterval) -> NSString {
        
        let ti = NSInteger(interval)
        
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)
        
        return NSString(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier) -> String {
	return input.rawValue
}
