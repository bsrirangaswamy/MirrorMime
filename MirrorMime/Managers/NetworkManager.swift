//
//  NetworkManager.swift
//  MirrorMime
//
//  Created by Balakumaran Srirangaswamy on 6/1/19.
//  Copyright © 2019 Bala. All rights reserved.
//

import UIKit

let APIKey = "c123a265114041cb9a381b0093342cb4" // Ocp-Apim-Subscription-Key
let Region = "canadacentral"
let FindSimilarsUrl = "https://\(Region).api.cognitive.microsoft.com/face/v1.0/findsimilars"
let DetectUrl = "https://\(Region).api.cognitive.microsoft.com/face/v1.0/detect?returnFaceId=true"

class NetworkManager: NSObject {
    
    static let sharedInstance = NetworkManager()
    
    // Step 1: Detect Face ID
    func executeDetectFaceID(imageData: Data) -> [String] {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/octet-stream"
        headers["Ocp-Apim-Subscription-Key"] = APIKey
        
        let response = self.postRequest(url: DetectUrl, postData: imageData, headers: headers)
        let faceIds = getFaceIds(fromResponse: response)
        
        return faceIds
    }
    
    // Step 2: Find Similar faces of user's face with the face id
    func findSimilars(faceId: String, faceIds: [String], completion: @escaping ([String]) -> Void) {
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        headers["Ocp-Apim-Subscription-Key"] = APIKey
        
        let params: [String: Any] = [
            "faceId": faceId,
            "faceIds": faceIds,
            "mode": "matchFace"
        ]
        
        // Convert the Dictionary to Data
        let data = try! JSONSerialization.data(withJSONObject: params)
        
        DispatchQueue.global(qos: .background).async {
            let response = self.postRequest(url: FindSimilarsUrl, postData: data, headers: headers)
            
            // Use a low confidence value to get more matches
            let faceIds = self.getFaceIds(fromResponse: response, minConfidence: 0.4)
            
            DispatchQueue.main.async {
                completion(faceIds)
            }
        }
    }
    
    private func getFaceIds(fromResponse response: [AnyObject], minConfidence: Float? = nil) -> [String] {
        var faceIds: [String] = []
        for faceInfo in response {
            if let faceId = faceInfo["faceId"] as? String  {
                var canAddFace = true
                if minConfidence != nil {
                    let confidence = (faceInfo["confidence"] as! NSNumber).floatValue
                    canAddFace = confidence >= minConfidence!
                }
                if canAddFace { faceIds.append(faceId) }
            }
            
        }
        
        return faceIds
    }
    
    private func postRequest(url: String, postData: Data, headers: [String: String] = [:]) -> [AnyObject] {
        var resultObject: [AnyObject] = []
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = postData
        
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        
        // Using semaphore to make request synchronous
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyObject]{
                resultObject = json
            }
            else {
                print("ERROR response: \(String(data: data!, encoding: .utf8) ?? "")")
            }
            
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return resultObject
    }

}
