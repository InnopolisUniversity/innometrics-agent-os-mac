//
//  ProcessCRUD.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 24.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import Cocoa

class ProcessCRUD {
    public static func getAllProcesses(context: NSManagedObjectContext, session: Session, callback: @escaping (Set<ActiveProcess>?) -> Void) {
        
        let group = DispatchGroup()
        
        group.enter()
        
        var processes = Set<ActiveProcess>()
        
        let apps = NSWorkspace.shared.runningApplications
        let dispatchQueue = DispatchQueue(label: "processes", qos: .background)
        
        dispatchQueue.async(group: group, execute: {
            for p in apps {
                if p.bundleIdentifier == nil {
                    continue
                }
                
                let pid = String(p.processIdentifier)
                let comm = String((p.bundleIdentifier?.split(separator: ".").last)!)

                let newProcess = NSEntityDescription.insertNewObject(forEntityName: "ActiveProcess", into: context) as! ActiveProcess
  
                newProcess.pid = pid
                newProcess.process_name = comm
                newProcess.session = session
                
                processes.insert(newProcess)
                
                // 3: get energy metrics per process
                let _ = ProcessCRUD.measureEnergyMetrics(process: newProcess, processID: pid, context: context)
            }
            
            context.perform {
                do {
                    try context.save()
                } catch {
                    print("error in getAllProcesses: can't save\n\(error)")
                }
                
                group.leave()
                group.notify(queue: DispatchQueue.main, execute: {
                    callback(processes)
                })
            }
        })
    }
    
    public static func measureEnergyMetrics(process: ActiveProcess, processID: String, context: NSManagedObjectContext) -> Set<EnergyMeasurement> {
        
        var measurements = Set<EnergyMeasurement>()
        
        let usesAcPower = Helpers.shell("pmset -g ps").contains("AC Power") ? true : false
        
        let batteryPercentageMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let batteryStatusMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let ramMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let vRamMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        let cpuMeasurement = NSEntityDescription.insertNewObject(forEntityName: "EnergyMeasurement", into: context) as! EnergyMeasurement
        
        let d = NSDate()
        // 1. battery percentage
        let estimatedChargeRemaining = usesAcPower ? "-1" : Helpers.shell("pmset -g batt | grep -Eo \"\\d+%\" | cut -d% -f1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        batteryPercentageMeasurement.alternativeLabel = "EstimatedChargeRemaining"
        batteryPercentageMeasurement.measurementTypeId = "1"
        batteryPercentageMeasurement.value = estimatedChargeRemaining
        batteryPercentageMeasurement.process = process
        batteryPercentageMeasurement.capturedDate = NSDate()
        
        // 2. battery status (charging or not)
        batteryStatusMeasurement.alternativeLabel = "BatteryStatus"
        batteryStatusMeasurement.measurementTypeId = "2"
        batteryStatusMeasurement.value = usesAcPower ? "2" : "1"
        batteryStatusMeasurement.process = process
        batteryStatusMeasurement.capturedDate = d
        
        // 3. ram usage
        let ramUsage = Helpers.shell("ps -p \(processID) -o rss")
            .split{ $0.isNewline }[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        ramMeasurement.alternativeLabel = "RAM"
        ramMeasurement.measurementTypeId = "3"
        ramMeasurement.value = Int(ramUsage) != nil ? String(Int(ramUsage)! / 1024) : "0"
        ramMeasurement.process = process
        ramMeasurement.capturedDate = d
        
        // 4. vRAM usage
        let vRamUsage = Helpers.shell("ps -p \(processID) -xm -o vsz")
            .split{ $0.isNewline }[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        vRamMeasurement.alternativeLabel = "vRAM"
        vRamMeasurement.measurementTypeId = "4"
        vRamMeasurement.value = Int(vRamUsage) != nil ? String(Int(vRamUsage)! / 1024) : "0"
        vRamMeasurement.process = process
        vRamMeasurement.capturedDate = d
        
        // 5. CPU usage
        let cpuUsage = Helpers.shell("ps -p \(processID) -xm -o %cpu")
            .split{ $0.isNewline }[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cpuMeasurement.alternativeLabel = "CPU"
        cpuMeasurement.measurementTypeId = "5"
        cpuMeasurement.value = String(cpuUsage)
        cpuMeasurement.process = process
        cpuMeasurement.capturedDate = d
        
        measurements.insert(batteryPercentageMeasurement)
        measurements.insert(batteryStatusMeasurement)
        measurements.insert(ramMeasurement)
        measurements.insert(vRamMeasurement)
        measurements.insert(cpuMeasurement)
        
        return measurements
    }
}
