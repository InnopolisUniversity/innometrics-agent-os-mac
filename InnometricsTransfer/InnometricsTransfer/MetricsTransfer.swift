//
//  MetricsTransfer.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 25/02/2017.
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Foundation

public class MetricsTransfer {

    public static func sendMetrics(token: String, focusAppMetrics: [Metric], idleMetrics: [IdleMetric], completion: @escaping (_ response: Int) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        var activitiesArrayJson: [[String: Any]] = []
        for metric in focusAppMetrics {
            
            var measurementsArrayJson: [[String: Any]] = []
            let appBundleIdentifierJson: [String: String] = ["name": "bundle_identifier", "type": "string", "value": metric.bundleIdentifier ?? ""]
            let appBundleURLJson: [String: String] = ["name": "path", "type": "string", "value": metric.bundleURL ?? ""]
            let appDurationJson: [String: String] = ["name": "activity_duration", "type": "double", "value": String(format:"%.0f", metric.duration)]
            if metric.tabName != nil {
                var tabName: String = ""
                if (metric.tabName!.count < 200) {
                    tabName = metric.tabName!
                }
                else {
                    tabName = String(metric.tabName!.prefix(199))
                }
                let appTabNameJson: [String: String] = ["name": "window title", "type": "string", "value": tabName]
                measurementsArrayJson.append(appTabNameJson)
            }
            if metric.tabUrl != nil {
                // Check, if tab's name is greater than 200 - number, which causes error on server. If it is, just
                // cut it up to the second domain name
                var tabUrl: String = ""
                if (metric.tabUrl!.count < 200) {
                    tabUrl = metric.tabUrl!
                }
                else {
                    if let host = NSURL(string: metric.tabUrl!)?.host {
                        tabUrl = host
                    }
                }
                let appTabUrlJson: [String: String] = ["name": "url", "type": "string", "value": tabUrl]
                measurementsArrayJson.append(appTabUrlJson)
            }
            let appTimestampStartJson: [String: String] = ["name": "activity end", "type": "epoch_time", "value":  String(format: "%.0f", metric.timestampStart!.timeIntervalSince1970)]
            if metric.timestampEnd != nil {
                let appTimestampEndJson: [String: String] = ["name": "activity start", "type": "epoch_time", "value":String(format: "%.0f", metric.timestampEnd!.timeIntervalSince1970)]
                
                measurementsArrayJson.append(appTimestampEndJson)
            }
            measurementsArrayJson.append(appBundleIdentifierJson)
            measurementsArrayJson.append(appBundleURLJson)
            measurementsArrayJson.append(appDurationJson)
            measurementsArrayJson.append(appTimestampStartJson)
            
            if (metric.session != nil) {
                let appSessionIpAddress: [String: String] = ["name": "ip address", "type": "string", "value": metric.session!.ipAddress ?? ""]
                let appSessionMacAddress: [String: String] = ["name": "mac address", "type": "string", "value": metric.session!.macAddress ?? ""]
                let operatingSystem: [String: String] = ["name": "os name", "type": "string", "value": metric.session!.operatingSystem ?? ""]
                let userLogin: [String: String] = ["name": "session_user_login", "type": "string", "value": metric.session!.userLogin ?? ""]
                let userName: [String: String] = ["name": "os username", "type": "string", "value": metric.session!.userName ?? ""]
                let applicationName: [String: String] = ["name": "application name", "type": "string", "value": metric.appName ?? "undefined"]
                
                measurementsArrayJson.append(appSessionIpAddress)
                measurementsArrayJson.append(appSessionMacAddress)
                measurementsArrayJson.append(operatingSystem)
                measurementsArrayJson.append(userLogin)
                measurementsArrayJson.append(userName)
                measurementsArrayJson.append(applicationName)
            }
            
            activitiesArrayJson.append(["name": "MacOS Agent", "measurements": measurementsArrayJson])
        }
        
        for metric in idleMetrics {
            var measurementsArrayJson: [[String: Any]] = []
            let appName: [String: String] = ["name": "application name", "type": "string", "value": metric.appName ?? ""]
            let duration: [String: String] = ["name": "idle time duration", "type": "double", "value": String(format:"%.0f", metric.duration)]
            let timeStampStart: [String: String] = ["name": "idle time start", "type": "epoch_time", "value": String(format: "%.0f", metric.timeStampStart!.timeIntervalSince1970)]
            if metric.timeStampEnd != nil {
                let timeStampEnd: [String: String] = ["name": "idle time end", "type": "epoch_time", "value": String(format: "%.0f", metric.timeStampEnd!.timeIntervalSince1970)]
                measurementsArrayJson.append(timeStampEnd)
            }
            measurementsArrayJson.append(appName)
            measurementsArrayJson.append(duration)
            measurementsArrayJson.append(timeStampStart)
            
            activitiesArrayJson.append(["name": "MacOS Agent", "measurements": measurementsArrayJson])
        }
        
        let finalJson: [String: [Any]] = ["activities": activitiesArrayJson]
        do {
            let jsonData = try! JSONSerialization.data(withJSONObject: finalJson, options: .prettyPrinted)
            
//            let jsonString = NSString(data: jsonData, encoding: String.Encoding.ascii.rawValue)
//            print("jsonData: \(jsonString)")
            // create post request
            var request = URLRequest(url: URL(string: "\(ServerPrefs.getServerUrl())/activities/")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
            
            // insert json data to the request
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil
                {
                    print("\(error)")
                    completion(-1)
                    return
                }
                
                let responseCode = (response as! HTTPURLResponse).statusCode
                if (responseCode == 201) {
                    completion(1)
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
