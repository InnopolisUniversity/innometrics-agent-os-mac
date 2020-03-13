//
//  EnergyMeasurement+CoreDataProperties.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 26.02.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import CoreData

extension EnergyMeasurement {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EnergyMeasurement> {
        return NSFetchRequest<EnergyMeasurement>(entityName: "EnergyMeasurement")
    }
    
    @NSManaged public var alternativeLabel: String!
    @NSManaged public var measurementTypeId: String!
    @NSManaged public var value: String!
    @NSManaged public var process: ActiveProcess?
    @NSManaged public var capturedDate: NSDate?
}
