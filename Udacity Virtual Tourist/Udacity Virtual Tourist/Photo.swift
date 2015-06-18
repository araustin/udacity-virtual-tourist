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

/**
URL FOrmat
https://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}_[mstzb].jpg
*/
@objc(Photo)
class Photo: NSManagedObject {
    
    struct Keys {
        static let URL = "url"
    }
    
    struct Config {
        static let SearchURL = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=fe55c54bf73041bb22103a594eefe684&format=json&nojsoncallback=1"
        static let Radius = 1 /* kilometers */
        static let flickrURLTemplate = ["https://farm", "{farm-id}", ".staticflickr.com/", "{server-id}", "/", "{id}", "_", "{secret}", "_q.jpg"]
    }
    

    @NSManaged var url: String
    @NSManaged var pin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
 
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        url = dictionary[Keys.URL] as! String
    }
    
   
    //MARK: - Flickr image search
    
    /**
    Searches for image given a Pin. The radius is specified in the Config struct. Found photos are associated with the Pin and saved in the managed object context
    
    :param: pin The center point for the search.
    :param: didComplete Callback when search request compeletes
    */
    class func search(pin: Pin, didComplete: (success: Bool) -> Void) {
        let url = "\(Config.SearchURL)&lat=\(pin.coordinate.latitude)&lon=\(pin.coordinate.longitude)&radius=\(Config.Radius)"
        println(url)
        let request = NSURLRequest(URL: NSURL(string: url)!)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            if error != nil {
                didComplete(success: false)
                return
            }
            Photo.savePhotosForPin(pin, data: data)
            didComplete(success: true)
        }
        task.resume()
    }
    
    class func savePhotosForPin(pin: Pin, data: NSData) -> Bool {
       var success = false
        if let search = NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers, error: nil) as? NSDictionary {
            if let photoData = search["photos"] as? [String: AnyObject],
            let photos = photoData["photo"] as? [AnyObject]
            {
                success = true
                for photo in photos {
                    
                    let photoUrl = Photo.buildFlickrUrl(photo as! [String : AnyObject])
                    let photo = Photo(dictionary: ["url": photoUrl], context: pin.managedObjectContext!)
                    photo.pin = pin
                    
                    var error = NSErrorPointer()
                    pin.managedObjectContext?.save(error)
                    
                    if error != nil {
                        success = false
                        break
                    }
                }
            }
        }
        return success
    }
    
    class func buildFlickrUrl(photo: [String: AnyObject]) -> String {
        var photoUrlParts = Config.flickrURLTemplate
        photoUrlParts[1] = String(photo["farm"] as! Int)
        photoUrlParts[3] = photo["server"] as! String
        photoUrlParts[5] = photo["id"] as! String
        photoUrlParts[7] = photo["secret"] as! String

        return "".join(photoUrlParts)
    }
}
