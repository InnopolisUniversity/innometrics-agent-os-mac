//
//  ActiveProcess+CoreDataProperties.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 13.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

import Foundation
import CoreData

extension ActiveProcess {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActiveProcess> {
        return NSFetchRequest<ActiveProcess>(entityName: "ActiveProcess")
    }
    
    @NSManaged public var process_name: String!
    @NSManaged public var measurementReportList: Set<EnergyMeasurement>?
    @NSManaged public var session: Session?
    @NSManaged public var pid: String?
}
