//
//  MetricsTransfer.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 25/02/2017.
//  Modified by Dragos Strugar in 2020
//  Copyright © 2020 Innopolis University.
//

import Foundation

public class MetricsTransfer {
    
    public static func extractDataFromMetric(metric: Metric, username: String, idle: Bool = false) -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        let activity: [String: Any] = [
            "idle_activity": idle,
            "start_time": dateFormatter.string(from: metric.timestampStart! as Date),
            "end_time": (metric.timestampEnd != nil) ? dateFormatter.string(from: metric.timestampEnd! as Date) : dateFormatter.string(from: Date()),
            "executable_name": metric.bundleURL != nil ? metric.bundleURL!.split(separator: "/").last! : "",
            "browser_url": metric.tabUrl ?? "",
            "browser_title": metric.tabName ?? "",
            "ip_address": (metric.session != nil) ? metric.session?.ipAddress : "",
            "mac_address": (metric.session != nil) ? metric.session?.macAddress : "",
            "activityType": "os",
            "activityID": 0,
            "userID": username
        ]
        
        return activity
    }
    
    public static func sendMetrics(token: String, username: String, focusAppMetrics: [Metric], idleMetrics: [IdleMetric], completion: @escaping (_ response: Int) -> Void) {
        
        var activitiesArrayJson: [[String: Any]] = []
        
        for metric in focusAppMetrics {
            activitiesArrayJson.append(extractDataFromMetric(metric: metric, username: username))
        }
        
        for metric in idleMetrics {
            activitiesArrayJson.append(extractDataFromMetric(metric: metric, username: username, idle: true))
        }
        
        let activities: [String: [Any]] = ["activities": activitiesArrayJson]
        do {
            let jsonData = try! JSONSerialization.data(withJSONObject: activities, options: .prettyPrinted)
            
            /*
             let jsonString = NSString(data: jsonData, encoding: String.Encoding.ascii.rawValue)
             print("jsonData: \(String(describing: jsonString))")
            */
 
            // create post request
            var request = URLRequest(url: URL(string: "\(ServerPrefs.getServerUrl())/V1/activity")!)
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
                
                print(responseCode)
                
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
