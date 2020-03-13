//
//  CurrentWorkingSessionController.swift
//  InnoMetricsCollector
//
//  Created by Denis Zaplatnikov on 12/01/2017.
//  Modified in 2020 by Dragos Strugar
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Cocoa

class CurrentWorkingSessionController: NSView {
    
    @IBOutlet weak var operatingSystem: NSTextField!
    @IBOutlet weak var userName: NSTextField!
    @IBOutlet weak var userLogin: NSTextField!
    @IBOutlet weak var ipAddress: NSTextField!
    @IBOutlet weak var macAddress: NSTextField!
    
    func updateSession(session: Session) {
        if (session.operatingSystem != nil) {
            operatingSystem.stringValue = session.operatingSystem!
            operatingSystem.sizeToFit()
        }
        if (session.userName != nil) {
            userName.stringValue = session.userName!
            userName.sizeToFit()
        }
        if (session.userLogin != nil) {
            userLogin.stringValue = session.userLogin!
            userLogin.sizeToFit()
        }
        if (session.ipAddress != nil) {
            ipAddress.stringValue = session.ipAddress!
            ipAddress.sizeToFit()
        }
        if (session.macAddress != nil) {
            macAddress.stringValue = session.macAddress!
            macAddress.sizeToFit()
        }
    }
}
