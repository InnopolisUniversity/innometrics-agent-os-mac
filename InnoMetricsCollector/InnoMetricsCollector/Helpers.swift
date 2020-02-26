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
    
    public static func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    public static func dialogOK(question: String, text: String) {
        let myPopup: NSAlert = NSAlert()
        myPopup.messageText = question
        myPopup.informativeText = text
        myPopup.alertStyle = NSAlert.Style.informational
        myPopup.addButton(withTitle: "OK")
        myPopup.runModal()
    }
}
