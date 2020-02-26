//
//  Helpers.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 26.02.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa

class Helpers {
    public static func shell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String

        return output
    }
    
    public static func isLoggedIn() -> Bool {
        // TODO: check if token expired
        let defaults = UserDefaults.standard
        let token = defaults.string(forKey: "token")
        if token == nil {
            return false
        }
        
        return true
    }
}
