//
//  BrowserInfoUtils.swift
//  InnoMetricsCollector
//
//  Created by Denis Zaplatnikov on 18/01/2017.
//  Modified by Dragos Strugar on 13/02/2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation

class BrowserInfoUtils {
    
    // Get browser tab url
    static func activeTabURL(bundleIdentifier: String) -> String? {
        var code: String?
        
        switch(bundleIdentifier){
            case "org.chromium.Chromium":
                code = "tell application \"Chromium\" to return URL of active tab of front window"
            case "com.google.Chrome.canary":
                code =  "tell application \"Google Chrome Canary\" to return URL of active tab of front window"
            case "com.google.Chrome":
                code =  "tell application \"Google Chrome\" to return URL of active tab of front window"
            case "com.apple.Safari":
                code = "tell application \"Safari\" to return URL of front document"
            case "com.jetbrains.pycharm":
                code = "tell application \"Pycharm\" to return window title"
            case "com.operasoftware.Opera":
                code = "tell application \"Opera\" to return URL of active tab of front window"
            case "ru.yandex.desktop.yandex-browser":
                code = "tell application \"Yandex\" to return URL of active tab of front window"
            case "org.mozilla.firefox":
                code = "tell application \"Firefox\" to return URL of active tab of front window"
            case "org.mozilla.firefoxdeveloperedition":
                code = "tell application \"Firefox Developer Edition\" to return URL of active tab of front window"
            default:
                code = nil
        }
        
        if (code == nil) {
            return nil;
        }
        
        return appleScripExec(code: code!)
    }
    
    // Get browser tab name
    static func activeTabTitle(bundleIdentifier: String) -> String? {
        var code: String?
        
        switch(bundleIdentifier){
            case "org.chromium.Chromium":
                code =  "tell application \"Chromium\" to return title of active tab of front window"
            case "com.google.Chrome.canary":
                code =  "tell application \"Google Chrome Canary\" to return title of active tab of front window"
            case "com.google.Chrome":
                code =  "tell application \"Google Chrome\" to return title of active tab of front window"
            case "com.apple.Safari":
                code =  "tell application \"Safari\" to return name of front document"
            case "com.jetbrains.pycharm":
                code = "tell application \"Pycharm\" to return window title"
            case "com.operasoftware.Opera":
                code = "tell application \"Opera\" to return title of active tab of front window"
            case "ru.yandex.desktop.yandex-browser":
                code = "tell application \"Yandex\" to return title of active tab of front window"
            case "org.mozilla.firefox":
                code = "tell application \"Firefox\" to return title of active tab of front window"
            case "org.mozilla.firefoxdeveloperedition":
                code = "tell application \"Firefox Developer Edition\" to return title of active tab of front window"
            default:
                code =  nil
        }
        
        if (code == nil) {
            return nil;
        }
        
        return appleScripExec(code: code!)
    }
    
    private static func appleScripExec(code: String) -> String? {
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: code)
        let scriptOutput = script?.executeAndReturnError(&errorInfo)
        if ((errorInfo) != nil) {
            print(errorInfo ?? "there has been an error using apple scripts")
            return nil;
        } else {
            return scriptOutput?.stringValue
        }
    }
}
