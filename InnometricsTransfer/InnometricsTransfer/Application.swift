//
//  Application.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 06/02/2017.
//  Copyright © 2020 Denis Zaplatnikov, Pavel Kotov & Dragos Strugar. All rights reserved.
//

import Foundation

class Application: NSObject {
    
    var application: String
    
    override init() {
        self.application = "default_application"
    }
    
    init (application: String) {
        self.application = application
    }
}
