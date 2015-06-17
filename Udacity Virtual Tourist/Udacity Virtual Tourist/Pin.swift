//
//  Pin.swift
//  Udacity Virtual Tourist
//
//  Created by Russell Austin on 6/16/15.
//  Copyright (c) 2015 Russell Austin. All rights reserved.
//

import Foundation
import CoreData
import MapKit

@objc(Pin)
class Pin: NSManagedObject {

    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var photos: [Photo]
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2DMake(latitude as Double, longitude as Double)
        }
    }

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        latitude = dictionary[Keys.Latitude] as! Double
        longitude = dictionary[Keys.Longitude] as! Double
    }
}
