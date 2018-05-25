//
//  NewMetricsController.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 05/02/2017.
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Cocoa

class MetricsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    var appFocusMetrics: [Metric] = []
    var idleMetrics: [IdleMetric] = []
    var mergedMetrics: [MergedMetric] = []
    @IBOutlet weak var newMetricsTableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = NSApplication.shared().delegate as! AppDelegate
        appDelegate.logOutMenuItem.isEnabled = true
        
        fetchNewMetricsAndRefreshTable()
    }
    
    public func fetchNewMetricsAndRefreshTable() {
        appFocusMetrics = []
        idleMetrics = []
        
        do {
            let appDelegate = NSApplication.shared().delegate as! AppDelegate
            let context = appDelegate.managedObjectContext
            
            // Create an appropriate request to data context using user's filters
            var appFocusDataPredicates: [NSPredicate] = []
            var idleDataPredicates: [NSPredicate] = []

            if (UserPrefs.isNeedFromDateFilter()) {
                let fromDate = UserPrefs.getExludedFromDate()
                appFocusDataPredicates.append(NSPredicate(format: "timestampStart < %@", fromDate))
                idleDataPredicates.append(NSPredicate(format: "timeStampStart < %@", fromDate))
            }
            
            if (UserPrefs.isNeedToDateFilter()) {
                let toDate = UserPrefs.getExludedToDate()
                appFocusDataPredicates.append(NSPredicate(format: "timestampStart > %@", toDate))
                idleDataPredicates.append(NSPredicate(format: "timeStampStart > %@", toDate))
            }
            let focusAppDatePredicateCompound = NSCompoundPredicate.init(type: .or, subpredicates: appFocusDataPredicates)
            let idleDatePredicateCompound = NSCompoundPredicate.init(type: .or, subpredicates: idleDataPredicates)
            
            let appNames = UserPrefs.getUserExludedApps()
            var appNamePredicates: [NSPredicate] = []
            
            for appName in appNames {
                appNamePredicates.append(NSPredicate(format: "NOT appName CONTAINS[c] %@", appName))
            }
            
            let focusAppKeywordsSearchableColumns: [String] = ["appName", "bundleIdentifier", "bundleURL", "tabName", "tabUrl"]
            let idleKeywordsSearchableColumns: [String] = ["appName"]
            
            let keywordsValues = UserPrefs.getUserExludedKeywords()
            var keywordsPredicatesFocusApp: [NSPredicate] = []
            var keywordsPredicatesIdle: [NSPredicate] = []
            
            for keyword in keywordsValues {
                for column in focusAppKeywordsSearchableColumns{
                    keywordsPredicatesFocusApp.append(NSPredicate(format: "NOT %K CONTAINS[c] %@", column, keyword))
                }
                for column in idleKeywordsSearchableColumns {
                    keywordsPredicatesIdle.append(NSPredicate(format: "NOT %K CONTAINS[c] %@", column, keyword))
                }
            }
            
            // Fetch the metrics and filter them
            let metricsFetch: NSFetchRequest<Metric> = Metric.fetchRequest()
            metricsFetch.sortDescriptors = [NSSortDescriptor(key: "timestampStart", ascending: false)]
            
            let idleMetricsFetch: NSFetchRequest<IdleMetric> = IdleMetric.fetchRequest()
            idleMetricsFetch.sortDescriptors = [NSSortDescriptor(key: "timeStampStart", ascending: false)]
            
            let isFinishedFocusApp = NSPredicate(format: "timestampEnd != nil")
            let isFinishedIdle = NSPredicate(format: "timeStampEnd != nil")
            
            var allFiltersFocusApp: [NSPredicate] = []
            var allFiltersIdle: [NSPredicate] = []
            
            if (appFocusDataPredicates.count > 0) {
                allFiltersFocusApp = appNamePredicates + keywordsPredicatesFocusApp + [focusAppDatePredicateCompound] + [isFinishedFocusApp]
            }
            else {
                allFiltersFocusApp = appNamePredicates + keywordsPredicatesFocusApp + [isFinishedFocusApp]
            }
            if (idleDataPredicates.count > 0) {
                allFiltersIdle = appNamePredicates + keywordsPredicatesIdle + [idleDatePredicateCompound] + [isFinishedIdle]
            }
            else {
                allFiltersIdle = appNamePredicates + keywordsPredicatesIdle + [isFinishedIdle]
            }
            
            let focusAppPredicateCompound = NSCompoundPredicate.init(type: .and, subpredicates: allFiltersFocusApp)
            let idlePredicateCompound = NSCompoundPredicate.init(type: .and, subpredicates: allFiltersIdle)
            
            metricsFetch.predicate = focusAppPredicateCompound
            idleMetricsFetch.predicate = idlePredicateCompound
            
            appFocusMetrics = try context.fetch(metricsFetch)
            idleMetrics = try context.fetch(idleMetricsFetch)
        } catch {
            print(error)
        }
        updateMergedMetrics()
        newMetricsTableView.reloadData()
    }
    
    // Merge all the metrics into one array
    private func updateMergedMetrics() {
        func dateIsEarlier(first: NSDate, second: NSDate) -> Bool {
            return first.compare(second as Date) == ComparisonResult.orderedDescending
        }
        
        mergedMetrics = []
        let totalCount = appFocusMetrics.count + idleMetrics.count - 2
        var appFocusPos = 0, idlePos = 0
        var appFocusIsFilled = false, idleIsFilled = false
        while ((appFocusPos + idlePos) < totalCount) {
            if((idleIsFilled) || (!appFocusIsFilled && dateIsEarlier(first: appFocusMetrics[appFocusPos].timestampStart!, second: idleMetrics[idlePos].timeStampStart!))) {
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
                mergedMetrics.append(MergedMetric(_type: MergedMetric.MetricType.idle, _appName: metric.appName!, _duration: metric.duration, _start: metric.timeStampStart!, _end: metric.timeStampEnd!, _bundleId: nil, _bundleURL: nil, _tabName: nil, _tabURL: nil))
                if (idlePos != idleMetrics.count - 1) {
                    idlePos += 1
                }
                else {
                    idleIsFilled = true
                }
            }
        }
    }
    
    // TODO: extend this to idle metrics
    public func sendMetrics (completion: @escaping (_ response: Int) -> Void) {
        MetricsTransfer.sendMetrics(token: AuthorizationUtils.getAuthorizationToken()!, focusAppMetrics: appFocusMetrics, idleMetrics: idleMetrics) { (response) in
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
                        switch mergedMetrics[i].type {
                        case .idle:
                            let metric = self.idleMetrics.first(where: { $0.timeStampStart == self.mergedMetrics[i].timeStampStart })
                            context.delete(metric!)
                            self.idleMetrics.remove(at: i)
                        case .appFocus:
                            let metric = self.appFocusMetrics.first(where: { $0.timestampStart == self.mergedMetrics[i].timeStampStart })
                            context.delete(metric!)
                            self.appFocusMetrics.remove(at: i)
                        }
                        mergedMetrics.remove(at: i)
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
        return mergedMetrics.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let columnId = tableColumn?.identifier
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        if (columnId == "metricType") {
            return mergedMetrics[row].type.stringValue
        } else if (columnId == "timestampStart") {
            return dateFormatter.string(from: mergedMetrics[row].timeStampStart as Date)
        } else if (columnId == "timestampEnd") {
            return dateFormatter.string(from: mergedMetrics[row].timeStampEnd as Date)
        } else if (columnId == "bundleIdentifier") {
            return mergedMetrics[row].bundleIdentifier
        } else if (columnId == "name") {
            return mergedMetrics[row].appName
        } else if (columnId == "bundleURL") {
            return mergedMetrics[row].bundleURL
        } else if (columnId == "tabUrl") {
            return mergedMetrics[row].tabURL
        } else if (columnId == "tabName") {
            return mergedMetrics[row].tabName
        } else if (columnId == "duration"){
            return stringFromTimeInterval(interval: mergedMetrics[row].duration)
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
