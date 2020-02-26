//
//  LoginViewController.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 26.02.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa

class LoginViewController: NSViewController {
    @IBOutlet weak var emailField: NSTextField!
    @IBOutlet weak var passwordField: NSSecureTextField!
    
    @IBOutlet weak var loaderIndicator: NSProgressIndicator!
    
    override func viewDidAppear() {
        loaderIndicator.isHidden = true
    }
    
    @IBAction func onLogIn(_ sender: Any) {
        loaderIndicator.isHidden = false
        loaderIndicator.startAnimation(self)
        
        let email = emailField.stringValue
        let password = passwordField.stringValue
        
        if !Helpers.isValidEmail(email) {
            Helpers.dialogOK(question: "Error", text: "Please enter a valid email address.")
        }
        
        AuthorizationUtils.authorization(username: email, password: password) { (token) in
            DispatchQueue.main.async {
                self.loaderIndicator.stopAnimation(self)
                self.loaderIndicator.isHidden = true
                if (token == nil) {
                    print("no success")
                    Helpers.dialogOK(question: "Error", text: "Wrong input authorization data")
                } else {
                    print("success")
                    AuthorizationUtils.saveAuthorizationToken(token: token!)
                    AuthorizationUtils.saveUsername(username: email)
                    AuthorizationUtils.saveIsAuthorized(isAuthorized: true)
                    
                    self.view.window?.close()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
