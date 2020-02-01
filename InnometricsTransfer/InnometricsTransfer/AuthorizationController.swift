//
//  AuthorizationController.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 25/02/2017.
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Cocoa

class AuthorizationController: NSViewController {

    @IBOutlet weak var offlineModeBtn: NSButton!
    @IBOutlet weak var loginBtn: NSButton!
    @IBOutlet weak var emailTextField: NSTextField!
    @IBOutlet weak var passwordTextField: NSSecureTextField!
    
    @IBOutlet weak var loaderIndicator: NSProgressIndicator!
    
    override func viewDidAppear() {
        self.view.window?.titleVisibility = .hidden
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.isMovableByWindowBackground = true
        self.view.window?.backgroundColor = NSColor.gray
        self.view.window?.styleMask = [(self.view.window?.styleMask)!]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let attrs = [convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor) : NSColor.white, convertFromNSAttributedStringKey(NSAttributedString.Key.font) : NSFont.systemFont(ofSize: 17.0)] as [String : Any]
        let buttonTitleStr = NSMutableAttributedString(string:"Login", attributes:convertToOptionalNSAttributedStringKeyDictionary(attrs))
        let attributedString = NSMutableAttributedString(string: "")
        attributedString.append(buttonTitleStr)
        loginBtn.setValue(attributedString, forKey: "attributedTitle")
    }
    
    @IBAction func offlineBtn_Clicked(_ sender: Any) {
        DispatchQueue.main.async {
            AuthorizationUtils.enableOfflineMode()
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let mvc = storyboard.instantiateController(withIdentifier:"MainController") as! MainController
            self.view.window?.contentViewController = mvc
        }
    }
    
    @IBAction func loginBtn_Clicked(_ sender: AnyObject) {
        let email = emailTextField.stringValue
        let password = passwordTextField.stringValue
        if (((email.range(of: "\\s+", options: .regularExpression) != nil) || email.count == 0) && ((password.range(of: "\\s+", options: .regularExpression) != nil) || password.count == 0)) {
            dialogOKCancel(question: "Warning", text: "Enter your email and password")
        } else if (((email.range(of: "\\s+", options: .regularExpression) != nil) || email.count == 0)) {
            dialogOKCancel(question: "Warning", text: "Enter your email")
        } else if (((password.range(of: "\\s+", options: .regularExpression) != nil) || password.count == 0)) {
            dialogOKCancel(question: "Warning", text: "Enter your password")
        } else {
            loaderIndicator.isHidden = false
            loaderIndicator.startAnimation(self)
            disableInputElements()
            
            AuthorizationUtils.authorization(username: email, password: password) { (token) in
                DispatchQueue.main.async {
                    self.enableInputElements()
                    self.loaderIndicator.stopAnimation(self)
                    self.loaderIndicator.isHidden = true
                    if (token == nil) {
                        self.dialogOKCancel(question: "Error", text: "Wrong input authorization data")
                    } else {
                        AuthorizationUtils.saveAuthorizationToken(token: token!)
                        AuthorizationUtils.saveIsAuthorized(isAuthorized: true)
                        let storyboard = NSStoryboard(name: "Main", bundle: nil)
                        let mvc = storyboard.instantiateController(withIdentifier:"MainController") as! MainController
                        self.view.window?.contentViewController = mvc
                        AuthorizationUtils.disableOfflineMode()
                    }
                }
            }
        }
    }
    
    func enableInputElements() {
        loginBtn.isEnabled = true
        emailTextField.isEnabled = true
        passwordTextField.isEnabled = true
    }
    
    func disableInputElements() {
        loginBtn.isEnabled = false
        emailTextField.isEnabled = false
        passwordTextField.isEnabled = false
    }
    
    func dialogOKCancel(question: String, text: String) {
        let myPopup: NSAlert = NSAlert()
        myPopup.messageText = question
        myPopup.informativeText = text
        myPopup.alertStyle = NSAlert.Style.informational
        myPopup.addButton(withTitle: "OK")
        myPopup.runModal()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
