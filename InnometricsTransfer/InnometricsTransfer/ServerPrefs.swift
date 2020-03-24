//
//  ServerPrefs.swift
//  InnometricsTransfer
//
//  Created by Denis Zaplatnikov on 26/02/2017.
//  Modified by Dragos Strugar in 2020
//  Copyright © 2020 Innopolis University.
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
        // this is the api v1 (https://innometric.guru:8120)
        return "https://innometric.guru:9091"
        // this is the dev api: return "http://10.90.137.67:9091"
    }
}
