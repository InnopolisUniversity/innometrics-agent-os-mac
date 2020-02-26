//
//  LoginController.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 26.02.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa

class LoginViewController: NSView {
    @IBOutlet weak var emailField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!

    
    @IBAction func onLogIn(_ sender: Any) {
        // TODO: send API request
        
        // If successful, save token + display menu
        // If unsuccessful, display warning
    }
}
