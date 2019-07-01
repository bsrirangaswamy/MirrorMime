//
//  DataManager.swift
//  MirrorMime
//
//  Created by Balakumaran Srirangaswamy on 6/2/19.
//  Copyright © 2019 Bala. All rights reserved.
//

import UIKit

class DataManager: NSObject {
    
    static let sharedInstance = DataManager()
    
    var people = [User]()
    var profileUser = User()
    
    lazy var allPhotosFaceIds: [String] = {
        var allFaceIds: [String] = []
        for person in people {
            allFaceIds.append(contentsOf: person.faceIdArray)
        }
        return allFaceIds
    }()
    
    func loadData(fromFileURL: String = "", forAllPeople: Bool, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            if forAllPeople {
                let (photoDatas, photoImages) = self.loadImages(at: fromFileURL)
                for (photoData, photoImage) in zip(photoDatas, photoImages) {
                    let faceIdArray = NetworkManager.sharedInstance.executeDetectForFaceID(imageData: photoData)
                    if !faceIdArray.isEmpty {
                        let person = User()
                        person.faceIdArray = faceIdArray
                        person.pictureImage = photoImage
                        self.people.append(person)
                    }
                }
            } else {
                if let profileUserImageData = self.profileUser.pictureImage.jpegData(compressionQuality: 1) {
                    self.profileUser.faceIdArray = NetworkManager.sharedInstance.executeDetectForFaceID(imageData: profileUserImageData)
//                    self.people.append(self.profileUser)
//                    self.allPhotosFaceIds.append(contentsOf: self.profileUser.faceIdArray)
                }
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    func filterPersons(withFaceIds faceIds: [String]) -> [User] {
        var filteredPersons: [User] = []
        let faceIdsSet = Set(faceIds)
//        let faceIdsSet = Set(faceIds.count > 4 ? Array(faceIds[0...3]) : faceIds)
        for person in people {
            let fileteredFaceIDSet = Set(person.faceIdArray).intersection(faceIdsSet)
            if !fileteredFaceIDSet.isEmpty && !filteredPersons.contains(person) {
                filteredPersons.append(person)
            }
        }
        
        return filteredPersons
    }
    
    private func loadImages(at path: String) -> ([Data], [UIImage]) {
        var datas: [Data] = []
        var images: [UIImage] = []
        
        let fullFolderPath = Bundle.main.resourcePath!.appending(path)
        let imageNames = try! FileManager.default.contentsOfDirectory(atPath: fullFolderPath)
        
        for imageName in imageNames {
            let imageUrl = fullFolderPath.appending("/\(imageName)")
            let data = try! Data.init(contentsOf: URL(fileURLWithPath: imageUrl))
            let image = UIImage.init(data: data, scale: UIScreen.main.scale)!
            
            datas.append(data)
            images.append(image)
        }
        
        return (datas, images)
    }

}
