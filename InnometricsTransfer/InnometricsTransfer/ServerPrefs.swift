//
//  ServerPrefs.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 26/02/2017.
//  Copyright © 2020 Denis Zaplatnikov, Pavel Kotov & Dragos Strugar.
//  Innopolis University, All rights reserved.
//

import Foundation

public class ServerPrefs {
    
    private static var serverUrlAlias: String = "serverUrl"

    public static func saveServerUrl(serverUrl: String) {
        let defaults = UserDefaults.standard
        defaults.set(serverUrl, forKey: serverUrlAlias)
    }
    
    public static func getServerUrl() -> String {
        let defaults = UserDefaults.standard
        // this is the api v1 (https://innometric.guru:8120)
        return defaults.string(forKey: serverUrlAlias) ?? "http://innometric.guru:9091"
    }
    
}
