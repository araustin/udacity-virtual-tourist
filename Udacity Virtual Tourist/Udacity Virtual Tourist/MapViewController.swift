//
//  ViewController.swift
//  Udacity Virtual Tourist
//
//  Created by Russell Austin on 6/16/15.
//  Copyright (c) 2015 Russell Austin. All rights reserved.
//

import UIKit
import MapKit
import CoreData

/**
Flicker API
fab57d67573d42d644953ca8b54c7f6e

Secret:
d71749318920aaa0
*/
class MapViewController: UIViewController, MKMapViewDelegate {
    
    struct Keys {
        static let region = "region"
    }
    
    /// Shows where the pin would be dropped once the touch ends
    var floatingPin: MKPointAnnotation?
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.delegate = self
        
        restoreLastMapRegion()
        
        let pins = fetchAllPins()
        for pin in pins {
            mapView.addAnnotation(pin)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Touch event handling
    
    @IBAction func didLongPress(recognizer: UIGestureRecognizer) {
       
        let viewLocation = recognizer.locationInView(mapView)
        let coordinate = mapView.convertPoint(viewLocation, toCoordinateFromView: mapView)
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        
        switch recognizer.state {
        case .Changed, .Ended:
            mapView.removeAnnotation(floatingPin)
            fallthrough
        default:
            floatingPin = annotation
            mapView.addAnnotation(annotation)
        }
       
        if recognizer.state == .Ended {
            
            let dictionary = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
            let pin = Pin(dictionary: dictionary, context: sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
 
    // MARK: MapView delegate implementation
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
   
    // MARK: Fetch all
    func fetchAllPins()  -> [Pin] {
        let error: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        let results = sharedContext.executeFetchRequest(fetchRequest, error: error)
        if error != nil {
            println("Error in fetchAllPins(): \(error)")
        }
        return results! as! [Pin]
    }
   
    // MARK: - Map region save and retrieve
    
    /**
    Use UserDefaults to restore the region
    */
    func restoreLastMapRegion() {
        if let regionDictionary = NSUserDefaults.standardUserDefaults().dictionaryForKey(Keys.region) {
            
            var region = MKCoordinateRegionMake(
                CLLocationCoordinate2DMake(
                    regionDictionary["latitude"] as! Double,
                    regionDictionary["longitude"] as! Double
                ),
                MKCoordinateSpanMake(
                    regionDictionary["spanLatitude"] as! Double,
                    regionDictionary["spanLongitude"]as! Double
                )
            )
            mapView.setRegion(region, animated: true)
        }       
    }
    
    /**
    Use UserDefaults to save the region
    */
    func saveMapRegion() {
        let region = mapView.region
        var regionDictionary = [
            "latitude": region.center.latitude,
            "longitude": region.center.longitude,
            "spanLatitude":   region.span.latitudeDelta,
            "spanLongitude":   region.span.longitudeDelta
        ]
        
        NSUserDefaults.standardUserDefaults().setObject(regionDictionary, forKey: Keys.region)
    }
    
    // MARK: Core Data convenience method
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }

}

