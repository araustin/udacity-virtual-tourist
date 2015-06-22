//
//  Photo.swift
//  Udacity Virtual Tourist
//
//  Created by Russell Austin on 6/16/15.
//  Copyright (c) 2015 Russell Austin. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation

@objc(Photo)
class Photo: NSManagedObject {
   
    struct Keys {
        static let URL = "url"
    }
   
    struct Config {
        static let flickrURLTemplate = ["https://farm", "{farm-id}", ".staticflickr.com/", "{server-id}", "/", "{id}", "_", "{secret}", "_z.jpg"]
    }
   
    /// The Flickr URL also the path in the documents directory
    @NSManaged var url: String
    
    /// The associated pin
    @NSManaged var pin: Pin?
   
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
 
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        url = dictionary[Keys.URL] as! String
    }
   
    /**
    Builds the URL from the Flickr data

    :photo: The photo information
    :returns: The URL
    */
    class func buildFlickrUrl(photo: [String: AnyObject]) -> String {
        var photoUrlParts = Config.flickrURLTemplate
        photoUrlParts[1] = String(photo["farm"] as! Int)
        photoUrlParts[3] = photo["server"] as! String
        photoUrlParts[5] = photo["id"] as! String
        photoUrlParts[7] = photo["secret"] as! String

        return "".join(photoUrlParts)
    }
}