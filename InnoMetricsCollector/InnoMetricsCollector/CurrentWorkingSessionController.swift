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
    @IBOutlet weak var cpuModel: NSTextField!
    @IBOutlet weak var systemType: NSTextField!
    @IBOutlet weak var noOfThreads: NSTextField!
    
    func updateSession(session: Session) {
        DispatchQueue.main.async {
            if (session.operatingSystem != nil) {
                self.operatingSystem.stringValue = session.operatingSystem!
                self.operatingSystem.sizeToFit()
            }
            if (session.userName != nil) {
                self.userName.stringValue = session.userName!
                self.userName.sizeToFit()
            }
            if (session.userLogin != nil) {
                self.userLogin.stringValue = session.userLogin!
                self.userLogin.sizeToFit()
            }
            if (session.ipAddress != nil) {
                self.ipAddress.stringValue = session.ipAddress!
                self.ipAddress.sizeToFit()
            }
            if (session.macAddress != nil) {
                self.macAddress.stringValue = session.macAddress!.uppercased()
                self.macAddress.sizeToFit()
            }

            self.cpuModel.stringValue = Helpers.shell("sysctl -n machdep.cpu.brand_string").split{ $0.isNewline }[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.cpuModel.sizeToFit()
            
            self.systemType.stringValue = Helpers.shell("sysctl -n hw.model | grep \"Book\"").split{ $0.isNewline }[0].trimmingCharacters(in: .whitespacesAndNewlines)
            
            self.noOfThreads.stringValue = Helpers.shell("sysctl -n hw.ncpu").split{ $0.isNewline }[0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
