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
class Pin: NSManagedObject, MKAnnotation {

    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    struct Config {
        static let SearchURL = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=fab57d67573d42d644953ca8b54c7f6e&format=json&nojsoncallback=1"
        static let Radius = 1 /* kilometers */
        static let Limit = 12
        static let AllPhotosLoadedForPinNotification = "AllPhotosLoadedForPinNotification"
    }
    
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var photos: [Photo]
    /// What page of the results to load
    @NSManaged var page: Int
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2DMake(latitude as Double, longitude as Double)
        }
    }

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
        
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        latitude = dictionary[Keys.Latitude] as! Double
        longitude = dictionary[Keys.Longitude] as! Double
        page = 1
    }
    
    /// Loads the photos associated with the pin
    func loadPhotos(getNextPage: Bool = false, didCompleteSearch: (numberFound: Int) -> Void) {
        if getNextPage {
            page++
        }
        searchFlickr() { count in
            didCompleteSearch(numberFound: count)
            if count > 0 {
                self.preloadPhotos()
            }
        }
    }
    
    /// Deletes the current photo set
    func deletePhotos() {
        for photo in photos {
            photo.delete()
        }
    }

    //MARK: - Flickr image search
    
    /**
    Searches for image given a Pin. The radius is specified in the Config struct. Found photos are associated with the Pin and saved in the managed object context
    
    :param: didComplete Callback when search request compeletes
    */
    func searchFlickr(didComplete: (numberFound: Int) -> Void) {
        let url = "\(Config.SearchURL)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&radius=\(Config.Radius)&per_page=\(Config.Limit)&page=\(page)"
        let request = NSURLRequest(URL: NSURL(string: url)!)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            if error != nil {
                println("Error searching Flickr \(error)")
                didComplete(numberFound: 0)
                return
            }
            let count = self.savePhotosForPin(data)
            didComplete(numberFound: count)
        }
        task.resume()
    }
    
   
    /**
    Builds and saves the photo url. Also adds the photo to the pin's array of photos

    :param: data The data returned from the request
    :returns: The number of photos saved
    */
    func savePhotosForPin(data: NSData) -> Int {
       var count = 0
        if let search = NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers, error: nil) as? NSDictionary {
            if let photoData = search["photos"] as? [String: AnyObject],
            let photos = photoData["photo"] as? [AnyObject]
            {
                for photo in photos {
                    
                    let file = photo["id"] as! String
                    let photoUrl = Photo.buildFlickrUrl(photo as! [String : AnyObject])
                    let dict = ["url": photoUrl, "file": file]
                    let photo = Photo(dictionary: dict, context: self.managedObjectContext!)
                    photo.pin = self
                    
                    var error = NSErrorPointer()
                    self.managedObjectContext?.save(error)
                    
                    if error != nil {
                        println("Error saving photo \(error)")
                        break
                    }
                    count++
                }
            }
        }
        return count
    }
    
    /// Downloads the photos associated with the pin
    func preloadPhotos() {
        
        var unloadedPhotos = photos.count
        for photo in photos {
            photo.downloadStatus = .Loading
            let task = ImageCache.Static.instance.downloadImage(photo.url) { imageData, error in
                
                // keep track of the loaded photos
                unloadedPhotos--
                
                if imageData == nil {
                    return
                }
                let image = UIImage(data: imageData!)
                photo.saveImage(image!)
                if unloadedPhotos == 0 {
                    NSNotificationCenter.defaultCenter().postNotificationName(Config.AllPhotosLoadedForPinNotification, object: self)
                }
            }
        }
    }
}
