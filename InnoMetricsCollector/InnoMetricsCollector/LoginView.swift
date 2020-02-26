//
//  LoginController.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 26.02.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa

class LoginView: NSView {
    @IBOutlet weak var emailField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    @IBOutlet weak var onLogIn: NSButton!
    
    @IBAction func onLogIn(_ sender: Any) {
        NSApp.activate(ignoringOtherApps: true)
        let emailVal = emailField.stringValue
        let pwVal = passwordField.stringValue
        
        AuthorizationUtils.authorization(username: emailVal, password: pwVal) { (token) in
            DispatchQueue.main.async {
                if (token == nil) {
                    Helpers.dialogOKCancel(question: "Error", text: "Wrong credentials")
                    
                    print("login unsuccessful")
                } else {
                    AuthorizationUtils.saveAuthorizationToken(token: token!)
                    AuthorizationUtils.saveUsername(username: emailVal)
                    AuthorizationUtils.saveIsAuthorized(isAuthorized: true)
                    
                    print("login successful")
                    print("token")
                    print(token)
                }
                
            }
        }
    }
}
