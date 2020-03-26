//
//  ProcessController.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 13.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa
import Foundation

class ProcessController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    var processes: [ActiveProcess] = []
    var measurements: [EnergyMeasurement] = []
    var context: NSManagedObjectContext? = nil
    
    public func fetchNewProcesses(context: NSManagedObjectContext, callback: @escaping () -> Void) {
        
        self.context = context
        
        self.processes = []
        self.measurements = []
        
        self.context?.perform {
            do {
                // Fetch the processes
                let processesFetch: NSFetchRequest<ActiveProcess> = ActiveProcess.fetchRequest()
                let measurementsFetch: NSFetchRequest<EnergyMeasurement> = EnergyMeasurement.fetchRequest()
                
                self.processes = try context.fetch(processesFetch)
                self.measurements = try context.fetch(measurementsFetch)
            } catch {
                print("in fetchNewProcesses: can't fetch\nerror: \(error)")
            }
            
            callback()
        }
    }
    
    public func sendProcesses (completion: @escaping (_ response: Int) -> Void) {
        ProcessesTransfer.sendProcesses(token: AuthorizationUtils.getAuthorizationToken()!, username: AuthorizationUtils.getUsername()!, processes: processes, measurements: measurements) { (response) in
            completion(response)
        }
    }
    
    public func clearDB() {
        self.context?.perform {
            do {
                let processesFetch: NSFetchRequest<ActiveProcess> = ActiveProcess.fetchRequest()
                processesFetch.includesPropertyValues = false
                let processesToDelete = try self.context!.fetch(processesFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
                
                for p in processesToDelete {
                    self.context?.delete(p)
                }
                
                let measurementFetch: NSFetchRequest<EnergyMeasurement> = EnergyMeasurement.fetchRequest()
                measurementFetch.includesPropertyValues = false
                let measurementsToDelete = try self.context!.fetch(measurementFetch as! NSFetchRequest<NSFetchRequestResult>) as! [NSManagedObject]
                
                for m in measurementsToDelete {
                    self.context?.delete(m)
                }
                
                try self.context?.save()
            } catch {
                print("in clearDB of processes: can't clear\nerror: \(error)")
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier) -> String {
    return input.rawValue
}
