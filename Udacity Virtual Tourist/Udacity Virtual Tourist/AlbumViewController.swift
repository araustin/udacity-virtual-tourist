//
//  AlbumViewController.swift
//  Udacity Virtual Tourist
//
//  Created by Russell Austin on 6/16/15.
//  Copyright (c) 2015 Russell Austin. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class AlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    /// The pin we are loading images for
    var pin: Pin!
    
    /// Image cache
    var cache = ImageCache.Static.instance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var error = NSErrorPointer()
        fetchedResultsController.performFetch(error)
        if error != nil {
            println("Error fetching \(error)")
        }
        
        fetchedResultsController.delegate = self
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadAllPhotos:", name: Pin.Config.AllPhotosLoadedForPinNotification, object: pin)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        newCollectionButton.enabled = pin.photosLoadState == .Loaded
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func didLoadAllPhotos(sender: AnyObject) {
        newCollectionButton.enabled = true
    }
    
    @IBAction func didPressNewCollection(sender: UIButton) {
        pin.deletePhotos()
        pin.loadPhotos(getNextPage: true)
    }
    // MARK: - Collection view datasource implementation
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell", forIndexPath: indexPath) as! PhotoCell
        
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        cell.imageView.image = UIImage(named: "no-image")
        cell.activityIndicator.startAnimating()
        if let image = cache.imageWithIdentifier(photo.url) {
            println("IMAGE IN CACHE \(photo.url)")
            cell.activityIndicator.stopAnimating()
            cell.imageView.image = image
        } else {
            println("NO CACHE \(photo.url)")
            getRemoteImage(cell, photo: photo)
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }
    
    
    // MARK: - Remote image download
    /**
    Downloads the given photo and sets the image in the cell. Stores the image in the cache for later use.
    
    :param: cell The PhotoCell
    :param: photo The Photo
    */
    func getRemoteImage(cell: PhotoCell, photo: Photo) {
        let task = cache.downloadImage(photo.url) { imageData, error in
            if imageData != nil {
                let image = UIImage(data: imageData!)
                self.cache.storeImage(image, withIdentifier: photo.url)
                dispatch_async(dispatch_get_main_queue()) {
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                }
            }
        }
        cell.taskToCancelifCellIsReused = task       
    }
    
    
    // MARK: - NSFetchedResultsController
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "url", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    // MARK: Core Data convenience method
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
 
}

