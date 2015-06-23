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
        
        fetchedResultsController.delegate = self
        fetch()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadAllPhotos:", name: Pin.Config.AllPhotosLoadedForPinNotification, object: pin)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadPhoto:", name: Photo.Config.PhotoLoadedForPinNotification, object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        var allPhotosLoaded = true
        for photo in pin.photos {
            if photo.downloadStatus != .Loaded {
                allPhotosLoaded = false
            }
        }
        newCollectionButton.enabled = allPhotosLoaded
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /// use fetched result controller to fetch
    func fetch() {
        var error = NSErrorPointer()
        fetchedResultsController.performFetch(error)
        if error != nil {
            println("Error fetching \(error)")
        }
    }
    
    func didLoadAllPhotos(sender: AnyObject) {
        println("DID LOAD ALL PHOTOS")
        newCollectionButton.enabled = true
        collectionView.layoutSubviews()
        collectionView.reloadData()
    }
    
    func didLoadPhoto(photo: Photo) {
        if let indexPath = fetchedResultsController.indexPathForObject(photo) {
            dispatch_async(dispatch_get_main_queue()) {
                println("PHOTO LOAD \(photo.file)")
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
        }
    }
    
    @IBAction func didPressNewCollection(sender: UIButton) {
        newCollectionButton.enabled = false
        pin.deletePhotos()
        pin.loadPhotos(getNextPage: true) { success in
            self.fetch()
            dispatch_async(dispatch_get_main_queue()) {
                self.collectionView.reloadData()
            }
        }
    }
    // MARK: - Collection view datasource implementation
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        var cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell", forIndexPath: indexPath) as! PhotoCell
        
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        cell.imageView.image = UIImage(named: "no-image")
        cell.activityIndicator.startAnimating()
        if let image = cache.imageWithIdentifier(photo.file) {
            println("IMAGE IN CACHE \(photo.url)")
            cell.activityIndicator.stopAnimating()
            cell.imageView.image = image
        } else if photo.downloadStatus == .NotLoaded {
            println("NO CACHE \(photo.url)")
            getRemoteImage(cell, photo: photo)
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        println("NUM ITEM \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    /// Delete the item when pressed
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        if photo.downloadStatus == .Loaded {
            photo.delete()
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            let photo = anObject as! Photo
            println("PHOTO \(photo.url)")
        case .Delete:
            collectionView.deleteItemsAtIndexPaths([indexPath!])
        default:
            println("TYPE \(type)")
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        println("DID CHANGE CONTENT")
    }
    
    
    
    // MARK: - Remote image download
    /**
    Downloads the given photo and sets the image in the cell. Stores the image in the cache for later use.
    
    :param: cell The PhotoCell
    :param: photo The Photo
    */
    func getRemoteImage(cell: PhotoCell, photo: Photo) {
        let task = cache.downloadImage(photo.file) { imageData, error in
            if imageData != nil {
                let image = UIImage(data: imageData!)
                photo.saveImage(image!)
                cell.imageView.image = image
                cell.activityIndicator.stopAnimating()
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

