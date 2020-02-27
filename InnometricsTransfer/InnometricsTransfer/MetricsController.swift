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
    var appFocusMeasurements: [EnergyMeasurement] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        // TODO: update later
        // appDelegate.logOutMenuItem.isEnabled = true
        
        fetchNewMetrics()
    }
    
    public func fetchNewMetrics() {
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
