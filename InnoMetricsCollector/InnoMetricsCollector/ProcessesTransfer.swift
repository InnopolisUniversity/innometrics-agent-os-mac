//
//  ProcessesTransfer.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 13.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import Cocoa

public class ProcessesTransfer {
    
    public static func extractDataFromProcess(process: ActiveProcess, username: String, idle: Bool = false) -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        var measurementReportList: [[String: String]] = []
        if (process.measurementReportList != nil) {
            for m in process.measurementReportList ?? Set<EnergyMeasurement>() {
                let mJson: [String: String] = [
                    "alternativeLabel": m.alternativeLabel ?? "CPU",
                    "measurementTypeId": m.measurementTypeId ?? "0",
                    "value": m.value ?? "0",
                    "capturedDate": dateFormatter.string(from: m.capturedDate! as Date)
                ]
                measurementReportList.append(mJson)
            }
        }
        
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let systemStr = "macOS \(systemVersion.majorVersion).\(systemVersion.minorVersion).\(systemVersion.patchVersion)"
        
        var p: [String: Any] = [
            "ip_address": (process.session != nil) ? process.session?.ipAddress ?? "127.0.0.1" : "",
            "processName": process.process_name!,
            "userID": username,
            "measurementReportList": measurementReportList,
            "pid": (process.pid != nil) ? process.pid! : "",
            "osversion": systemStr
        ]
        if let macAdr = process.session?.macAddress {
            p["mac_address"] = process.session?.macAddress?.uppercased()
        }
        
        return p
    }
    
    public static func sendProcesses(token: String, username: String, processes: [ActiveProcess], measurements: [EnergyMeasurement], completion: @escaping (_ response: Int) -> Void) {
        
        var processesArrayJSON: [[String: Any]] = []
        
        
        for process in processes.prefix(1000) {
            processesArrayJSON.append(extractDataFromProcess(process: process, username: username))
        }
        
        /*
        print("Sending processes....", processesArrayJSON.count)
        print("Example:", processesArrayJSON.first)
        */
 
        let processesArray: [String: [Any]] = ["processesReport": processesArrayJSON]
        do {
            
            let jsonData = try! JSONSerialization.data(withJSONObject: processesArray, options: .prettyPrinted)
            /*
             let jsonString = NSString(data: jsonData, encoding: String.Encoding.ascii.rawValue)
             print("jsonData: \(String(describing: jsonString))")
            */
 
            // create post request
            var request = URLRequest(url: URL(string: "\(ServerPrefs.getServerUrl())/V1/process")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("\(token)", forHTTPHeaderField: "Token")
            
            // insert json data to the request
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                
                if error != nil {
                    completion(-1)
                    return
                }
                
                let responseCode = (response as! HTTPURLResponse).statusCode
                
                if (responseCode == 201 || responseCode == 200) {
                    completion(1)
                    return
                } else if (responseCode == 401) {
                    completion(2)
                    return
                } else {
                    completion(-1)
                    return
                }
            }
            
            task.resume()
        }
    }
}

