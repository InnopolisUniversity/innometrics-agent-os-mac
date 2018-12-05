//
//  MetricsTransfer.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 25/02/2017.
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Foundation

public class MetricsTransfer {
    
    public static func extractDataFromMetric(metric: Metric, idle: Bool = false) -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let activity: [String: Any] = [
            "idle_activity": idle,
            "start_time": dateFormatter.string(from: metric.timestampEnd as! Date),
            "end_time": dateFormatter.string(from: metric.timestampStart as! Date),
            "executable_name": metric.bundleURL ?? "",
            "browser_url": metric.tabUrl ?? "",
            "browser_title": metric.tabName ?? "",
            "ip_address": metric.session!.ipAddress ?? "",
            "mac_address": metric.session!.macAddress ?? ""
        ]
        return activity
    }
    
    public static func sendMetrics(token: String, focusAppMetrics: [Metric], idleMetrics: [IdleMetric], completion: @escaping (_ response: Int) -> Void) {
        
        var activitiesArrayJson: [[String: Any]] = []
        for metric in focusAppMetrics {
            activitiesArrayJson.append(extractDataFromMetric(metric: metric))
        }
        for metric in idleMetrics {
            activitiesArrayJson.append(extractDataFromMetric(metric: metric, idle: true))
        }
        
        let activities: [String: [Any]] = ["activities": activitiesArrayJson]
        let finalJson: [String: Any] = ["activity": activities]
        do {
            let jsonData = try! JSONSerialization.data(withJSONObject: finalJson, options: .prettyPrinted)
            
//            let jsonString = NSString(data: jsonData, encoding: String.Encoding.ascii.rawValue)
//            print("jsonData: \(jsonString)")
            // create post request
            var request = URLRequest(url: URL(string: "\(ServerPrefs.getServerUrl())/activity")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
            
            // Day-long timeout... maybe server will process metrics faster, then this will be to removed
            request.timeoutInterval = 86400
            
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
                } else if (responseCode == 401) {
                    completion(2)
                    return
                }
                else {
                    completion(-1)
                    return
                }
            }
            
            task.resume()
        }
    }
}
