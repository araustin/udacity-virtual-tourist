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
        
        fetchedResultsController.delegate = self
        fetch()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Notfications for image loading
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadAllPhotos:", name: Pin.Config.AllPhotosLoadedForPinNotification, object: pin)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didLoadPhoto:", name: Photo.Config.PhotoLoadedNotification, object: nil)
        
        // add the map pin
        mapView.addAnnotation(pin)
        centerMapOnLocation(pin.coordinate)
        
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
        dispatch_async(dispatch_get_main_queue()) {
            self.newCollectionButton.enabled = true
        }
    }
    
    func didLoadPhoto(photo: Photo) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView.reloadData()
        }
    }
    
    @IBAction func didPressNewCollection(sender: UIButton) {
        newCollectionButton.enabled = false
        pin.deletePhotos()
        pin.loadPhotos(getNextPage: true) { success in
            self.fetch()
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
    
   /*
    - (CGSize)collectionView:(UICollectionView *)collectionView
    layout:(UICollectionViewLayout *)collectionViewLayout
    sizeForItemAtIndexPath:(NSIndexPath *)indexPath
    {
    // Adjust cell size for orientation
    if (UIDeviceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
    return CGSizeMake(170.f, 170.f);
    }
    return CGSizeMake(192.f, 192.f);
    }
    
    - (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
    {
    [self.collectionView performBatchUpdates:nil completion:nil];
    }
   */
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        collectionView.performBatchUpdates(nil, completion: nil)
    }
    // MARK: - Fetched results controller
    
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
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    println("error downloading image \(error)")
                    photo.delete()
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
 
    // MARK: - Map view convenience method

    /**
    Center the map on a location. From the raywenderlich.com tutorial
    :param: location The location to center the map
    */
    func centerMapOnLocation(coordinate: CLLocationCoordinate2D) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, 2000, 2000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}

