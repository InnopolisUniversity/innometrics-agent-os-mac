//
//  IdleMetric+CoreDataProperties.swift
//  InnoMetricsCollector
//
//  Created by Pavel Kotov on 05/03/2018.
//  Copyright © 2018 Pavel Kotov. All rights reserved.
//

import Foundation
import CoreData

extension IdleMetric {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<IdleMetric> {
        return NSFetchRequest<IdleMetric>(entityName: "IdleMetric")
    }
    
    @NSManaged public var appName: String?
    @NSManaged public var duration: Double
    @NSManaged public var timeStampStart: NSDate?
    @NSManaged public var timeStampEnd: NSDate?
    @NSManaged public var session: Session?
}

