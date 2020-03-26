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
    
    var metrics: [Metric] = []
    var context: NSManagedObjectContext? = nil
    
    public func fetchNewMetrics(context: NSManagedObjectContext, callback: @escaping () -> Void) {
        
        self.context = context
        
        let group = DispatchGroup()
        group.enter()
        
        let dispatchQueue = DispatchQueue(label: "fetchMetrics", qos: .background)
        
        dispatchQueue.async(group: group, execute: {
            self.metrics = []
            
            self.context?.perform {
                do {
                    let metricsFetch: NSFetchRequest<Metric> = Metric.fetchRequest()
                    metricsFetch.sortDescriptors = [NSSortDescriptor(key: "timestampStart", ascending: false)]
                    
                    self.metrics = try self.context!.fetch(metricsFetch)
                } catch {
                    print("in fetchNewMetrics: can't fetch\nerror: \(error)")
                }
                
                group.leave()
                group.notify(queue: DispatchQueue.main, execute: {
                    callback()
                })
            }
        })
    }
    
    public func sendMetrics (completion: @escaping (_ response: Int) -> Void) {
        if (AuthorizationUtils.isAuthorized()) {
            MetricsTransfer.sendMetrics(token: AuthorizationUtils.getAuthorizationToken()!, username: AuthorizationUtils.getUsername()!, metrics: metrics) { (response) in
                completion(response)
            }
        } else {
            DispatchQueue.main.async {
                Helpers.dialogOK(question: "Error", text: "You need to relogin to the system.")
                AuthorizationUtils.saveIsAuthorized(isAuthorized: false)
            }
        }
    }
    
    public func clearDB() {
        self.context?.perform {
            do {
                let metricsFetch: NSFetchRequest<Metric> = Metric.fetchRequest()
                metricsFetch.includesPropertyValues = true
                let metricsToDelete = try self.context!.fetch(metricsFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
                
                for metric in metricsToDelete {
                    if metric.value(forKey: "timestampEnd") == nil {
                        // do not delete unfinished metrics
                    } else {
                        // delete metrics that are finished
                        self.context!.delete(metric)
                    }
                }
                
                // Save Changes
                try self.context!.save()
                
                print("deleted metrics...")
            } catch {
                print("clearDB: errros :( \n\(error)")
            }
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
