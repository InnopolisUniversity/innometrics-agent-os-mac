//
//  NewMetricsController.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 05/02/2017.
//  Copyright © 2017 Denis Zaplatnikov. All rights reserved.
//

import Cocoa

class MetricsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    var metrics: [Metric] = []
    @IBOutlet weak var newMetricsTableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        appDelegate.logOutMenuItem.isEnabled = true
        
        fetchNewMetricsAndRefreshTable()
    }
    
    public func fetchNewMetricsAndRefreshTable() {
        metrics = []
        
        do {
            let appDelegate = NSApplication.shared().delegate as! AppDelegate
            let context = appDelegate.managedObjectContext
            
            var datePredicates: [NSPredicate] = []

            if (UserPrefs.isNeedFromDateFilter()) {
                let fromDate = UserPrefs.getExludedFromDate()
                datePredicates.append(NSPredicate(format: "timestampStart < %@", fromDate))
            }
            
            if (UserPrefs.isNeedToDateFilter()) {
                let toDate = UserPrefs.getExludedToDate()
                datePredicates.append(NSPredicate(format: "timestampStart > %@", toDate))
            }
            let datePredicateCompound = NSCompoundPredicate.init(type: .or, subpredicates: datePredicates)
            
            let appNames = UserPrefs.getUserExludedApps()
            var appNamePredicates: [NSPredicate] = []
            
            for appName in appNames {
                appNamePredicates.append(NSPredicate(format: "NOT appName CONTAINS[c] %@", appName))
            }
            
            let keywordsSearchableColumns: [String] = ["appName", "bundleIdentifier", "bundleURL", "tabName", "tabUrl"]
            let keywordsValues = UserPrefs.getUserExludedKeywords()
            var keywordsPredicates: [NSPredicate] = []
            for keyword in keywordsValues {
                for column in keywordsSearchableColumns{
                    keywordsPredicates.append(NSPredicate(format: "NOT %K CONTAINS[c] %@", column, keyword))
                }
            }
            
            let metricsFetch: NSFetchRequest<Metric> = Metric.fetchRequest()
            metricsFetch.sortDescriptors = [NSSortDescriptor(key: "timestampStart", ascending: false)]
            
            let isFinished = NSPredicate(format: "timestampEnd != nil")
            var allFilters: [NSPredicate] = []
            if (datePredicates.count > 0) {
                allFilters = appNamePredicates + keywordsPredicates + [datePredicateCompound] + [isFinished]
            } else {
                allFilters = appNamePredicates + keywordsPredicates + [isFinished]
            }
            
            let predicateCompound = NSCompoundPredicate.init(type: .and, subpredicates: allFilters)
            metricsFetch.predicate = predicateCompound
            
            metrics = try context.fetch(metricsFetch)
        } catch {
            print(error)
        }
        newMetricsTableView.reloadData()
    }
    
    public func sendMetrics (completion: @escaping (_ response: Int) -> Void) {
        MetricsTransfer.sendMetrics(token: AuthorizationUtils.getAuthorizationToken()!, metrics: metrics) { (response) in
            completion(response)
        }
    }
    
    @IBAction func deleteMetricsBtn_Clicked(_ sender: AnyObject) {
        if (newMetricsTableView != nil) {
            let indexes = newMetricsTableView.selectedRowIndexes.map { Int($0) }
            
            if (indexes.count > 0) {
                let alert: NSAlert = NSAlert()
                alert.messageText = "Would you like to delete selected metrics?"
                alert.informativeText = "This action cannot be undone."
                alert.alertStyle = NSAlertStyle.critical
                alert.addButton(withTitle: "Delete")
                alert.addButton(withTitle: "Cancel")
                
                let answer = alert.runModal()
                if answer == NSAlertFirstButtonReturn {
                    
                    let startChangingDbNotificationName = Notification.Name("db_start_changing")
                    let endChangingDbNotificationName = Notification.Name("db_end_changing")
                    DistributedNotificationCenter.default().postNotificationName(startChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
                
                    newMetricsTableView.beginUpdates()
                    let indexPaths = newMetricsTableView.selectedRowIndexes
                    let appDelegate = NSApplication.shared().delegate as! AppDelegate
                    let context = appDelegate.managedObjectContext
                    for i in indexes.reversed() {
                        context.delete(metrics[i])
                        metrics.remove(at: i)
                    }
                
                    do {
                        // Save Changes
                        try context.save()
                    } catch {
                        print (error)
                    }

                    newMetricsTableView.endUpdates()
                    newMetricsTableView.removeRows (at: indexPaths, withAnimation: .effectFade)
                    DistributedNotificationCenter.default().postNotificationName(endChangingDbNotificationName, object: Bundle.main.bundleIdentifier, deliverImmediately: true)
                }
            }
        }
    }
    
    // Table view utilities
    func numberOfRows(in tableView: NSTableView) -> Int {
        return metrics.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let columnId = tableColumn?.identifier
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        if (columnId == "timestampStart") {
            return dateFormatter.string(from: metrics[row].timestampStart as! Date)
        } else if (columnId == "timestampEnd") {
            if (metrics[row].timestampEnd != nil) {
                return dateFormatter.string(from: metrics[row].timestampEnd as! Date)
            } else {
                return ""
            }
        } else if (columnId == "bundleIdentifier") {
            return metrics[row].bundleIdentifier
        } else if (columnId == "name") {
            return metrics[row].appName
        } else if (columnId == "bundleURL") {
            return metrics[row].bundleURL
        } else if (columnId == "tabUrl") {
            return metrics[row].tabUrl
        } else if (columnId == "tabName") {
            return metrics[row].tabName
        } else if (columnId == "duration"){
            return stringFromTimeInterval(interval: metrics[row].duration)
        } else {
            return ""
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
