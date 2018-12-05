//
//  Keyword.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 05/02/2017.
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Foundation

class Keyword: NSObject {
    
    var keyword: String
    
    override init() {
        self.keyword = "default_keyword"
    }
    
    init (keyword: String) {
        self.keyword = keyword
    }
}
