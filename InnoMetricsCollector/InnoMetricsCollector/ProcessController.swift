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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _ = NSApplication.shared.delegate as! AppDelegate
        fetchNewProcesses()
    }
    
    public func fetchNewProcesses() {
        processes = []
        measurements = []
        
        do {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            let context = appDelegate.managedObjectContext

            // Fetch the processes
            let processesFetch: NSFetchRequest<ActiveProcess> = ActiveProcess.fetchRequest()
            let measurementsFetch: NSFetchRequest<EnergyMeasurement> = EnergyMeasurement.fetchRequest()
            
            processes = try context.fetch(processesFetch)
            measurements = try context.fetch(measurementsFetch)
        } catch {
            print(error)
        }
    }
    
    public func sendProcesses (completion: @escaping (_ response: Int) -> Void) {
        ProcessesTransfer.sendProcesses(token: AuthorizationUtils.getAuthorizationToken()!, username: AuthorizationUtils.getUsername()!, processes: processes, measurements: measurements) { (response) in
            completion(response)
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier) -> String {
    return input.rawValue
}
