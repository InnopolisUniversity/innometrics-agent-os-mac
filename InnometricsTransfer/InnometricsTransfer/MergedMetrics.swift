//
//  MergedMetrics.swift
//  InnometricsTransfer
//
//  Created by Pavel Kotov on 29/03/2018.
//  Modified by Dragos Strugar in 2020
//  Copyright © 2020 Innopolis University.
//

/*
 Class to represent all metrics merged together into one type
 */
import Foundation

class MergedMetric {
    
    public enum MetricType {
        case appFocus
        case idle
        
        var stringValue: String {
            switch self {
                case .appFocus:
                    return "App Focus"
                case .idle:
                    return "Idle"
            }
        }
    }
    
    public let type: MetricType
    
    public var appName: String
    public var duration: Double
    public var timestampStart: NSDate
    public var timestampEnd: NSDate
    
    public var bundleIdentifier: String?
    public var bundleURL: String?
    public var tabName: String?
    public var tabURL: String?
    
    public init(_type: MetricType, _appName: String, _duration: Double, _start: NSDate, _end: NSDate, _bundleId: String?, _bundleURL: String?, _tabName: String?, _tabURL: String?) {
        appName = _appName
        duration = _duration
        timestampStart = _start
        timestampEnd = _end
        bundleIdentifier = _bundleId
        bundleURL = _bundleURL
        tabName = _tabName
        tabURL = _tabURL
        type = _type
    }
}
