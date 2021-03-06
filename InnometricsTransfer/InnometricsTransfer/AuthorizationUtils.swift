//
//  AuthorizationUtils.swift
//  InnometricsCollector
//
//  Created by Denis Zaplatnikov on 25/02/2017.
//  Modified by Dragos Strugar in 2020
//  Copyright © 2018 Denis Zaplatnikov and Pavel Kotov. All rights reserved.
//

import Foundation

public class AuthorizationUtils {
    public static var isAuthorizedAlias: String = "isAuthorized"
    public static var authorizationTokenAlias: String = "authorizationToken"
    public static var userIdAlias: String = "userId"
    public static var userPw: String = "userPw"
    public static var offlineModeIsEnabled: Bool = false

    public static func authorization(username: String, password: String, completion: @escaping (_ token: String?) -> Void) {
        let authorizationJson: [String: String] = ["email": username, "password": password]
        do {
            let jsonData = try! JSONSerialization.data(withJSONObject: authorizationJson, options: .prettyPrinted)
            // create post request

            var request = URLRequest(url: URL(string: "\(ServerPrefs.getServerUrl())/login")!)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            
            // insert json data to the request
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil
                {
                    print("\(String(describing: error))")
                    completion(nil)
                    return
                }
                
                let responseCode = (response as! HTTPURLResponse).statusCode
                
                if (responseCode == 200) {
                    if data != nil {
                        if let responseJson = try? JSONSerialization.jsonObject(with: data!) as? [String: Any] {
                            if let token = responseJson["token"] as? String {
                                // save credentials for future use
                                saveUsername(username: username)
                                savePassword(pw: password)
                                completion(token)
                                return
                            }
                        }
                    }
                }
                
                completion(nil)
                return
            }
            
            task.resume()
        }
    }
    
    public static func saveIsAuthorized(isAuthorized: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(isAuthorized, forKey: isAuthorizedAlias)
    }
    
    public static func isAuthorized() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: isAuthorizedAlias)
    }
    
    public static func saveAuthorizationToken(token: String?) {
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: authorizationTokenAlias)
    }
    
    public static func saveUsername(username: String?) {
        let defaults = UserDefaults.standard
        defaults.set(username, forKey: userIdAlias)
    }
    
    public static func savePassword(pw: String?) {
        let defaults = UserDefaults.standard
        defaults.set(pw, forKey: userPw)
    }
    
    public static func getAuthorizationToken() -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: authorizationTokenAlias)
    }
    
    public static func getUsername() -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: userIdAlias)
    }
}
