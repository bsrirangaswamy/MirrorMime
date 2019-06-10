//
//  ViewController.swift
//  MirrorMime
//
//  Created by Balakumaran Srirangaswamy on 5/30/19.
//  Copyright © 2019 Bala. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var pictureImageView: UIImageView!
    @IBOutlet weak var takePictureButton: UIButton!
    @IBOutlet weak var firstMatchImageView: UIImageView!
    @IBOutlet weak var secondMatchImageView: UIImageView!
    @IBOutlet weak var thirdMatchImageView: UIImageView!
    
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var innerStackView: UIStackView!
    
    private var imagePickerController = UIImagePickerController()
    private var isTakePicture = true
    private var similarPersonsArray = [User]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Load all stored images to cloud for detection -> generating unique face Ids
        self.setPictureButtonUI(title: "Uploading...", enabled: false)
        DataManager.sharedInstance.loadData(fromFileURL: "/Images/AllPhotos", forAllPeople: true) { [weak self] in
            guard let strongSelf = self else { return }
            let _ = DataManager.sharedInstance.allPhotosFaceIds
            strongSelf.setPictureButtonUI(title: "TAKE PICTURE", enabled: true)
        }
    }
    
    override func viewWillLayoutSubviews() {
        pictureImageView.layer.cornerRadius = pictureImageView.frame.height/2
        firstMatchImageView.layer.cornerRadius = firstMatchImageView.frame.height/2
        secondMatchImageView.layer.cornerRadius = secondMatchImageView.frame.height/2
        thirdMatchImageView.layer.cornerRadius = thirdMatchImageView.frame.height/2
//        mainStackView.isHidden = true
    }
    
    @IBAction func takePictureButtonPressed(_ sender: UIButton) {
        if isTakePicture {
            imagePickerController.delegate = self
            imagePickerController.allowsEditing = true
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if let cameraAction = self.createAction(title: "kTakePicture".localized, sourceType: .camera) {
                alertController.addAction(cameraAction)
            }
            if let photoLibAction = self.createAction(title: "kPhotoLibrary".localized, sourceType: .photoLibrary) {
                alertController.addAction(photoLibAction)
            }
            alertController.addAction(UIAlertAction(title: "kCancel".localized, style: .cancel, handler: nil))
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                alertController.popoverPresentationController?.sourceView = sender
                alertController.popoverPresentationController?.sourceRect = sender.bounds
                alertController.popoverPresentationController?.permittedArrowDirections = [.down, .up]
            }
            
            self.present(alertController, animated: true)
        } else {
            let DMInstance = DataManager.sharedInstance
            if let faceId = DMInstance.profileUser.faceIdArray.first {
                NetworkManager.sharedInstance.findSimilars(faceId: faceId, faceIds: DMInstance.allPhotosFaceIds) { [weak self] (faceIDs) in
                    guard let strongSelf = self else { return }
                    strongSelf.similarPersonsArray = DMInstance.filterPersons(withFaceIds: faceIDs)
                    strongSelf.updateUIWithSimilarFaces()
                    strongSelf.isTakePicture = true
                    strongSelf.setPictureButtonUI(title: "TAKE PICTURE", enabled: true)
                }
            }
        }
    }
    
    private func setPictureButtonUI(title: String, enabled: Bool) {
        self.takePictureButton.setTitle(title, for: .normal)
        self.takePictureButton.isUserInteractionEnabled = enabled
        self.takePictureButton.alpha = enabled ? 1.0 : 0.7
    }
    
    private func updateUIWithSimilarFaces() {
        if similarPersonsArray.count > 2 {
            mainStackView.isHidden = false
            innerStackView.isHidden = false
            
            firstMatchImageView.isHidden = false
            secondMatchImageView.isHidden = false
            thirdMatchImageView.isHidden = false
            
            firstMatchImageView.image = similarPersonsArray[0].pictureImage
            secondMatchImageView.image = similarPersonsArray[1].pictureImage
            thirdMatchImageView.image = similarPersonsArray[2].pictureImage
            
        } else if similarPersonsArray.count > 1 {
            mainStackView.isHidden = false
            innerStackView.isHidden = false
            
            firstMatchImageView.isHidden = false
            secondMatchImageView.isHidden = false
            thirdMatchImageView.isHidden = true
            
            firstMatchImageView.image = similarPersonsArray[0].pictureImage
            secondMatchImageView.image = similarPersonsArray[1].pictureImage
            
        } else if similarPersonsArray.count > 0 {
            mainStackView.isHidden = false
            innerStackView.isHidden = true
            
            firstMatchImageView.isHidden = false
            
            firstMatchImageView.image = similarPersonsArray[0].pictureImage
        }
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editedImage = info[.editedImage] as? UIImage {
            pictureImageView.image = editedImage
            DataManager.sharedInstance.profileUser.pictureImage = editedImage
        } else if let originalImage = info[.originalImage] as? UIImage {
            pictureImageView.image = originalImage
            DataManager.sharedInstance.profileUser.pictureImage = originalImage
        }
        if pictureImageView.image != nil {
            self.setPictureButtonUI(title: "Uploading...", enabled: false)
            DataManager.sharedInstance.loadData(forAllPeople: false) {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.isTakePicture = false
                strongSelf.setPictureButtonUI(title: "Find Similar Face", enabled: true)
            }
        }
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePickerController.dismiss(animated: true, completion: nil)
    }
    
    func createAction(title: String, sourceType: UIImagePickerController.SourceType) -> UIAlertAction? {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            return nil
        }
        let alertAction = UIAlertAction(title: title, style: .default) { [unowned self] (_) in
            self.checkPermission(sourceType: sourceType, completion: { [unowned self] (isAccessGranted) in
                if isAccessGranted {
                    self.imagePickerController.sourceType = sourceType
                    self.present(self.imagePickerController, animated: true)
                }
            })
        }
        return alertAction
    }
    
    func checkPermission(sourceType: UIImagePickerController.SourceType, completion: @escaping (_ isPermissionGranted: Bool) -> Void) {
        switch sourceType {
        case .camera:
            let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraAuthorizationStatus == .authorized {
                completion(true)
            } else if cameraAuthorizationStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { (isAccessGranted) in
                    if isAccessGranted {
                        print("Camera access granted")
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            } else {
                completion(false)
            }
            break
        case .photoLibrary:
            let photoLibAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
            if photoLibAuthorizationStatus == .authorized {
                completion(true)
            } else if photoLibAuthorizationStatus == .notDetermined {
                PHPhotoLibrary.requestAuthorization { (requestAuthStatus) in
                    if requestAuthStatus == .authorized {
                        print("Photo library access granted")
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        default:
            print("Source type undefined")
            completion(false)
        }
    }
}

